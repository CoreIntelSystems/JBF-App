-- Imported members may choose their zones themselves, but only once. After
-- that their Zone Secretary, the Founder or the General Secretary changes them.

create table if not exists public.member_zone_choice (
  org_id uuid not null,
  member_key text not null,
  chosen_at timestamptz not null default now(),
  primary key (org_id, member_key)
);
alter table public.member_zone_choice enable row level security;

create or replace function public.member_update_profile(
  token text,
  patch jsonb,
  zone_ids text[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.member_sessions := public.member_session_for(token);
  m public.sync_records;
  stamp text := to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS')
    || ' +00:00';
  allowed text[] := array['full_name', 'gender', 'date_of_birth', 'nationality',
    'occupation', 'marital_status', 'location', 'phone', 'whatsapp', 'email',
    'address', 'gps_address', 'emergency_name', 'emergency_phone'];
  k text;
  v text;
  clean jsonb := '{}';
  zids text[];
  zid text;
  z public.sync_records;
  mz public.sync_records;
  primary_zone text;
begin
  select * into m from public.sync_records r
  where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key;
  if m.key is null then
    raise exception 'Member not found.' using errcode = 'P0001';
  end if;
  if coalesce((m.data ->> 'self_edit')::int, 0) <> 1 then
    raise exception 'Your details are updated by your Zone Secretary.'
      using errcode = 'P0001';
  end if;

  if zone_ids is not null and exists (
    select 1 from public.member_zone_choice c
    where c.org_id = s.org_id and c.member_key = s.member_key
  ) then
    raise exception 'You have already chosen your zones. Your Zone Secretary can change them.'
      using errcode = 'P0001';
  end if;

  for k, v in select * from jsonb_each_text(coalesce(patch, '{}')) loop
    if not (k = any (allowed)) then
      continue;
    end if;
    v := nullif(btrim(v), '');
    if length(coalesce(v, '')) > 200 then
      raise exception 'That is too long.' using errcode = 'P0001';
    end if;
    if k = 'full_name' and v is null then
      raise exception 'Enter your full name.' using errcode = 'P0001';
    end if;
    clean := clean || jsonb_build_object(k, v);
  end loop;

  update public.sync_records r
  set data = r.data || clean || jsonb_build_object('updated_at', stamp),
      updated_at = now(), pushed_by = null
  where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key;

  if zone_ids is not null then
    select array_agg(distinct x) into zids from unnest(zone_ids) x;
    if coalesce(cardinality(zids), 0) < 1 then
      raise exception 'Choose at least 1 zone.' using errcode = 'P0001';
    end if;
    if cardinality(zids) > 2 then
      raise exception 'A member can belong to at most 2 zones.'
        using errcode = 'P0001';
    end if;
    foreach zid in array zids loop
      select * into z from public.sync_records r
      where r.org_id = s.org_id and r.tbl = 'zones' and r.key = zid
        and r.data ->> 'deleted_at' is null;
      if z.key is null then
        raise exception 'That zone does not exist.' using errcode = 'P0001';
      end if;
      if coalesce((z.data ->> 'is_active')::int, 0) <> 1 and not exists (
        select 1 from public.sync_records r
        where r.org_id = s.org_id and r.tbl = 'member_zones'
          and r.data ->> 'member_id' = s.member_key
          and r.data ->> 'zone_id' = zid and r.data ->> 'deleted_at' is null
      ) then
        raise exception 'That zone is not open for members yet.'
          using errcode = 'P0001';
      end if;
    end loop;
    primary_zone := zone_ids[1];
    -- Leave zones that were dropped.
    update public.sync_records r
    set data = r.data || jsonb_build_object('deleted_at', stamp,
          'updated_at', stamp, 'is_primary', 0),
        updated_at = now(), pushed_by = null
    where r.org_id = s.org_id and r.tbl = 'member_zones'
      and r.data ->> 'member_id' = s.member_key
      and r.data ->> 'deleted_at' is null
      and not (r.data ->> 'zone_id' = any (zids));
    foreach zid in array zids loop
      select * into mz from public.sync_records r
      where r.org_id = s.org_id and r.tbl = 'member_zones'
        and r.data ->> 'member_id' = s.member_key
        and r.data ->> 'zone_id' = zid
      order by (r.data ->> 'deleted_at' is null) desc limit 1;
      if mz.key is null then
        insert into public.sync_records (org_id, tbl, key, data, updated_at)
        values (s.org_id, 'member_zones',
          'mz' || substr(md5(s.member_key || ':' || zid), 1, 30),
          jsonb_build_object('id',
            'mz' || substr(md5(s.member_key || ':' || zid), 1, 30),
            'created_at', stamp, 'updated_at', stamp, 'created_by', null,
            'device_id', null, 'deleted_at', null,
            'member_id', s.member_key, 'zone_id', zid,
            'is_primary', (zid = primary_zone)::int, 'assigned_on', stamp),
          now());
      else
        update public.sync_records r
        set data = r.data || jsonb_build_object('deleted_at', null,
              'updated_at', stamp, 'is_primary', (zid = primary_zone)::int),
            updated_at = now(), pushed_by = null
        where r.org_id = mz.org_id and r.tbl = mz.tbl and r.key = mz.key;
      end if;
    end loop;
    insert into public.member_zone_choice (org_id, member_key)
    values (s.org_id, s.member_key) on conflict do nothing;
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.member_home(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  home jsonb := public.member_home_base(token);
  s public.member_sessions := public.member_session_for(token);
  m jsonb;
  editable boolean;
  out jsonb;
begin
  select r.data into m from public.sync_records r
  where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key;
  editable := coalesce((m ->> 'self_edit')::int, 0) = 1;
  out := home || public.member_notices(s.org_id, s.member_key)
    || jsonb_build_object(
      'roles', public.member_role_labels(s.org_id, s.member_key),
      'self_edit', editable);
  if editable then
    out := out || jsonb_build_object(
      'zones_locked', exists (
        select 1 from public.member_zone_choice c
        where c.org_id = s.org_id and c.member_key = s.member_key),
      'profile', jsonb_build_object(
        'full_name', m ->> 'full_name', 'gender', m ->> 'gender',
        'date_of_birth', left(m ->> 'date_of_birth', 10),
        'nationality', m ->> 'nationality', 'occupation', m ->> 'occupation',
        'marital_status', m ->> 'marital_status', 'location', m ->> 'location',
        'phone', m ->> 'phone', 'whatsapp', m ->> 'whatsapp',
        'email', m ->> 'email', 'address', m ->> 'address',
        'gps_address', m ->> 'gps_address',
        'emergency_name', m ->> 'emergency_name',
        'emergency_phone', m ->> 'emergency_phone'),
      'zone_options', coalesce((
        select jsonb_agg(jsonb_build_object('id', z.key,
          'code', (z.data ->> 'code')::int, 'name', z.data ->> 'name')
          order by (z.data ->> 'code')::int)
        from public.sync_records z
        where z.org_id = s.org_id and z.tbl = 'zones'
          and z.data ->> 'deleted_at' is null
          and coalesce((z.data ->> 'is_active')::int, 0) = 1), '[]'),
      'zone_ids', coalesce((
        select jsonb_agg(r.data ->> 'zone_id'
          order by (r.data ->> 'is_primary')::int desc)
        from public.sync_records r
        where r.org_id = s.org_id and r.tbl = 'member_zones'
          and r.data ->> 'member_id' = s.member_key
          and r.data ->> 'deleted_at' is null), '[]'));
  end if;
  return out;
end;
$$;
grant execute on function public.member_home(text) to anon, authenticated;
grant execute on function public.member_update_profile(text, jsonb, text[])
  to anon, authenticated;
