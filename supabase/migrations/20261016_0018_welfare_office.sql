-- The Welfare Committee's office (the fourth committee office).
--
-- The Welfare Chairman and Secretary lead; the Treasurer, committee members
-- and the zone welfare officers and helpers are members. The office reuses
-- the committee's existing 'welfare' chat, shows the welfare cases (only
-- the caller's zones for zone officers) and any benefit amounts waiting
-- for approval, and a lead can add the standard steps to a case as tasks.

alter table public.office_tasks add column if not exists welfare_case_id text;
create index if not exists office_tasks_welfare_case
  on public.office_tasks (welfare_case_id);

insert into public.office_committees (org_id, key, name, purpose, source,
  member_roles, lead_roles, checklist, sort, chat)
select null, 'welfare', 'Welfare Committee',
  'Looks after members in times of need: checks each case, approves the benefit and pays it.',
  'roles',
  '{welfare_treasurer,welfare_member,zone_welfare_officer,zone_welfare_helper}',
  '{welfare_chairman,welfare_secretary}',
  '["Confirm the details with the member''s zone",
    "Check the member is in good standing",
    "Prepare the case with the fixed benefit",
    "Approve the case (Chairman, or Secretary if the Chairman is away)",
    "Pay the benefit and record the payout",
    "Visit or call the member and family"]'::jsonb, 4, 'welfare'
where not exists (select 1 from public.office_committees
                  where org_id is null and key = 'welfare');

-- Welfare cases for the office: counts and amounts by status, benefit
-- amounts waiting for approval, and the latest cases with their steps.
-- zones is null for the whole association, else the zone ids the caller
-- looks after (cases of members in those zones only).
create or replace function public.office_welfare(org uuid, zones jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with cases as (
    select w.key, w.data
    from public.sync_records w
    where w.org_id = org and w.tbl = 'welfare_cases'
      and w.data ->> 'deleted_at' is null
      and (zones is null or exists (
        select 1 from public.sync_records z
        where z.org_id = org and z.tbl = 'member_zones'
          and z.data ->> 'deleted_at' is null
          and z.data ->> 'member_id' = w.data ->> 'member_id'
          and zones ? (z.data ->> 'zone_id')))
  ), types as (
    select t.key, t.data
    from public.sync_records t
    where t.org_id = org and t.tbl = 'welfare_case_types'
      and t.data ->> 'deleted_at' is null
      and coalesce((t.data ->> 'is_active')::int, 1) = 1
  )
  select jsonb_build_object(
    'pending', (select count(*) from cases
                where data ->> 'status' = 'pending'),
    'approved', (select count(*) from cases
                 where data ->> 'status' = 'approved'),
    'paid', (select count(*) from cases where data ->> 'status' = 'paid'),
    'rejected', (select count(*) from cases
                 where data ->> 'status' = 'rejected'),
    'to_pay', (select coalesce(sum((data ->> 'amount')::bigint), 0)
               from cases where data ->> 'status' = 'approved'),
    'paid_total', (select coalesce(sum((data ->> 'amount')::bigint), 0)
                   from cases where data ->> 'status' = 'paid'),
    'unset_types', (select count(*) from types
                    where data ->> 'benefit_amount' is null
                      and data ->> 'proposed_amount' is null),
    'proposals', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', key, 'name', data ->> 'name',
        'amount', (data ->> 'benefit_amount')::bigint,
        'proposed', (data ->> 'proposed_amount')::bigint,
        'by', data ->> 'proposed_by_name')
        order by (data ->> 'sort_order')::int nulls last, data ->> 'name'),
        '[]')
      from types where data ->> 'proposed_amount' is not null),
    'recent', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.key, 'case_no', c.data ->> 'case_no',
        'status', c.data ->> 'status',
        'amount', (c.data ->> 'amount')::bigint,
        'type', (select t.data ->> 'name' from public.sync_records t
                 where t.org_id = org and t.tbl = 'welfare_case_types'
                   and t.key = c.data ->> 'case_type_id'),
        'member_name', public.office_member_name(org, c.data ->> 'member_id'),
        'member_no', (select m.data ->> 'member_no'
                      from public.sync_records m
                      where m.org_id = org and m.tbl = 'members'
                        and m.key = c.data ->> 'member_id'),
        'beneficiary', c.data ->> 'beneficiary',
        'occurred_on', c.data ->> 'occurred_on',
        'by', c.data ->> 'prepared_by_name',
        'decided_by', c.data ->> 'decided_by_name',
        'steps', (select count(*) from public.office_tasks t
                  where t.org_id = org and t.welfare_case_id = c.key
                    and t.deleted_at is null),
        'steps_done', (select count(*) from public.office_tasks t
                       where t.org_id = org and t.welfare_case_id = c.key
                         and t.deleted_at is null and t.status = 'done'))
        order by c.data ->> 'status' = 'paid' or c.data ->> 'status' = 'rejected',
          c.data ->> 'created_at' desc), '[]')
      from (select * from cases
            order by data ->> 'status' in ('paid', 'rejected'),
              data ->> 'created_at' desc limit 20) c))
$$;
revoke all on function public.office_welfare(uuid, jsonb)
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
  end if;
  return out;
end;
$$;

-- A lead: add the committee's standard steps to a welfare case, once.
create or replace function public.office_add_welfare_steps(
  token text, committee text, welfare_case text
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
    raise exception 'Only the Welfare Chairman or Secretary can do this.'
      using errcode = 'P0001';
  end if;
  if me ->> 'committee' <> 'welfare' then
    raise exception 'This office has no welfare cases.' using errcode = 'P0001';
  end if;
  select coalesce(r.data ->> 'case_no', 'Case') || ' · '
    || coalesce(public.office_member_name(org, r.data ->> 'member_id'), '')
    into title
  from public.sync_records r
  where r.org_id = org and r.tbl = 'welfare_cases' and r.key = welfare_case
    and r.data ->> 'deleted_at' is null;
  if title is null then
    raise exception 'No such welfare case.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.office_tasks t
             where t.org_id = org and t.welfare_case_id = welfare_case
               and t.deleted_at is null) then
    raise exception 'This case already has its steps.' using errcode = 'P0001';
  end if;
  for step in select jsonb_array_elements_text(me -> 'checklist') loop
    n := n + 1;
    insert into public.office_tasks (org_id, committee, welfare_case_id,
      title, sort, created_by)
    values (org, me ->> 'committee', welfare_case, step, n, me ->> 'member');
  end loop;
  perform public.office_write_log(me, 'Added the case steps', title);
  return jsonb_build_object('added', n);
end;
$$;
revoke all on function public.office_add_welfare_steps(text, text, text)
  from public;
grant execute on function public.office_add_welfare_steps(text, text, text)
  to anon, authenticated;
