-- Audit hardening (2026-10-19).
-- 1. Sessions expire after 30 days without use, and deleted members are signed out.
-- 2. Chat files and pictures must be real base64, so they can never carry markup.
-- 3. Remove broad table grants from anon (RLS already blocks them).

create or replace function public.member_session_for(token text)
returns public.member_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.member_sessions;
begin
  select * into s from public.member_sessions
  where token_hash = public.sync_hash(token);
  if s.id is null or s.revoked_at is not null
     or coalesce(s.last_seen_at, s.created_at) < now() - interval '30 days' then
    raise exception 'Please sign in again.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.sync_records r
    where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key
      and r.data ->> 'deleted_at' is not null
  ) then
    raise exception 'Please sign in again.' using errcode = 'P0001';
  end if;
  update public.member_sessions set last_seen_at = now() where id = s.id;
  return s;
end;
$$;

-- Stop files that are not real base64 at the door (covers chat_post and avatar_set).
create or replace function public.enforce_base64()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  body text;
begin
  if tg_table_name = 'member_avatars' then
    body := substr(new.photo, strpos(new.photo, ',') + 1);
  else
    body := new.data;
  end if;
  if body !~ '^[A-Za-z0-9+/=]*$' then
    raise exception 'That file is not allowed.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists chat_files_base64 on public.chat_files;
create trigger chat_files_base64 before insert or update on public.chat_files
  for each row execute function public.enforce_base64();
drop trigger if exists member_avatars_base64 on public.member_avatars;
create trigger member_avatars_base64 before insert or update on public.member_avatars
  for each row execute function public.enforce_base64();

do $$
declare
  t text;
begin
  foreach t in array array['announce_roles', 'member_zone_choice', 'pay_claims', 'pay_requests'] loop
    if to_regclass('public.' || t) is not null then
      execute format('revoke all on public.%I from anon, authenticated', t);
    end if;
  end loop;
end $$;
