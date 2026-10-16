-- The Leadership Council's office (the seventh committee office).
--
-- The Founder and General Secretary lead; the Directors (and Patron), the
-- Organizer, the Treasurer, the Welfare Chairman and every zone executive
-- are members. The office reuses the existing 'leadership' chat (the
-- Welfare Chairman now joins it through the office) and shows how each
-- zone is doing, what waits for a decision across the association, and
-- the executive and general meetings. The leads can add the standard
-- Council meeting steps to a meeting.

insert into public.office_committees (org_id, key, name, purpose, source,
  member_roles, lead_roles, checklist, sort, chat)
select null, 'leadership', 'Leadership Council',
  'Brings the national and zone executives together to steer the association.',
  'roles',
  '{director,patron,organizer,treasurer,welfare_chairman,zone_mayor,zone_deputy,zone_secretary,zone_treasurer,zone_organizer,zone_welfare_officer}',
  '{founder,general_secretary}',
  '["Circulate the agenda to the Council",
    "Collect a report from every Zone Mayor",
    "Collect reports from the committees",
    "Hold the meeting and take attendance",
    "Record the decisions and who does what",
    "Follow up on every decision before the next meeting"]'::jsonb,
  0, 'leadership'
where not exists (select 1 from public.office_committees
                  where org_id is null and key = 'leadership');

-- Meetings: upcoming soonest first, then the latest held, with attendance,
-- whether minutes were written, and how far each meeting's steps have got.
-- Zone Secretaries see their zones' meetings and association-wide ones.
-- Steps are counted for the given office only (each office has its own).
create or replace function public.office_meetings(org uuid, zones jsonb,
  committee text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with mt as (
    select r.key, r.data
    from public.sync_records r
    where r.org_id = org and r.tbl = 'meetings'
      and r.data ->> 'deleted_at' is null
      and (zones is null or r.data ->> 'zone_id' is null
           or zones ? (r.data ->> 'zone_id'))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.key, 'title', e.data ->> 'title', 'kind', e.data ->> 'kind',
    'held_on', e.data ->> 'held_on', 'venue', e.data ->> 'venue',
    'zone', (select z.data ->> 'name' from public.sync_records z
             where z.org_id = org and z.tbl = 'zones'
               and z.key = e.data ->> 'zone_id'),
    'upcoming', e.rank = 0,
    'has_agenda', coalesce(e.data ->> 'agenda', '') <> '',
    'has_minutes', coalesce(e.data ->> 'minutes', '') <> '',
    'present', (select count(*) from public.sync_records a
                where a.org_id = org and a.tbl = 'attendance_records'
                  and a.data ->> 'occasion_id' = e.key
                  and a.data ->> 'deleted_at' is null
                  and a.data ->> 'status' = 'present'),
    'steps', (select count(*) from public.office_tasks t
              where t.org_id = org and t.meeting_id = e.key
                and t.committee = office_meetings.committee
                and t.deleted_at is null),
    'steps_done', (select count(*) from public.office_tasks t
                   where t.org_id = org and t.meeting_id = e.key
                     and t.committee = office_meetings.committee
                     and t.deleted_at is null and t.status = 'done'))
    order by e.rank, case when e.rank = 0 then e.data ->> 'held_on' end,
      e.data ->> 'held_on' desc), '[]')
  from (
    (select mt.*, 0 as rank from mt
     where left(mt.data ->> 'held_on', 10) >= current_date::text
     order by mt.data ->> 'held_on' limit 20)
    union all
    (select mt.*, 1 from mt
     where left(mt.data ->> 'held_on', 10) < current_date::text
     order by mt.data ->> 'held_on' desc limit 8)
  ) e
$$;
revoke all on function public.office_meetings(uuid, jsonb, text)
  from public, anon, authenticated;

-- The Secretariat's meetings (kept for office_home's existing call).
create or replace function public.office_meetings(org uuid, zones jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select public.office_meetings(org, zones, 'secretariat')
$$;

-- The Council's view of the association: each active zone with its
-- members, executives in post and dues paid this month, and what waits
-- for a decision.
create or replace function public.office_council(org uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with month as (select to_char(current_date, 'YYYY-MM') as m),
  exec_roles as (
    select r.key as role_id, r.data ->> 'key' as role_key,
      r.data ->> 'name' as role_name
    from public.sync_records r
    where r.org_id = org and r.tbl = 'roles'
      and r.data ->> 'key' in ('zone_mayor', 'zone_deputy', 'zone_secretary',
        'zone_treasurer', 'zone_organizer', 'zone_welfare_officer')
  ),
  held as (
    select e.role_key, a.data ->> 'member_id' as member_id, z.zone_id
    from public.sync_records a
    join exec_roles e on e.role_id = a.data ->> 'role_id'
    cross join lateral unnest(string_to_array(
      coalesce(a.data ->> 'zone_ids', ''), ',')) as z(zone_id)
    where a.org_id = org and a.tbl = 'role_assignments'
      and a.data ->> 'deleted_at' is null
      and (a.data ->> 'ends_on' is null
           or left(a.data ->> 'ends_on', 10)::date > current_date)
  ),
  dues as (
    select t.key from public.sync_records t
    where t.org_id = org and t.tbl = 'contribution_types'
      and t.data ->> 'deleted_at' is null
      and t.data ->> 'frequency' = 'monthly'
      and coalesce((t.data ->> 'applies_to_all')::int, 1) = 1
      and coalesce((t.data ->> 'is_active')::int, 1) = 1
    order by t.data ->> 'created_at' limit 1
  ),
  zones as (
    select z.key, z.data ->> 'name' as name,
      coalesce((z.data ->> 'code')::int, 999) as code
    from public.sync_records z
    where z.org_id = org and z.tbl = 'zones'
      and z.data ->> 'deleted_at' is null
      and coalesce((z.data ->> 'is_active')::int, 1) = 1
      and lower(z.data ->> 'name') <> 'unassigned'
  ),
  zm as (
    select zn.key as zone_id, mz.data ->> 'member_id' as member_id
    from zones zn
    join public.sync_records mz on mz.org_id = org
      and mz.tbl = 'member_zones' and mz.data ->> 'deleted_at' is null
      and mz.data ->> 'zone_id' = zn.key
    join public.sync_records m on m.org_id = org and m.tbl = 'members'
      and m.key = mz.data ->> 'member_id' and m.data ->> 'status' = 'active'
      and m.data ->> 'deleted_at' is null
  )
  select jsonb_build_object(
    'month', (select m from month),
    'zones', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', zn.key, 'name', zn.name,
        'members', (select count(distinct member_id) from zm
                    where zm.zone_id = zn.key),
        'executives', (select count(distinct role_key) from held h
                       where h.zone_id = zn.key),
        'mayor', (select public.office_member_name(org, h.member_id)
                  from held h where h.zone_id = zn.key
                    and h.role_key = 'zone_mayor' limit 1),
        'missing', (select coalesce(jsonb_agg(e.role_name
                      order by e.role_key), '[]')
                    from exec_roles e
                    where not exists (select 1 from held h
                                      where h.zone_id = zn.key
                                        and h.role_key = e.role_key)),
        'dues_paid', (select count(distinct p.data ->> 'member_id')
                      from public.sync_records p, month, dues
                      where p.org_id = org and p.tbl = 'payments'
                        and p.data ->> 'deleted_at' is null
                        and coalesce(p.data ->> 'status', 'valid') = 'valid'
                        and p.data ->> 'contribution_type_id' = dues.key
                        and coalesce(p.data ->> 'period',
                              left(p.data ->> 'paid_on', 7)) = month.m
                        and p.data ->> 'member_id' in (
                          select member_id from zm
                          where zm.zone_id = zn.key)))
        order by zn.code, zn.name), '[]') from zones zn),
    'positions', (select coalesce(jsonb_agg(x.role_name order by x.role_key),
        '[]')
      from (select r.data ->> 'key' as role_key, r.data ->> 'name' as role_name
            from public.sync_records r
            where r.org_id = org and r.tbl = 'roles'
              and r.data ->> 'key' in ('general_secretary', 'treasurer',
                'organizer', 'welfare_chairman', 'welfare_secretary',
                'welfare_treasurer')
              and not exists (
                select 1 from public.sync_records a
                where a.org_id = org and a.tbl = 'role_assignments'
                  and a.data ->> 'deleted_at' is null
                  and a.data ->> 'role_id' = r.key
                  and (a.data ->> 'ends_on' is null
                       or left(a.data ->> 'ends_on', 10)::date
                          > current_date))) x),
    'waiting', jsonb_build_object(
      'dues_amounts', (select count(*) from public.sync_records t
                       where t.org_id = org and t.tbl = 'contribution_types'
                         and t.data ->> 'deleted_at' is null
                         and t.data ->> 'proposed_amount' is not null),
      'benefit_amounts', (select count(*) from public.sync_records t
                          where t.org_id = org
                            and t.tbl = 'welfare_case_types'
                            and t.data ->> 'deleted_at' is null
                            and t.data ->> 'proposed_amount' is not null),
      'welfare_cases', (select count(*) from public.sync_records w
                        where w.org_id = org and w.tbl = 'welfare_cases'
                          and w.data ->> 'deleted_at' is null
                          and w.data ->> 'status' = 'pending'),
      'complaints', (select count(*) from public.discipline_cases d
                     where d.org_id = org and d.kind = 'complaint'
                       and d.status = 'open')),
    'meetings', (select coalesce(jsonb_agg(x.v order by x.i), '[]')
      from jsonb_array_elements(
        public.office_meetings(org, null, 'leadership')) with ordinality x(v, i)
      where x.v ->> 'kind' in ('executive', 'general')))
$$;
revoke all on function public.office_council(uuid)
  from public, anon, authenticated;

create or replace function public.office_home(token text, committee text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  org uuid := (me ->> 'org')::uuid;
  c public.office_committees;
  out jsonb;
begin
  select * into c from public.office_defs(org) d where d.key = committee;
  out := jsonb_build_object(
    'key', c.key, 'name', c.name, 'purpose', c.purpose,
    'me', me ->> 'member', 'role', me ->> 'role',
    'role_name', me ->> 'role_name', 'lead', (me ->> 'lead')::boolean,
    'has_checklist', jsonb_array_length(c.checklist) > 0,
    'chat', coalesce(c.chat, 'office:' || c.key),
    'members', public.office_members(org, c),
    'tasks', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.id, 'title', t.title, 'details', t.details,
        'election_id', t.election_id, 'case_id', t.case_id,
        'event_id', t.event_id, 'welfare_case_id', t.welfare_case_id,
        'meeting_id', t.meeting_id, 'period', t.period,
        'assignee', t.assignee_key,
        'assignee_name', public.office_member_name(org, t.assignee_key),
        'due_on', t.due_on, 'status', t.status,
        'by', public.office_member_name(org, t.created_by),
        'mine', t.created_by = me ->> 'member',
        'done_by', public.office_member_name(org, t.done_by),
        'done_at', t.done_at)
        order by t.status = 'done', t.due_on nulls last, t.sort, t.created_at), '[]')
      from public.office_tasks t
      where t.org_id = org and t.committee = c.key and t.deleted_at is null),
    'notes', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', n.id, 'kind', n.kind, 'title', n.title, 'body', n.body,
        'met_on', n.met_on, 'at', n.created_at, 'updated_at', n.updated_at,
        'by', public.office_member_name(org, n.by_key),
        'mine', n.by_key = me ->> 'member')
        order by coalesce(n.met_on, n.created_at::date) desc,
          n.created_at desc), '[]')
      from (select * from public.office_notes x
            where x.org_id = org and x.committee = c.key
              and x.deleted_at is null
            order by x.created_at desc limit 200) n),
    'notices', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', n.id, 'title', n.title, 'body', n.body, 'at', n.created_at,
        'by', public.office_member_name(org, n.by_key),
        'withdrawn', n.withdrawn_at is not null)
        order by n.created_at desc), '[]')
      from (select * from public.office_notices x
            where x.org_id = org and x.committee = c.key
            order by x.created_at desc limit 50) n),
    'log', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'at', l.at, 'by', public.office_member_name(org, l.by_key),
        'event', l.event, 'detail', l.detail) order by l.id desc), '[]')
      from (select * from public.office_log x
            where x.org_id = org and x.committee = c.key
            order by x.id desc limit 40) l));
  if c.source = 'election_officers' then
    out := out || jsonb_build_object(
      'roll', public.office_voter_roll(org),
      'elections', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', e.id, 'title', e.title, 'status', public.election_state(e),
          'closes_at', e.closes_at, 'opened_at', e.opened_at,
          'voters', (select count(*) from public.election_voters v
                     where v.election_id = e.id),
          'voted', case when e.status = 'draft' then null else
            (select count(distinct d.member_key)
             from public.election_voted d
             join public.election_posts p on p.id = d.post_id
             where p.election_id = e.id) end,
          'steps', (select count(*) from public.office_tasks t
                    where t.election_id = e.id and t.deleted_at is null),
          'steps_done', (select count(*) from public.office_tasks t
                         where t.election_id = e.id and t.deleted_at is null
                           and t.status = 'done'))
          order by e.created_at desc), '[]')
        from public.elections e
        where e.org_id = org and e.status <> 'cancelled'));
  elsif c.key = 'discipline' then
    out := out || jsonb_build_object('cases', public.office_cases(org));
  elsif c.key = 'organizing' then
    out := out || jsonb_build_object('events', public.office_events(org));
  elsif c.key = 'welfare' then
    out := out || jsonb_build_object('welfare',
      public.office_welfare(org, case when jsonb_typeof(me -> 'zones') = 'array'
        then me -> 'zones' end));
  elsif c.key = 'secretariat' then
    out := out || jsonb_build_object(
      'register', public.office_register(org,
        case when jsonb_typeof(me -> 'zones') = 'array' then me -> 'zones' end),
      'meetings', public.office_meetings(org,
        case when jsonb_typeof(me -> 'zones') = 'array' then me -> 'zones' end));
  elsif c.key = 'treasury' then
    out := out || jsonb_build_object('treasury', public.office_treasury(org,
      case when jsonb_typeof(me -> 'zones') = 'array' then me -> 'zones' end));
  elsif c.key = 'leadership' then
    out := out || jsonb_build_object('council', public.office_council(org));
  end if;
  return out;
end;
$$;

-- The leads of the Secretariat or the Leadership Council: add the
-- office's standard steps to a meeting, once per office.
create or replace function public.office_add_meeting_steps(
  token text, committee text, meeting text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  org uuid := (me ->> 'org')::uuid;
  title text;
  step text;
  n int := 0;
begin
  if not (me ->> 'lead')::boolean then
    raise exception 'Only the % leads can do this.', me ->> 'committee_name'
      using errcode = 'P0001';
  end if;
  if me ->> 'committee' not in ('secretariat', 'leadership') then
    raise exception 'This office has no meetings.' using errcode = 'P0001';
  end if;
  select r.data ->> 'title' into title from public.sync_records r
  where r.org_id = org and r.tbl = 'meetings' and r.key = meeting
    and r.data ->> 'deleted_at' is null;
  if title is null then
    raise exception 'No such meeting.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.office_tasks t
             where t.org_id = org and t.committee = me ->> 'committee'
               and t.meeting_id = meeting and t.deleted_at is null) then
    raise exception 'This meeting already has its steps.'
      using errcode = 'P0001';
  end if;
  for step in select jsonb_array_elements_text(me -> 'checklist') loop
    n := n + 1;
    insert into public.office_tasks (org_id, committee, meeting_id, title,
      sort, created_by)
    values (org, me ->> 'committee', meeting, step, n, me ->> 'member');
  end loop;
  perform public.office_write_log(me, 'Added the meeting steps', title);
  return jsonb_build_object('added', n);
end;
$$;
