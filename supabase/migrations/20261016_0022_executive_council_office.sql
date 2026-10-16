-- The Executive Council's office (the eighth committee office).
--
-- The Founder and General Secretary lead; the Directors (and Patron), the
-- Treasurer, the Organizer and the Auditor are members. The office reuses
-- the existing 'board' chat (the Auditor now joins it through the office)
-- and shows the association's money this month and this year, the cash
-- position, decisions waiting, how each committee office is getting on,
-- and the executive meetings. The leads can add the standard Executive
-- Council meeting steps to a meeting.

insert into public.office_committees (org_id, key, name, purpose, source,
  member_roles, lead_roles, checklist, sort, chat)
select null, 'executive', 'Executive Council',
  'Runs the association between general meetings and oversees its money and committees.',
  'roles', '{director,patron,treasurer,organizer,auditor}',
  '{founder,general_secretary}',
  '["Agree the agenda with the Founder",
    "Send the agenda and papers to members a week before",
    "Review the Treasurer''s finance report",
    "Review the committee reports",
    "Hold the meeting and take attendance",
    "Record the decisions and who does what",
    "Follow up on every decision before the next meeting"]'::jsonb,
  -1, 'board'
where not exists (select 1 from public.office_committees
                  where org_id is null and key = 'executive');

-- The Executive Council's view: money this month and this year, the cash
-- position since records began, decisions waiting, and the other offices.
create or replace function public.office_executive(org uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with periods as (
    select to_char(current_date, 'YYYY-MM') as m,
      to_char(current_date, 'YYYY') as y
  ),
  money as (
    select 'in' as dir, p.data ->> 'paid_on' as on_,
      (p.data ->> 'amount')::bigint as amount
    from public.sync_records p
    where p.org_id = org and p.tbl = 'payments'
      and p.data ->> 'deleted_at' is null
      and coalesce(p.data ->> 'status', 'valid') = 'valid'
    union all
    select 'out', e.data ->> 'paid_on', (e.data ->> 'amount')::bigint
    from public.sync_records e
    where e.org_id = org and e.tbl = 'expenses'
      and e.data ->> 'deleted_at' is null
      and coalesce(e.data ->> 'status', 'valid') = 'valid'
    union all
    select 'welfare', w.data ->> 'paid_on', (w.data ->> 'amount')::bigint
    from public.sync_records w
    where w.org_id = org and w.tbl = 'welfare_cases'
      and w.data ->> 'deleted_at' is null and w.data ->> 'status' = 'paid'
  )
  select jsonb_build_object(
    'month', (select m from periods),
    'year', (select y from periods),
    'money', (select jsonb_build_object(
        'month_in', coalesce(sum(amount) filter (where dir = 'in'
          and left(on_, 7) = periods.m), 0),
        'month_out', coalesce(sum(amount) filter (where dir = 'out'
          and left(on_, 7) = periods.m), 0),
        'month_welfare', coalesce(sum(amount) filter (where dir = 'welfare'
          and left(on_, 7) = periods.m), 0),
        'year_in', coalesce(sum(amount) filter (where dir = 'in'
          and left(on_, 4) = periods.y), 0),
        'year_out', coalesce(sum(amount) filter (where dir <> 'in'
          and left(on_, 4) = periods.y), 0),
        'balance', coalesce(sum(case when dir = 'in' then amount
          else -amount end), 0))
      from periods left join money on true group by periods.m, periods.y),
    'waiting', jsonb_build_object(
      'dues_amounts', (select count(*) from public.sync_records t
                       where t.org_id = org and t.tbl = 'contribution_types'
                         and t.data ->> 'deleted_at' is null
                         and t.data ->> 'proposed_amount' is not null),
      'unset_dues', (select count(*) from public.sync_records t
                     where t.org_id = org and t.tbl = 'contribution_types'
                       and t.data ->> 'deleted_at' is null
                       and t.data ->> 'frequency' = 'monthly'
                       and coalesce((t.data ->> 'is_active')::int, 1) = 1
                       and t.data ->> 'amount' is null
                       and t.data ->> 'proposed_amount' is null),
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
    'offices', (select coalesce(jsonb_agg(jsonb_build_object(
        'key', c.key, 'name', c.name,
        'members', jsonb_array_length(public.office_members(org, c)),
        'open', (select count(*) from public.office_tasks t
                 where t.org_id = org and t.committee = c.key
                   and t.deleted_at is null and t.status = 'open'),
        'late', (select count(*) from public.office_tasks t
                 where t.org_id = org and t.committee = c.key
                   and t.deleted_at is null and t.status = 'open'
                   and t.due_on < current_date),
        'last_at', (select max(l.at) from public.office_log l
                    where l.org_id = org and l.committee = c.key))
        order by c.sort, c.name), '[]')
      from public.office_defs(org) c where c.key <> 'executive'),
    'meetings', (select coalesce(jsonb_agg(x.v order by x.i), '[]')
      from jsonb_array_elements(
        public.office_meetings(org, null, 'executive')) with ordinality x(v, i)
      where x.v ->> 'kind' in ('executive', 'general')))
$$;
revoke all on function public.office_executive(uuid)
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
  elsif c.key = 'executive' then
    out := out || jsonb_build_object('executive', public.office_executive(org));
  end if;
  return out;
end;
$$;
-- The leads of the Secretariat, the Leadership Council or the Executive
-- Council: add the office's standard steps to a meeting, once per office.
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
  if me ->> 'committee' not in ('secretariat', 'leadership', 'executive') then
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
