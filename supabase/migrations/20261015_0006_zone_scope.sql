-- Zone executives' phones only hold their own zones: members of those zones
-- and their payments, welfare cases and attendance, plus the shared lists
-- (zones, roles, dues types, events...). Phones of people with a wider role,
-- and phones joined with a code or an old username, still get everything.

-- The zones a phone is limited to, or null for no limit.
create or replace function public.sync_device_zones(d public.sync_devices)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  acc jsonb;
begin
  if d.member_key is null then
    return null;
  end if;
  acc := public.member_access(d.org_id, d.member_key);
  -- No executive role any more: no members at all. The phone still gets
  -- the role changes, so its sign-in stops working too.
  if not coalesce((acc ->> 'officer')::boolean, false) then
    return '[]'::jsonb;
  end if;
  -- Only zone roles: their zones (none if no zones were recorded).
  if not exists (select 1 from jsonb_array_elements(acc -> 'roles') r
                 where r ->> 'key' <> 'member' and r ->> 'level' <> 'zone') then
    return case when jsonb_typeof(acc -> 'zones') = 'array'
                then acc -> 'zones' else '[]'::jsonb end;
  end if;
  return null;
end;
$$;

-- Members who belong to one of [zones].
create or replace function public.sync_zone_members(org uuid, zones jsonb)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct r.data ->> 'member_id'), '{}')
  from public.sync_records r
  where r.org_id = org and r.tbl = 'member_zones'
    and r.data ->> 'deleted_at' is null
    and zones ? (r.data ->> 'zone_id')
$$;

create or replace function public.sync_push(token text, rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
  zones jsonb := public.sync_device_zones(d);
  members text[];
  n int;
begin
  if jsonb_typeof(rows) <> 'array' or jsonb_array_length(rows) > 1000 then
    raise exception 'Send at most 1000 rows at a time.' using errcode = 'P0001';
  end if;
  if zones is not null then
    -- Members of the phone's zones, including ones added in this batch.
    members := public.sync_zone_members(d.org_id, zones) || coalesce((
      select array_agg(x -> 'd' ->> 'member_id')
      from jsonb_array_elements(rows) x
      where x ->> 't' = 'member_zones' and zones ? (x -> 'd' ->> 'zone_id')
    ), '{}');
  end if;
  insert into public.sync_records as r (org_id, tbl, key, data, updated_at,
    pushed_by)
  select d.org_id, x ->> 't', x ->> 'k', x -> 'd', (x ->> 'u')::timestamptz,
    d.id
  from jsonb_array_elements(rows) as x
  where zones is null or case
    when x ->> 't' = 'members' then x ->> 'k' = any (members)
    when x ->> 't' in ('member_zones', 'payments', 'welfare_cases',
                       'attendance_records')
      then x -> 'd' ->> 'member_id' = any (members)
    when x ->> 't' = 'role_assignments' then exists (
      select 1 from public.sync_records ro
      where ro.org_id = d.org_id and ro.tbl = 'roles'
        and ro.key = x -> 'd' ->> 'role_id' and ro.data ->> 'level' = 'zone')
    when x ->> 't' in ('audit_logs', 'events', 'meetings', 'executives')
      then true
    else false
  end
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
-- [scope] changes whenever the phone's zones or their membership change;
-- the phone then downloads again from the start.
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
  zones jsonb := public.sync_device_zones(d);
  members text[];
  scope text := 'all';
  result jsonb;
  last_seq bigint;
  lim int := least(greatest(max_rows, 1), 2000);
begin
  if zones is not null then
    members := public.sync_zone_members(d.org_id, zones);
    scope := md5(zones::text || coalesce((
      select max(r.seq) from public.sync_records r
      where r.org_id = d.org_id and r.tbl = 'member_zones'
        and zones ? (r.data ->> 'zone_id')
        and r.pushed_by is distinct from d.id), 0)::text);
  end if;
  with page as (
    select r.tbl, r.key, r.data, r.updated_at, r.seq, r.pushed_by,
      zones is null or case
        when r.tbl = 'members' then r.key = any (members)
        when r.tbl in ('member_zones', 'payments', 'welfare_cases',
                       'attendance_records')
          then r.data ->> 'member_id' = any (members)
        when r.tbl in ('users', 'audit_logs', 'expenses') then false
        when r.tbl = 'meetings'
          then r.data ->> 'zone_id' is null or zones ? (r.data ->> 'zone_id')
        else true
      end as visible
    from public.sync_records r
    where r.org_id = d.org_id and r.seq > since
    order by r.seq
    limit lim
  )
  select
    coalesce(jsonb_agg(jsonb_build_object('t', tbl, 'k', key, 'd', data,
      'u', updated_at) order by seq)
      filter (where pushed_by is distinct from d.id and visible), '[]'::jsonb),
    max(seq)
  into result, last_seq
  from page;
  return jsonb_build_object(
    'rows', result,
    'last_seq', coalesce(last_seq, since),
    'more', exists (select 1 from public.sync_records r
             where r.org_id = d.org_id and r.seq > coalesce(last_seq, since)),
    'scope', scope,
    'zones', zones
  );
end;
$$;

revoke all on function public.sync_device_zones(public.sync_devices) from public, anon, authenticated;
revoke all on function public.sync_zone_members(uuid, jsonb) from public, anon, authenticated;
