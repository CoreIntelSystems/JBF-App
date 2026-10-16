-- The Organizing Committee's office (the third committee office).
--
-- The national Organizer leads; Zone Organizers and organizing helpers are
-- members. The office reuses the committee's existing 'organizing' chat,
-- shows the events (upcoming first, with attendance), and the Organizer can
-- add the standard event-planning steps to an event as tasks.

alter table public.office_tasks add column if not exists event_id text;
create index if not exists office_tasks_event on public.office_tasks (event_id);

insert into public.office_committees (org_id, key, name, purpose, source,
  member_roles, lead_roles, checklist, sort, chat)
select null, 'organizing', 'Organizing Committee',
  'Plans and runs the association''s events and meetings, and takes attendance.',
  'roles', '{zone_organizer,zone_organizing_helper}', '{organizer}',
  '["Agree the date, venue and budget",
    "Book the venue",
    "Arrange transport and accommodation",
    "Announce the event to members",
    "Arrange any Silver Collection",
    "Print or share the attendance QR codes",
    "Take attendance on the day",
    "Report attendance and spending after the event"]'::jsonb, 3, 'organizing'
where not exists (select 1 from public.office_committees
                  where org_id is null and key = 'organizing');

-- Events: planned ones soonest first, then the latest held or cancelled,
-- with attendance and how far each event's steps have got.
create or replace function public.office_events(org uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.key, 'name', e.data ->> 'name', 'kind', e.data ->> 'kind',
    'starts_on', e.data ->> 'starts_on', 'venue', e.data ->> 'venue',
    'status', coalesce(e.data ->> 'status', 'planned'),
    'present', (select count(*) from public.sync_records a
                where a.org_id = org and a.tbl = 'attendance_records'
                  and a.data ->> 'occasion_id' = e.key
                  and a.data ->> 'deleted_at' is null
                  and a.data ->> 'status' = 'present'),
    'steps', (select count(*) from public.office_tasks t
              where t.org_id = org and t.event_id = e.key
                and t.deleted_at is null),
    'steps_done', (select count(*) from public.office_tasks t
                   where t.org_id = org and t.event_id = e.key
                     and t.deleted_at is null and t.status = 'done'))
    order by e.rank, case when e.rank = 0 then e.data ->> 'starts_on' end,
      e.data ->> 'starts_on' desc), '[]')
  from (
    (select r.*, 0 as rank
     from public.sync_records r
     where r.org_id = org and r.tbl = 'events'
       and r.data ->> 'deleted_at' is null
       and coalesce(r.data ->> 'status', 'planned') = 'planned'
     order by r.data ->> 'starts_on' limit 20)
    union all
    (select r.*, 1
     from public.sync_records r
     where r.org_id = org and r.tbl = 'events'
       and r.data ->> 'deleted_at' is null
       and coalesce(r.data ->> 'status', 'planned') <> 'planned'
     order by r.data ->> 'starts_on' desc limit 5)
  ) e
$$;
revoke all on function public.office_events(uuid)
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
        'event_id', t.event_id,
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
  end if;
  return out;
end;
$$;


-- The lead: add the committee's standard planning steps to an event, once.
create or replace function public.office_add_event_steps(
  token text, committee text, event text
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
    raise exception 'Only the Organizer can do this.' using errcode = 'P0001';
  end if;
  if me ->> 'committee' <> 'organizing' then
    raise exception 'This office has no events.' using errcode = 'P0001';
  end if;
  select r.data ->> 'name' into title from public.sync_records r
  where r.org_id = org and r.tbl = 'events' and r.key = event
    and r.data ->> 'deleted_at' is null;
  if title is null then
    raise exception 'No such event.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.office_tasks t
             where t.org_id = org and t.event_id = event
               and t.deleted_at is null) then
    raise exception 'This event already has its steps.'
      using errcode = 'P0001';
  end if;
  for step in select jsonb_array_elements_text(me -> 'checklist') loop
    n := n + 1;
    insert into public.office_tasks (org_id, committee, event_id, title,
      sort, created_by)
    values (org, me ->> 'committee', event, step, n, me ->> 'member');
  end loop;
  perform public.office_write_log(me, 'Added the event steps', title);
  return jsonb_build_object('added', n);
end;
$$;
revoke all on function public.office_add_event_steps(text, text, text)
  from public;
grant execute on function public.office_add_event_steps(text, text, text)
  to anon, authenticated;
