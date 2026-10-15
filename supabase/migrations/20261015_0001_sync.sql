-- Offline-first sync for the JBF app (CoreIntel multi-organisation ready).
--
-- Phones never touch the tables directly: row level security is on with no
-- policies, and everything goes through SECURITY DEFINER functions that
-- check a per-phone device token. Each phone's rows are stored as JSON
-- records keyed by (org, table, key); the newest updated_at wins, except
-- that money and audit records keep their original values.

create sequence if not exists public.sync_seq;

create table public.sync_orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.sync_devices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  name text not null,
  series text,
  token_hash text not null unique,
  is_admin boolean not null default false,
  enrolled_at timestamptz not null default now(),
  last_seen_at timestamptz,
  revoked_at timestamptz
);
create unique index sync_devices_series on public.sync_devices (org_id, series)
  where series is not null and revoked_at is null;

create table public.sync_codes (
  code_hash text primary key,
  org_id uuid not null references public.sync_orgs (id),
  is_admin boolean not null default false,
  created_by uuid references public.sync_devices (id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by uuid references public.sync_devices (id)
);

create table public.sync_records (
  org_id uuid not null references public.sync_orgs (id),
  tbl text not null,
  key text not null,
  data jsonb not null,
  updated_at timestamptz not null,
  pushed_by uuid references public.sync_devices (id),
  seq bigint not null default nextval('public.sync_seq'),
  primary key (org_id, tbl, key)
);
create index sync_records_seq on public.sync_records (org_id, seq);

alter table public.sync_orgs enable row level security;
alter table public.sync_devices enable row level security;
alter table public.sync_codes enable row level security;
alter table public.sync_records enable row level security;
revoke all on public.sync_orgs, public.sync_devices, public.sync_codes,
  public.sync_records from anon, authenticated;

-- Keeps money and history honest whatever a phone sends.
create or replace function public.sync_records_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  incoming jsonb := new.data;
  rank_old int;
  rank_new int;
  k text;
begin
  if new.tbl = 'audit_logs' then
    return old;
  end if;
  if new.tbl in ('payments', 'expenses') then
    foreach k in array array['amount', 'member_id', 'contribution_type_id',
      'receipt_no', 'voucher_no', 'category_id', 'paid_on', 'period'] loop
      if old.data ? k then
        new.data := jsonb_set(new.data, array[k], old.data -> k);
      end if;
    end loop;
    if old.data ->> 'status' = 'voided' then
      foreach k in array array['status', 'void_reason', 'voided_by',
        'voided_at'] loop
        if old.data ? k then
          new.data := jsonb_set(new.data, array[k], old.data -> k);
        end if;
      end loop;
    end if;
  end if;
  if new.tbl = 'welfare_cases' then
    rank_old := case old.data ->> 'status'
      when 'pending' then 0 when 'paid' then 2 else 1 end;
    rank_new := case new.data ->> 'status'
      when 'pending' then 0 when 'paid' then 2 else 1 end;
    if rank_new < rank_old then
      return old;
    end if;
  end if;
  if new.data is distinct from incoming then
    -- Changed by the guard: send the corrected row back to the pusher too.
    new.pushed_by := null;
  end if;
  new.seq := nextval('public.sync_seq');
  return new;
end;
$$;

create trigger sync_records_guard
before update on public.sync_records
for each row execute function public.sync_records_guard();

create or replace function public.sync_hash(secret text)
returns text
language sql
immutable
set search_path = ''
as $$ select encode(extensions.digest(secret, 'sha256'), 'hex') $$;

create or replace function public.sync_device_for(token text)
returns public.sync_devices
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices;
begin
  select * into d from public.sync_devices
  where token_hash = public.sync_hash(token);
  if d.id is null then
    raise exception 'This phone is not set up for cloud sync.'
      using errcode = 'P0001';
  end if;
  if d.revoked_at is not null then
    raise exception 'This phone has been removed from cloud sync.'
      using errcode = 'P0001';
  end if;
  update public.sync_devices set last_seen_at = now() where id = d.id;
  return d;
end;
$$;

-- Joins a phone to an organisation with a one-time code.
create or replace function public.sync_enroll(
  code text,
  device_name text,
  series text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.sync_codes;
  token text := encode(extensions.gen_random_bytes(32), 'hex');
  dev_id uuid;
  org_name text;
  clean_series text := nullif(upper(trim(coalesce(series, ''))), '');
begin
  select * into c from public.sync_codes
  where code_hash = public.sync_hash(upper(trim(code)))
  for update;
  if c.code_hash is null or c.used_at is not null or c.expires_at < now() then
    raise exception 'This code is not valid. Ask for a new one.'
      using errcode = 'P0001';
  end if;
  if coalesce(trim(device_name), '') = '' then
    raise exception 'Give this phone a name.' using errcode = 'P0001';
  end if;
  if clean_series is not null and exists (
    select 1 from public.sync_devices d
    where d.org_id = c.org_id and d.series = clean_series
      and d.revoked_at is null
  ) then
    raise exception 'Another phone already uses the number series %.',
      clean_series using errcode = 'P0001';
  end if;
  insert into public.sync_devices (org_id, name, series, token_hash, is_admin)
  values (c.org_id, trim(device_name), clean_series, public.sync_hash(token),
    c.is_admin)
  returning id into dev_id;
  update public.sync_codes set used_at = now(), used_by = dev_id
  where code_hash = c.code_hash;
  select name into org_name from public.sync_orgs where id = c.org_id;
  return jsonb_build_object(
    'token', token,
    'device_id', dev_id,
    'org_id', c.org_id,
    'org_name', org_name,
    'is_admin', c.is_admin,
    'records', (select count(*) from public.sync_records r
                where r.org_id = c.org_id)
  );
end;
$$;

-- Uploads changed rows: [{t, k, u, d}] (table, key, updated_at, data).
create or replace function public.sync_push(token text, rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
  n int;
begin
  if jsonb_typeof(rows) <> 'array' or jsonb_array_length(rows) > 1000 then
    raise exception 'Send at most 1000 rows at a time.' using errcode = 'P0001';
  end if;
  insert into public.sync_records as r (org_id, tbl, key, data, updated_at,
    pushed_by)
  select d.org_id, x ->> 't', x ->> 'k', x -> 'd', (x ->> 'u')::timestamptz,
    d.id
  from jsonb_array_elements(rows) as x
  on conflict (org_id, tbl, key) do update
    set data = excluded.data,
        updated_at = excluded.updated_at,
        pushed_by = excluded.pushed_by
    where excluded.updated_at >= r.updated_at;
  get diagnostics n = row_count;
  return jsonb_build_object('accepted', n);
end;
$$;

-- Downloads rows changed by other phones since [since], oldest first.
create or replace function public.sync_pull(
  token text,
  since bigint default 0,
  max_rows int default 500
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
  result jsonb;
  last_seq bigint;
  lim int := least(greatest(max_rows, 1), 2000);
begin
  with page as (
    select r.tbl, r.key, r.data, r.updated_at, r.seq, r.pushed_by
    from public.sync_records r
    where r.org_id = d.org_id and r.seq > since
    order by r.seq
    limit lim
  )
  select
    coalesce(jsonb_agg(jsonb_build_object('t', tbl, 'k', key, 'd', data,
      'u', updated_at) order by seq)
      filter (where pushed_by is distinct from d.id), '[]'::jsonb),
    max(seq)
  into result, last_seq
  from page;
  return jsonb_build_object(
    'rows', result,
    'last_seq', coalesce(last_seq, since),
    'more', exists (select 1 from public.sync_records r
             where r.org_id = d.org_id and r.seq > coalesce(last_seq, since))
  );
end;
$$;

-- Admin phones create one-time codes for new phones (valid 7 days).
create or replace function public.sync_create_code(
  token text,
  admin boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  i int;
begin
  if not d.is_admin then
    raise exception 'Only the main phone can add phones.' using errcode = 'P0001';
  end if;
  for i in 1..10 loop
    code := code || substr(alphabet,
      1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(alphabet)), 1);
  end loop;
  insert into public.sync_codes (code_hash, org_id, is_admin, created_by,
    expires_at)
  values (public.sync_hash(code), d.org_id, admin, d.id,
    now() + interval '7 days');
  return code;
end;
$$;

create or replace function public.sync_list_devices(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
begin
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', x.id, 'name', x.name, 'series', x.series, 'is_admin', x.is_admin,
      'enrolled_at', x.enrolled_at, 'last_seen_at', x.last_seen_at,
      'revoked', x.revoked_at is not null, 'me', x.id = d.id)
      order by x.enrolled_at), '[]'::jsonb)
    from public.sync_devices x where x.org_id = d.org_id
  );
end;
$$;

create or replace function public.sync_revoke_device(token text, device uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
begin
  if not d.is_admin then
    raise exception 'Only the main phone can remove phones.'
      using errcode = 'P0001';
  end if;
  if device = d.id then
    raise exception 'A phone cannot remove itself.' using errcode = 'P0001';
  end if;
  update public.sync_devices set revoked_at = now()
  where id = device and org_id = d.org_id and revoked_at is null;
end;
$$;

revoke all on function public.sync_records_guard() from public, anon, authenticated;
revoke all on function public.sync_device_for(text) from public, anon, authenticated;
revoke all on function public.sync_hash(text) from public, anon, authenticated;
grant execute on function public.sync_enroll(text, text, text) to anon, authenticated;
grant execute on function public.sync_push(text, jsonb) to anon, authenticated;
grant execute on function public.sync_pull(text, bigint, int) to anon, authenticated;
grant execute on function public.sync_create_code(text, boolean) to anon, authenticated;
grant execute on function public.sync_list_devices(text) to anon, authenticated;
grant execute on function public.sync_revoke_device(text, uuid) to anon, authenticated;
