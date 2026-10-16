-- Phones join by signing in with an officer's own username and password
-- (checked by the sync-sign-in edge function against the users records
-- the main phone uploaded), instead of one-time codes. Codes remain for
-- starting an organisation.

alter table public.sync_orgs add column if not exists slug text;
create unique index if not exists sync_orgs_slug on public.sync_orgs (upper(slug));
update public.sync_orgs set slug = 'JBF'
where name = 'June Borns Family' and slug is null;

-- Repeated wrong passwords lock that username for a while.
create table if not exists public.sync_sign_in_guard (
  org_id uuid not null references public.sync_orgs (id),
  username text not null,
  failures int not null default 0,
  locked_until timestamptz,
  primary key (org_id, username)
);
alter table public.sync_sign_in_guard enable row level security;
revoke all on public.sync_sign_in_guard from anon, authenticated;

-- The user record for a sign-in, for the edge function only.
create or replace function public.sync_sign_in_lookup(org text, user_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.sync_orgs;
  u jsonb;
  role_key text;
  g public.sync_sign_in_guard;
begin
  select * into o from public.sync_orgs where upper(slug) = upper(trim(org));
  if o.id is null then
    raise exception 'No organisation called %.', trim(org) using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.sync_devices d
                 where d.org_id = o.id and d.revoked_at is null) then
    raise exception '% is not online yet. Turn on cloud sync on the main phone first.',
      o.name using errcode = 'P0001';
  end if;
  select * into g from public.sync_sign_in_guard
  where org_id = o.id and username = lower(trim(user_name));
  if g.locked_until is not null and g.locked_until > now() then
    raise exception 'Too many wrong passwords. Try again after %.',
      to_char(g.locked_until at time zone 'UTC', 'HH24:MI "GMT"')
      using errcode = 'P0001';
  end if;
  select r.data into u from public.sync_records r
  where r.org_id = o.id and r.tbl = 'users'
    and lower(r.data ->> 'username') = lower(trim(user_name))
    and r.data ->> 'deleted_at' is null
  limit 1;
  if u is not null then
    select r.data ->> 'key' into role_key from public.sync_records r
    where r.org_id = o.id and r.tbl = 'roles' and r.key = u ->> 'role_id';
  end if;
  return jsonb_build_object(
    'org_id', o.id,
    'org_name', o.name,
    'found', u is not null,
    'active', coalesce((u ->> 'is_active')::int, 0) = 1,
    'password_hash', u ->> 'password_hash',
    'is_admin', role_key = 'super_admin'
  );
end;
$$;

-- Records the result of a sign-in and, when it succeeded, enrols the
-- phone with the next free number series (P2, P3...).
create or replace function public.sync_sign_in_complete(
  org uuid,
  user_name text,
  ok boolean,
  device_name text,
  admin boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  token text := encode(extensions.gen_random_bytes(32), 'hex');
  dev_id uuid;
  n int := 2;
  s text;
  uname text := lower(trim(user_name));
begin
  if not ok then
    insert into public.sync_sign_in_guard as g (org_id, username, failures)
    values (org, uname, 1)
    on conflict (org_id, username) do update
      set failures = g.failures + 1,
          locked_until = case when g.failures + 1 >= 5
                              then now() + interval '15 minutes' end;
    update public.sync_sign_in_guard set failures = 0
    where org_id = org and username = uname and locked_until is not null
      and failures >= 5;
    return null;
  end if;
  update public.sync_sign_in_guard set failures = 0, locked_until = null
  where org_id = org and username = uname;
  loop
    s := 'P' || n;
    exit when not exists (select 1 from public.sync_devices d
      where d.org_id = org and d.series = s and d.revoked_at is null);
    n := n + 1;
  end loop;
  insert into public.sync_devices (org_id, name, series, token_hash, is_admin)
  values (org, coalesce(nullif(trim(device_name), ''), 'Phone ' || s), s,
    public.sync_hash(token), admin)
  returning id into dev_id;
  return jsonb_build_object(
    'token', token,
    'device_id', dev_id,
    'org_id', org,
    'org_name', (select name from public.sync_orgs where id = org),
    'is_admin', admin,
    'series', s,
    'records', (select count(*) from public.sync_records r where r.org_id = org)
  );
end;
$$;

revoke all on function public.sync_sign_in_lookup(text, text)
  from public, anon, authenticated;
revoke all on function public.sync_sign_in_complete(uuid, text, boolean, text, boolean)
  from public, anon, authenticated;
grant execute on function public.sync_sign_in_lookup(text, text) to service_role;
grant execute on function public.sync_sign_in_complete(uuid, text, boolean, text, boolean)
  to service_role;
