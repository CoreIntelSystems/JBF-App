-- The roles a member holds today, as short labels for their ID card:
-- "Zone Mayor (Zone 5)", "Treasurer". The plain member role is left out.
create or replace function public.member_role_labels(org uuid, member_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with held as (
    select a.data ->> 'role_id' as role_id,
      nullif(a.data ->> 'zone_ids', '') as zone_ids,
      a.data ->> 'starts_on' as starts
    from public.sync_records a
    where a.org_id = org and a.tbl = 'role_assignments'
      and a.data ->> 'member_id' = member_key
      and a.data ->> 'deleted_at' is null
      and (a.data ->> 'starts_on' is null
           or left(a.data ->> 'starts_on', 10)::date <= current_date)
      and (a.data ->> 'ends_on' is null
           or left(a.data ->> 'ends_on', 10)::date > current_date)
    union all
    select u.data ->> 'role_id', nullif(u.data ->> 'zone_ids', ''), null
    from public.sync_records u
    where u.org_id = org and u.tbl = 'users'
      and u.data ->> 'member_id' = member_key
      and u.data ->> 'deleted_at' is null
      and coalesce((u.data ->> 'is_active')::int, 0) = 1
  ), labelled as (
    select distinct on (r.data ->> 'name', h.zone_ids)
      (r.data ->> 'name') || coalesce(' (' || (
        select string_agg(coalesce(z.data ->> 'name', zid), ', ')
        from unnest(string_to_array(h.zone_ids, ',')) zid
        left join public.sync_records z
          on z.org_id = org and z.tbl = 'zones' and z.key = zid
      ) || ')', '') as label,
      h.starts
    from held h
    join public.sync_records r on r.org_id = org and r.tbl = 'roles'
      and r.key = h.role_id
    where r.data ->> 'key' <> 'member'
      and r.data ->> 'level' not in ('member', 'system')
  )
  select coalesce(jsonb_agg(label order by starts nulls last, label), '[]')
  from labelled
$$;
revoke all on function public.member_role_labels(uuid, text)
  from public, anon, authenticated;

create or replace function public.member_home(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  home jsonb := public.member_home_base(token);
  s public.member_sessions := public.member_session_for(token);
begin
  return home || public.member_notices(s.org_id, s.member_key)
    || jsonb_build_object(
      'roles', public.member_role_labels(s.org_id, s.member_key));
end;
$$;
grant execute on function public.member_home(text) to anon, authenticated;
