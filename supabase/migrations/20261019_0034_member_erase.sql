-- Member self-service account deletion (Google Play requirement).
-- Called only by the member-auth edge function after the password is
-- re-checked. It matches what portal/delete-account.html promises: sign-in,
-- profile photo and personal details are erased, chat messages are made
-- anonymous, payment and election records stay without personal details.
create or replace function public.member_erase(org uuid, member_no text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  m public.sync_records := public.member_record(org, member_no);
  stamp text := to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS') || ' +00:00';
  pii text[] := array['gender', 'date_of_birth', 'nationality', 'occupation',
    'marital_status', 'location', 'phone', 'whatsapp', 'whatsapp_name', 'email',
    'address', 'gps_address', 'emergency_name', 'emergency_phone', 'photo_path'];
begin
  if m.key is null then
    raise exception 'Member not found.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.sync_records r
    where r.org_id = org and r.tbl = 'role_assignments' and r.data ->> 'deleted_at' is null
      and r.data ->> 'ends_on' is null and r.data ->> 'member_id' = m.key
  ) or exists (
    select 1 from public.sync_records r
    where r.org_id = org and r.tbl = 'executives' and r.data ->> 'deleted_at' is null
      and r.data ->> 'ended_on' is null and r.data ->> 'member_id' = m.key
  ) then
    raise exception 'You hold an office. Ask the Founder or General Secretary to end it first, then delete your account.'
      using errcode = 'P0001';
  end if;
  update public.member_sessions set revoked_at = now()
  where org_id = org and member_key = m.key and revoked_at is null;
  delete from public.member_accounts where org_id = org and member_key = m.key;
  delete from public.member_avatars where org_id = org and member_key = m.key;
  update public.chat_messages
    set author_key = null, author_name = 'Former member'
  where org_id = org and author_key = m.key;
  update public.sync_records
    set data = (data - pii) || jsonb_build_object(
          'full_name', 'Former member', 'deleted_at', stamp, 'updated_at', stamp),
        updated_at = now(),
        seq = nextval('public.sync_seq')
  where org_id = org and tbl = 'members' and key = m.key;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.member_erase(uuid, text) from public, anon, authenticated;
grant execute on function public.member_erase(uuid, text) to service_role;
