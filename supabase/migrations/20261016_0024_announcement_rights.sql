-- Who makes announcements (Agent PRO, 2026-10-16).
--
-- General announcements, read by every member: the Founder, the General
-- Secretary, the Welfare Secretary, the Organising Committee Secretary and
-- the Secretaries of the other committees (Disciplinary, Electoral
-- Commission). Zone Secretaries are in the Secretariat, so they do not; they
-- and their Zone Mayors announce to their own zones only.
--
-- The rule is a table so other organisations can set their own: scope 'all'
-- for general announcements, 'zone' for the zones the role is held in. The
-- old 'announce.post' permission still counts as general, so the Founder
-- can add someone from the Roles screen.
--
-- Zone announcements are their own read-only chat per zone
-- ('announce:<zone id>'), shown to that zone's members on their home page.
-- A committee office's notices to all members can be posted by the office's
-- leads (as before) and by anyone who makes general announcements.

create table if not exists public.announce_roles (
  id uuid primary key default gen_random_uuid(),
  org_id uuid,
  role_key text not null,
  scope text not null check (scope in ('all', 'zone'))
);
create unique index if not exists announce_roles_key
  on public.announce_roles (coalesce(org_id::text, ''), role_key);
alter table public.announce_roles enable row level security;

insert into public.announce_roles (org_id, role_key, scope)
select null, k, s from (values
  ('founder', 'all'), ('general_secretary', 'all'),
  ('welfare_secretary', 'all'), ('organizing_secretary', 'all'),
  ('discipline_secretary', 'all'), ('ec_secretary', 'all'),
  ('zone_secretary', 'zone'), ('zone_mayor', 'zone')) v(k, s)
where not exists (select 1 from public.announce_roles a
                  where a.org_id is null and a.role_key = v.k);

-- The Organising Committee Secretary leads the Organizing office with the
-- Organizer.
update public.office_committees
set lead_roles = lead_roles || '{organizing_secretary}'
where org_id is null and key = 'organizing'
  and not ('organizing_secretary' = any (lead_roles));

-- What the caller may announce: {all: bool, zones: [zone ids]}.
create or replace function public.announce_rights(me jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with org as (select (me ->> 'org')::uuid as id),
  defs as (
    select a.role_key, a.scope from public.announce_roles a, org
    where a.org_id = org.id
       or (a.org_id is null and not exists (
             select 1 from public.announce_roles o where o.org_id = org.id))
  )
  select jsonb_build_object(
    'all', coalesce((me ->> 'all')::boolean, false)
      or coalesce((me -> 'permissions') ? 'announce.post', false)
      or exists (select 1 from defs d
                 where d.scope = 'all' and (me -> 'roles') ? d.role_key)
      or exists (select 1 from public.election_officers o, org
                 where o.org_id = org.id and o.ended_at is null
                   and o.role = 'secretary'
                   and o.member_key = me ->> 'member'),
    'zones', coalesce((
      select jsonb_agg(distinct z)
      from jsonb_array_elements(coalesce(me -> 'role_zones', '[]')) x
      cross join unnest(string_to_array(x ->> 'zones', ',')) z
      where x ->> 'key' in (select d.role_key from defs d where d.scope = 'zone')
        and z <> ''), '[]'::jsonb))
$$;
revoke all on function public.announce_rights(jsonb)
  from public, anon, authenticated;

-- A zone's announcements chat for its members (read) and for whoever may
-- announce there (post).
create or replace function public.announce_zone_channels(me jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with r as (select public.announce_rights(me) -> 'zones' as zones),
  mine as (
    select mz.data ->> 'zone_id' as zid
    from public.sync_records mz
    where mz.org_id = (me ->> 'org')::uuid and mz.tbl = 'member_zones'
      and mz.data ->> 'deleted_at' is null
      and me ->> 'member' is not null
      and mz.data ->> 'member_id' = me ->> 'member'
    union
    select jsonb_array_elements_text(r.zones) from r
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', 'announce:' || z.key,
      'name', (z.data ->> 'name') || ' announcements',
      'post', r.zones ? z.key)
      order by coalesce((z.data ->> 'code')::int, 999)), '[]'::jsonb)
  from public.sync_records z, r
  where z.org_id = (me ->> 'org')::uuid and z.tbl = 'zones'
    and z.data ->> 'deleted_at' is null
    and lower(z.data ->> 'name') <> 'unassigned'
    and z.key in (select zid from mine)
$$;
revoke all on function public.announce_zone_channels(jsonb)
  from public, anon, authenticated;

do $do$
declare d text := pg_get_functiondef('public.chat_channels_base(jsonb)'::regprocedure);
begin
  d := replace(d,
    $r$'post', coalesce((me -> 'permissions') ? 'announce.post', false));$r$,
    $r$'post', (public.announce_rights(me) ->> 'all')::boolean)
    || public.announce_zone_channels(me);$r$);
  if position('announce_zone_channels' in d) = 0 then
    raise exception 'chat_channels_base patch did not match';
  end if;
  execute d;

  d := pg_get_functiondef('public.chat_send(text,text,text,text)'::regprocedure);
  d := replace(d, 'Only the Founder and General Secretary post here.',
    'Only the people who make these announcements can post here.');
  if position('make these announcements' in d) = 0 then
    raise exception 'chat_send patch did not match';
  end if;
  execute d;

  d := pg_get_functiondef('public.office_home(text,text)'::regprocedure);
  d := replace(d, $r$'lead', (me ->> 'lead')::boolean,$r$,
    $r$'lead', (me ->> 'lead')::boolean,
    'can_notice', (me ->> 'lead')::boolean
      or (public.announce_rights(me) ->> 'all')::boolean,$r$);
  if position('can_notice' in d) = 0 then
    raise exception 'office_home patch did not match';
  end if;
  execute d;
end
$do$;

-- Members see general announcements and those of their own zones.
create or replace function public.member_notices(org uuid, mid text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'announcements', (
      select coalesce(jsonb_agg(x.body order by x.created_at desc), '[]')
      from (select case when m.channel = 'announcements' then m.body
                   else coalesce((select z.data ->> 'name'
                                  from public.sync_records z
                                  where z.org_id = org and z.tbl = 'zones'
                                    and 'announce:' || z.key = m.channel),
                                 'Zone') || ': ' || m.body end as body,
              m.created_at
            from public.chat_messages m
            where m.org_id = org and m.deleted_at is null
              and (m.channel = 'announcements' or m.channel in (
                select 'announce:' || (mz.data ->> 'zone_id')
                from public.sync_records mz
                where mz.org_id = org and mz.tbl = 'member_zones'
                  and mz.data ->> 'deleted_at' is null
                  and mz.data ->> 'member_id' = mid))
            order by m.created_at desc limit 10) x),
    'warnings', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'details', c.details, 'at', c.created_at)
        order by c.created_at desc), '[]')
      from public.discipline_cases c
      where c.org_id = org and c.member_key = mid and c.kind = 'warning')
  )
$$;

-- A committee's notice to every member: the office's leads, or anyone who
-- makes general announcements.
create or replace function public.office_notice_post(
  token text, committee text, title text, body text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  nid uuid;
begin
  if not ((me ->> 'lead')::boolean
          or (public.announce_rights(me) ->> 'all')::boolean) then
    raise exception 'Only the Chairperson or Secretary can post notices.'
      using errcode = 'P0001';
  end if;
  if length(trim(coalesce(title, ''))) < 2
     or length(trim(coalesce(body, ''))) = 0 then
    raise exception 'Give the notice a title and write it.'
      using errcode = 'P0001';
  end if;
  insert into public.office_notices (org_id, committee, title, body, by_key)
  values ((me ->> 'org')::uuid, me ->> 'committee', trim(title),
    left(trim(body), 4000), me ->> 'member')
  returning id into nid;
  perform public.office_write_log(me, 'Posted a notice', trim(title));
  return jsonb_build_object('id', nid);
end;
$$;
