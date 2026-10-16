-- The Secretariat's office (the fifth committee office).
--
-- The General Secretary leads; Zone Secretaries are members. The office
-- reuses the existing 'secretariat' chat and shows the membership register
-- (counts by status, members still without a zone or phone, sign-ins) and
-- the meetings with their minutes and attendance. Zone Secretaries see
-- their own zones only. The General Secretary can add the standard
-- meeting steps to a meeting as tasks.

alter table public.office_tasks add column if not exists meeting_id text;
create index if not exists office_tasks_meeting
  on public.office_tasks (meeting_id);

insert into public.office_committees (org_id, key, name, purpose, source,
  member_roles, lead_roles, checklist, sort, chat)
select null, 'secretariat', 'Secretariat',
  'Keeps the membership register, prepares meetings and keeps the minutes.',
  'roles', '{zone_secretary}', '{general_secretary}',
  '["Agree the date and agenda with the Chairperson",
    "Send the notice and agenda to members",
    "Prepare the attendance register or QR codes",
    "Take attendance on the day",
    "Write the minutes",
    "Share the minutes and have them adopted at the next meeting",
    "Follow up on the decisions taken"]'::jsonb, 5, 'secretariat'
where not exists (select 1 from public.office_committees
                  where org_id is null and key = 'secretariat');

-- The membership register for the office. zones is null for the whole
-- association, else the zone ids the caller looks after.
create or replace function public.office_register(org uuid, zones jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with m as (
    select r.key, r.data,
      exists (select 1 from public.member_accounts a
              where a.org_id = org and a.member_key = r.key
                and a.activated_at is not null) as ready,
      not exists (
        select 1 from public.sync_records mz
        join public.sync_records zn on zn.org_id = org and zn.tbl = 'zones'
          and zn.key = mz.data ->> 'zone_id'
        where mz.org_id = org and mz.tbl = 'member_zones'
          and mz.data ->> 'deleted_at' is null
          and mz.data ->> 'member_id' = r.key
          and lower(zn.data ->> 'name') <> 'unassigned') as no_zone
    from public.sync_records r
    where r.org_id = org and r.tbl = 'members'
      and r.data ->> 'deleted_at' is null
      and (zones is null or exists (
        select 1 from public.sync_records z
        where z.org_id = org and z.tbl = 'member_zones'
          and z.data ->> 'deleted_at' is null
          and z.data ->> 'member_id' = r.key
          and zones ? (z.data ->> 'zone_id')))
  )
  select jsonb_build_object(
    'active', (select count(*) from m where data ->> 'status' = 'active'),
    'inactive', (select count(*) from m where data ->> 'status' = 'inactive'),
    'suspended', (select count(*) from m
                  where data ->> 'status' = 'suspended'),
    'deceased', (select count(*) from m where data ->> 'status' = 'deceased'),
    'ready', (select count(*) from m
              where ready and data ->> 'status' = 'active'),
    'no_zone', (select count(*) from m
                where no_zone and data ->> 'status' = 'active'),
    'no_phone', (select count(*) from m
                 where coalesce(data ->> 'phone', '') = ''
                   and data ->> 'status' = 'active'),
    'no_emergency', (select count(*) from m
                     where coalesce(data ->> 'emergency_phone', '') = ''
                       and data ->> 'status' = 'active'),
    'joined_30', (select count(*) from m
                  where left(data ->> 'date_joined', 10)
                        >= (current_date - 30)::text),
    'changes', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', x.data ->> 'full_name', 'member_no', x.data ->> 'member_no',
        'status', x.data ->> 'status', 'on', x.data ->> 'status_date')
        order by x.data ->> 'status_date' desc nulls last), '[]')
      from (select * from m where data ->> 'status' <> 'active'
            order by data ->> 'status_date' desc nulls last limit 5) x))
$$;
revoke all on function public.office_register(uuid, jsonb)
  from public, anon, authenticated;

-- Meetings: upcoming soonest first, then the latest held, with attendance,
-- whether minutes were written, and how far each meeting's steps have got.
-- Zone Secretaries see their zones' meetings and association-wide ones.
create or replace function public.office_meetings(org uuid, zones jsonb)
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
                and t.deleted_at is null),
    'steps_done', (select count(*) from public.office_tasks t
                   where t.org_id = org and t.meeting_id = e.key
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
revoke all on function public.office_meetings(uuid, jsonb)
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
        'meeting_id', t.meeting_id,
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
  end if;
  return out;
end;
$$;

-- The General Secretary: add the standard steps to a meeting, once.
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
    raise exception 'Only the General Secretary can do this.'
      using errcode = 'P0001';
  end if;
  if me ->> 'committee' <> 'secretariat' then
    raise exception 'This office has no meetings.' using errcode = 'P0001';
  end if;
  select r.data ->> 'title' into title from public.sync_records r
  where r.org_id = org and r.tbl = 'meetings' and r.key = meeting
    and r.data ->> 'deleted_at' is null;
  if title is null then
    raise exception 'No such meeting.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.office_tasks t
             where t.org_id = org and t.meeting_id = meeting
               and t.deleted_at is null) then
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
revoke all on function public.office_add_meeting_steps(text, text, text)
  from public;
grant execute on function public.office_add_meeting_steps(text, text, text)
  to anon, authenticated;
