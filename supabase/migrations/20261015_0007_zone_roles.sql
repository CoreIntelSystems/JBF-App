-- Zone Mayors add extra zone roles from their phones (zone helpers).

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
      or exists (select 1 from jsonb_array_elements(rows) y
        where y ->> 't' = 'roles' and y ->> 'k' = x -> 'd' ->> 'role_id'
          and y -> 'd' ->> 'level' = 'zone')
    -- A Zone Mayor's own zone roles: never a wider role, and only access
    -- the Mayor has.
    when x ->> 't' = 'roles' then x -> 'd' ->> 'level' = 'zone'
      and (x -> 'd' ->> 'permissions')::jsonb
        <@ (public.member_access(d.org_id, d.member_key) -> 'permissions')
      and not exists (select 1 from public.sync_records ro
        where ro.org_id = d.org_id and ro.tbl = 'roles' and ro.key = x ->> 'k'
          and ro.data ->> 'level' <> 'zone')
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
