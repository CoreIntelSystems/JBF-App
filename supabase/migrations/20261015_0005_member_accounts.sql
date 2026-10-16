-- Every member signs in with their member ID and a password they choose
-- when they first activate (checked against the phone number the
-- association has for them). People with an executive role get a phone
-- that syncs the records their role covers; everyone else gets a member
-- session that only reads their own statement and the public lists.
-- Passwords are PBKDF2 hashes made by the member-auth edge function.

create table if not exists public.member_accounts (
  org_id uuid not null references public.sync_orgs (id),
  member_key text not null,
  password_hash text,
  activated_at timestamptz,
  reset_at timestamptz,
  reset_by text,
  primary key (org_id, member_key)
);
alter table public.member_accounts enable row level security;
revoke all on public.member_accounts from anon, authenticated;

create table if not exists public.member_sessions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  member_key text not null,
  token_hash text not null unique,
  device_name text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz,
  revoked_at timestamptz
);
alter table public.member_sessions enable row level security;
revoke all on public.member_sessions from anon, authenticated;

-- The member a synced phone signed in as (null for phones joined with a
-- code or an old username login).
alter table public.sync_devices add column if not exists member_key text;

-- A member record by its member ID.
create or replace function public.member_record(org uuid, member_no text)
returns public.sync_records
language sql
stable
security definer
set search_path = ''
as $$
  select r.* from public.sync_records r
  where r.org_id = org and r.tbl = 'members'
    and upper(r.data ->> 'member_no') = upper(trim(member_no))
    and r.data ->> 'deleted_at' is null
  limit 1
$$;

-- What a member may do: their active roles (assigned roles plus any old
-- username login linked to them) and the permissions those roles give.
create or replace function public.member_access(org uuid, member_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with held as (
    select a.data ->> 'role_id' as role_id,
      nullif(a.data ->> 'zone_ids', '') as zone_ids
    from public.sync_records a
    where a.org_id = org and a.tbl = 'role_assignments'
      and a.data ->> 'member_id' = member_key
      and a.data ->> 'deleted_at' is null
      and (a.data ->> 'starts_on' is null
           or left(a.data ->> 'starts_on', 10)::date <= current_date)
      and (a.data ->> 'ends_on' is null
           or left(a.data ->> 'ends_on', 10)::date > current_date)
    union all
    select u.data ->> 'role_id', nullif(u.data ->> 'zone_ids', '')
    from public.sync_records u
    where u.org_id = org and u.tbl = 'users'
      and u.data ->> 'member_id' = member_key
      and u.data ->> 'deleted_at' is null
      and coalesce((u.data ->> 'is_active')::int, 0) = 1
  ), roles as (
    select r.data ->> 'key' as key, r.data ->> 'level' as level,
      h.zone_ids,
      case when r.data ->> 'permissions' is not null
        then (r.data ->> 'permissions')::jsonb
        else (select coalesce(jsonb_agg(p.data ->> 'permission'), '[]')
              from public.sync_records p
              where p.org_id = org and p.tbl = 'role_permissions'
                and p.data ->> 'role_id' = r.key)
      end as perms
    from held h
    join public.sync_records r on r.org_id = org and r.tbl = 'roles'
      and r.key = h.role_id
  )
  select jsonb_build_object(
    'roles', coalesce((select jsonb_agg(jsonb_build_object(
      'key', key, 'level', level, 'zones', zone_ids)) from roles), '[]'),
    'permissions', coalesce((select jsonb_agg(distinct p)
      from roles, jsonb_array_elements_text(perms) p), '[]'),
    'officer', exists (select 1 from roles where key <> 'member'),
    'admin', exists (select 1 from roles
                     where key in ('super_admin', 'founder')),
    -- Zones a zone-only person covers; null when any role is wider.
    'zones', case
      when not exists (select 1 from roles where key <> 'member') then null
      when exists (select 1 from roles
                   where key <> 'member' and level <> 'zone') then null
      else (select jsonb_agg(distinct z) from roles,
              unnest(string_to_array(zone_ids, ',')) z
            where level = 'zone')
    end
  )
$$;

-- Adds a phone to the organisation's sync with the next free number
-- series (P2, P3...).
create or replace function public.sync_enroll_device(
  org uuid,
  device_name text,
  admin boolean,
  member_key text
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
begin
  loop
    s := 'P' || n;
    exit when not exists (select 1 from public.sync_devices d
      where d.org_id = org and d.series = s and d.revoked_at is null);
    n := n + 1;
  end loop;
  insert into public.sync_devices (org_id, name, series, token_hash, is_admin,
    member_key)
  values (org, coalesce(nullif(trim(device_name), ''), 'Phone ' || s), s,
    public.sync_hash(token), admin, member_key)
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

-- For the member-auth edge function: the member, their account and
-- whether the phone number matches.
create or replace function public.member_auth_lookup(
  org text,
  member_no text,
  phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.sync_orgs;
  m public.sync_records;
  a public.member_accounts;
  g public.sync_sign_in_guard;
  digits text := right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9);
begin
  select * into o from public.sync_orgs where upper(slug) = upper(trim(org));
  if o.id is null then
    raise exception 'Organisation not found.' using errcode = 'P0001';
  end if;
  select * into g from public.sync_sign_in_guard
  where org_id = o.id and username = 'member:' || upper(trim(member_no));
  if g.locked_until is not null and g.locked_until > now() then
    raise exception 'Too many tries. Please wait 15 minutes and try again.'
      using errcode = 'P0001';
  end if;
  m := public.member_record(o.id, member_no);
  if m.key is not null then
    select * into a from public.member_accounts
    where org_id = o.id and member_key = m.key;
  end if;
  return jsonb_build_object(
    'org_id', o.id,
    'org_name', o.name,
    'found', m.key is not null,
    'member_key', m.key,
    'member_no', m.data ->> 'member_no',
    'name', m.data ->> 'full_name',
    'status', m.data ->> 'status',
    'phone_ok', m.key is not null and length(digits) = 9 and (
      right(regexp_replace(coalesce(m.data ->> 'phone', ''), '\D', '', 'g'), 9) = digits
      or right(regexp_replace(coalesce(m.data ->> 'whatsapp', ''), '\D', '', 'g'), 9) = digits),
    'activated', a.password_hash is not null,
    'password_hash', a.password_hash,
    'access', case when m.key is null then null
                   else public.member_access(o.id, m.key) end
  );
end;
$$;

-- For the member-auth edge function: records the outcome. A failed try
-- counts towards the 15-minute lock. On success it stores a new password
-- hash when given, then returns a synced phone for people with an
-- executive role or a member session for everyone else ([check] only
-- confirms the password, for a phone that is already set up).
create or replace function public.member_auth_complete(
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
  if (acc ->> 'officer')::boolean then
    return public.sync_enroll_device(org,
      coalesce(nullif(trim(device_name), ''),
               (m.data ->> 'full_name') || '''s phone'),
      (acc ->> 'admin')::boolean, m.key)
      || jsonb_build_object('kind', 'officer', 'member_key', m.key,
                            'access', acc);
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

-- The statement part of the member portal, for a member already checked.
create or replace function public.member_statement(org uuid, mid text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m jsonb;
  joined date;
  stopped date;
  dues jsonb := '[]'::jsonb;
  t record;
  from_m date;
  until_m date;
  n_months int;
  paid bigint;
  covered int;
begin
  select r.data into m from public.sync_records r
  where r.org_id = org and r.tbl = 'members' and r.key = mid;
  joined := left(m ->> 'date_joined', 10)::date;
  if m ->> 'status' <> 'active' and m ->> 'status_date' is not null then
    stopped := left(m ->> 'status_date', 10)::date;
  end if;

  -- Monthly dues, same rules as the app (lib/domain/dues.dart).
  for t in
    select r.key as id, r.data ->> 'name' as name,
      (r.data ->> 'amount')::bigint as amount,
      left(r.data ->> 'start_date', 10)::date as start_date,
      left(r.data ->> 'end_date', 10)::date as end_date
    from public.sync_records r
    where r.org_id = org and r.tbl = 'contribution_types'
      and r.data ->> 'frequency' = 'monthly'
      and (r.data ->> 'amount') is not null
      and (r.data ->> 'is_active')::int = 1
      and (r.data ->> 'applies_to_all')::int = 1
      and r.data ->> 'deleted_at' is null
  loop
    from_m := date_trunc('month', greatest(joined, coalesce(t.start_date, joined)));
    until_m := date_trunc('month', least(current_date,
      coalesce(t.end_date, current_date), coalesce(stopped, current_date)));
    n_months := case when until_m < from_m then 0 else
      (extract(year from until_m) - extract(year from from_m)) * 12
      + extract(month from until_m) - extract(month from from_m) + 1 end;
    select coalesce(sum((p.data ->> 'amount')::bigint), 0) into paid
    from public.sync_records p
    where p.org_id = org and p.tbl = 'payments'
      and p.data ->> 'member_id' = mid
      and p.data ->> 'contribution_type_id' = t.id
      and p.data ->> 'status' = 'valid';
    covered := least(n_months, (paid / greatest(t.amount, 1))::int);
    dues := dues || jsonb_build_object(
      'name', t.name,
      'monthly', t.amount,
      'months', n_months,
      'expected', t.amount * n_months,
      'paid', paid,
      'outstanding', greatest(t.amount * n_months - paid, 0),
      'months_behind', n_months - covered,
      'next_unpaid', case when covered < n_months
        then to_char(from_m + make_interval(months => covered), 'YYYY-MM') end
    );
  end loop;

  return jsonb_build_object(
    'org', (select name from public.sync_orgs where id = org),
    'member', jsonb_build_object(
      'name', m ->> 'full_name',
      'member_no', m ->> 'member_no',
      'status', m ->> 'status',
      'joined', joined,
      'zones', (
        select coalesce(jsonb_agg(z.data ->> 'name' order by (z.data ->> 'code')::int), '[]')
        from public.sync_records mz
        join public.sync_records z on z.org_id = org and z.tbl = 'zones'
          and z.key = mz.data ->> 'zone_id'
        where mz.org_id = org and mz.tbl = 'member_zones'
          and mz.data ->> 'member_id' = mid and mz.data ->> 'deleted_at' is null
      )
    ),
    'dues', dues,
    'payments', (
      select coalesce(jsonb_agg(x order by x ->> 'paid_on' desc), '[]')
      from (
        select jsonb_build_object(
          'receipt_no', p.data ->> 'receipt_no',
          'paid_on', left(p.data ->> 'paid_on', 10),
          'type', ct.data ->> 'name',
          'period', p.data ->> 'period',
          'amount', (p.data ->> 'amount')::bigint,
          'method', p.data ->> 'method'
        ) as x
        from public.sync_records p
        left join public.sync_records ct on ct.org_id = org
          and ct.tbl = 'contribution_types'
          and ct.key = p.data ->> 'contribution_type_id'
        where p.org_id = org and p.tbl = 'payments'
          and p.data ->> 'member_id' = mid and p.data ->> 'status' = 'valid'
        order by p.data ->> 'paid_on' desc
        limit 100
      ) s
    ),
    'updated', (select max(r.updated_at) from public.sync_records r
                where r.org_id = org)
  );
end;
$$;

-- The web portal, now built on member_statement.
create or replace function public.portal_statement(
  org text,
  member_no text,
  phone text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.sync_orgs;
  m jsonb;
  mid text;
  guard_key text := 'portal:' || upper(trim(member_no));
  g public.sync_sign_in_guard;
  digits text := right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9);
begin
  select * into o from public.sync_orgs where upper(slug) = upper(trim(org));
  if o.id is null then
    raise exception 'Organisation not found.' using errcode = 'P0001';
  end if;
  select * into g from public.sync_sign_in_guard
  where org_id = o.id and username = guard_key;
  if g.locked_until is not null and g.locked_until > now() then
    raise exception 'Too many tries. Please wait 15 minutes and try again.'
      using errcode = 'P0001';
  end if;
  select r.data, r.key into m, mid from public.sync_records r
  where r.org_id = o.id and r.tbl = 'members'
    and upper(r.data ->> 'member_no') = upper(trim(member_no))
    and r.data ->> 'deleted_at' is null
  limit 1;
  if m is null or length(digits) < 9 or not (
    right(regexp_replace(coalesce(m ->> 'phone', ''), '\D', '', 'g'), 9) = digits
    or right(regexp_replace(coalesce(m ->> 'whatsapp', ''), '\D', '', 'g'), 9) = digits
  ) then
    insert into public.sync_sign_in_guard as x (org_id, username, failures)
    values (o.id, guard_key, 1)
    on conflict (org_id, username) do update
      set failures = case when x.failures + 1 >= 5 then 0 else x.failures + 1 end,
          locked_until = case when x.failures + 1 >= 5
                              then now() + interval '15 minutes' end;
    -- Returned rather than raised, so the failed try is kept.
    return jsonb_build_object('error',
      'Member ID and phone number do not match our records.');
  end if;
  update public.sync_sign_in_guard set failures = 0, locked_until = null
  where org_id = o.id and username = guard_key;
  return public.member_statement(o.id, mid);
end;
$$;

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
  if s.id is null or s.revoked_at is not null then
    raise exception 'Please sign in again.' using errcode = 'P0001';
  end if;
  update public.member_sessions set last_seen_at = now() where id = s.id;
  return s;
end;
$$;

-- Everything an ordinary member sees in the app.
create or replace function public.member_home(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.member_sessions := public.member_session_for(token);
  org uuid := s.org_id;
  mid text := s.member_key;
begin
  if not exists (select 1 from public.member_accounts a
                 where a.org_id = org and a.member_key = mid
                   and a.password_hash is not null) then
    update public.member_sessions set revoked_at = now() where id = s.id;
    raise exception 'Your sign-in was reset. Please activate your account again.'
      using errcode = 'P0001';
  end if;
  return public.member_statement(org, mid) || jsonb_build_object(
    'officer', (public.member_access(org, mid) ->> 'officer')::boolean,
    'welfare', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'case_no', c.data ->> 'case_no',
        'type', t.data ->> 'name',
        'status', c.data ->> 'status',
        'amount', (c.data ->> 'amount')::bigint,
        'occurred_on', left(c.data ->> 'occurred_on', 10),
        'beneficiary', c.data ->> 'beneficiary')
        order by c.data ->> 'occurred_on' desc), '[]')
      from public.sync_records c
      left join public.sync_records t on t.org_id = org
        and t.tbl = 'welfare_case_types' and t.key = c.data ->> 'case_type_id'
      where c.org_id = org and c.tbl = 'welfare_cases'
        and c.data ->> 'member_id' = mid and c.data ->> 'deleted_at' is null
    ),
    'events', (
      select coalesce(jsonb_agg(x order by x ->> 'date'), '[]') from (
        select jsonb_build_object(
          'name', e.data ->> 'name', 'kind', 'event',
          'date', left(e.data ->> 'starts_on', 10),
          'venue', e.data ->> 'venue',
          'description', e.data ->> 'description') as x
        from public.sync_records e
        where e.org_id = org and e.tbl = 'events'
          and e.data ->> 'deleted_at' is null
          and coalesce(e.data ->> 'status', '') <> 'cancelled'
          and left(e.data ->> 'starts_on', 10)::date >= current_date
        union all
        select jsonb_build_object(
          'name', g.data ->> 'title', 'kind', 'meeting',
          'date', left(g.data ->> 'held_on', 10),
          'venue', g.data ->> 'venue',
          'description', g.data ->> 'agenda')
        from public.sync_records g
        where g.org_id = org and g.tbl = 'meetings'
          and g.data ->> 'deleted_at' is null
          and g.data ->> 'kind' = 'general'
          and left(g.data ->> 'held_on', 10)::date >= current_date
      ) s
    ),
    'executives', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'name', mm.data ->> 'full_name',
        'position', p.data ->> 'title',
        'level', p.data ->> 'level',
        'zone', z.data ->> 'name')
        order by (p.data ->> 'sort_order')::int, z.data ->> 'code',
          mm.data ->> 'full_name'), '[]')
      from public.sync_records x
      join public.sync_records p on p.org_id = org
        and p.tbl = 'executive_positions' and p.key = x.data ->> 'position_id'
      join public.sync_records mm on mm.org_id = org and mm.tbl = 'members'
        and mm.key = x.data ->> 'member_id'
      left join public.sync_records z on z.org_id = org and z.tbl = 'zones'
        and z.key = x.data ->> 'zone_id'
      where x.org_id = org and x.tbl = 'executives'
        and x.data ->> 'deleted_at' is null and x.data ->> 'ended_on' is null
    ),
    'directory', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'name', d.data ->> 'full_name',
        'zones', (
          select coalesce(jsonb_agg(z.data ->> 'name'
            order by (z.data ->> 'code')::int), '[]')
          from public.sync_records mz
          join public.sync_records z on z.org_id = org and z.tbl = 'zones'
            and z.key = mz.data ->> 'zone_id'
          where mz.org_id = org and mz.tbl = 'member_zones'
            and mz.data ->> 'member_id' = d.key
            and mz.data ->> 'deleted_at' is null))
        order by d.data ->> 'full_name'), '[]')
      from public.sync_records d
      where d.org_id = org and d.tbl = 'members'
        and d.data ->> 'deleted_at' is null
        and d.data ->> 'status' = 'active'
    ),
    'announcements', '[]'::jsonb
  );
end;
$$;

create or replace function public.member_sign_out(token text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.member_sessions set revoked_at = now()
  where token_hash = public.sync_hash(token) and revoked_at is null
$$;

-- An officer clears a member's sign-in so they activate again with their
-- phone number. The Founder and General Secretary may reset anyone; zone
-- officers only members of their own zones.
create or replace function public.member_reset_sign_in(
  token text,
  member text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
  acc jsonb;
  zones jsonb;
  who text;
begin
  if d.member_key is null then
    if not d.is_admin then
      raise exception 'Only officers who can reset sign-ins may do this.'
        using errcode = 'P0001';
    end if;
    who := d.name;
  else
    acc := public.member_access(d.org_id, d.member_key);
    if not (acc -> 'permissions') ? 'signin.reset' then
      raise exception 'Your role cannot reset sign-ins.' using errcode = 'P0001';
    end if;
    zones := acc -> 'zones';
    if zones is not null and jsonb_typeof(zones) = 'array' and not exists (
      select 1 from public.sync_records mz
      where mz.org_id = d.org_id and mz.tbl = 'member_zones'
        and mz.data ->> 'member_id' = member
        and mz.data ->> 'deleted_at' is null
        and zones ? (mz.data ->> 'zone_id')
    ) then
      raise exception 'You can only reset members of your own zone.'
        using errcode = 'P0001';
    end if;
    select r.data ->> 'full_name' into who from public.sync_records r
    where r.org_id = d.org_id and r.tbl = 'members' and r.key = d.member_key;
  end if;
  update public.member_accounts
  set password_hash = null, reset_at = now(), reset_by = who
  where org_id = d.org_id and member_key = member;
  update public.member_sessions set revoked_at = now()
  where org_id = d.org_id and member_key = member and revoked_at is null;
  update public.sync_devices set revoked_at = now()
  where org_id = d.org_id and member_key = member and revoked_at is null
    and id <> d.id;
  return jsonb_build_object('ok', true);
end;
$$;

-- Whether a member has activated, for the officer's member page.
create or replace function public.member_account_status(
  token text,
  member text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
  a public.member_accounts;
begin
  select * into a from public.member_accounts
  where org_id = d.org_id and member_key = member;
  return jsonb_build_object(
    'activated', a.password_hash is not null,
    'activated_at', a.activated_at,
    'reset_at', a.reset_at,
    'reset_by', a.reset_by
  );
end;
$$;

revoke all on function public.member_record(uuid, text) from public, anon, authenticated;
revoke all on function public.member_access(uuid, text) from public, anon, authenticated;
revoke all on function public.sync_enroll_device(uuid, text, boolean, text) from public, anon, authenticated;
revoke all on function public.member_statement(uuid, text) from public, anon, authenticated;
revoke all on function public.member_session_for(text) from public, anon, authenticated;
revoke all on function public.member_auth_lookup(text, text, text) from public, anon, authenticated;
revoke all on function public.member_auth_complete(uuid, text, boolean, text, text, boolean) from public, anon, authenticated;
grant execute on function public.member_auth_lookup(text, text, text) to service_role;
grant execute on function public.member_auth_complete(uuid, text, boolean, text, text, boolean) to service_role;
grant execute on function public.member_home(text) to anon, authenticated;
grant execute on function public.member_sign_out(text) to anon, authenticated;
grant execute on function public.member_reset_sign_in(text, text) to anon, authenticated;
grant execute on function public.member_account_status(text, text) to anon, authenticated;
