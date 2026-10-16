-- Sign-in for the member web app. It has no synced phone, so executives get
-- an ordinary member session (their roles still show and drive chats)
-- instead of enrolling a new phone each time they open it.
create or replace function public.member_auth_complete_web(
  org uuid,
  member_no text,
  ok boolean,
  new_hash text default null,
  device_name text default null,
  check_only boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  guard_key text := 'member:' || upper(trim(member_no));
  m public.sync_records := public.member_record(org, member_no);
  acc jsonb;
  token text;
begin
  if not ok or m.key is null then
    insert into public.sync_sign_in_guard as g (org_id, username, failures)
    values (org, guard_key, 1)
    on conflict (org_id, username) do update
      set failures = case when g.failures + 1 >= 5 then 0 else g.failures + 1 end,
          locked_until = case when g.failures + 1 >= 5
                              then now() + interval '15 minutes' end;
    return null;
  end if;
  update public.sync_sign_in_guard set failures = 0, locked_until = null
  where org_id = org and username = guard_key;
  if new_hash is not null then
    insert into public.member_accounts as x (org_id, member_key, password_hash,
      activated_at)
    values (org, m.key, new_hash, now())
    on conflict (org_id, member_key) do update
      set password_hash = excluded.password_hash,
          activated_at = coalesce(x.activated_at, now());
  end if;
  acc := public.member_access(org, m.key);
  if check_only then
    return jsonb_build_object('kind', 'checked', 'access', acc);
  end if;
  token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.member_sessions (org_id, member_key, token_hash,
    device_name)
  values (org, m.key, public.sync_hash(token), device_name);
  return jsonb_build_object(
    'kind', 'member',
    'token', token,
    'member_key', m.key,
    'member_no', m.data ->> 'member_no',
    'name', m.data ->> 'full_name',
    'org_name', (select name from public.sync_orgs where id = org)
  );
end;
$$;

revoke all on function public.member_auth_complete_web(uuid, text, boolean, text, text, boolean) from public, anon, authenticated;
grant execute on function public.member_auth_complete_web(uuid, text, boolean, text, text, boolean) to service_role;
