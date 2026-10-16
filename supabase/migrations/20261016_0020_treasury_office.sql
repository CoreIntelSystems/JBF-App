-- The Treasury's office (the sixth committee office).
--
-- The Treasurer leads; Zone Treasurers and the Welfare Treasurer are
-- members. The office reuses the existing 'treasury' chat and shows this
-- month's money: received by type and by collector, how many members have
-- paid this month's dues, spending and welfare payouts, amounts waiting
-- for approval, and voided receipts. Zone Treasurers see only payments of
-- members in their zones (no association-wide spending). The Treasurer can
-- add the standard month-end steps to a month as tasks.

alter table public.office_tasks add column if not exists period text;
create index if not exists office_tasks_period on public.office_tasks (period);

insert into public.office_committees (org_id, key, name, purpose, source,
  member_roles, lead_roles, checklist, sort, chat)
select null, 'treasury', 'Treasury',
  'Collects and banks the association''s money, pays approved costs and reports on the accounts.',
  'roles', '{zone_treasurer,welfare_treasurer}', '{treasurer}',
  '["Collect the money and receipt books from the Zone Treasurers",
    "Bank or send by mobile money all cash collected",
    "Check receipts against the money banked",
    "Record every expense with its voucher",
    "Pay the approved welfare cases",
    "Review any voided receipts",
    "Prepare the monthly finance report",
    "Present the report to the executives"]'::jsonb, 6, 'treasury'
where not exists (select 1 from public.office_committees
                  where org_id is null and key = 'treasury');

-- This month's money for the office. zones is null for the whole
-- association, else the zone ids the caller looks after.
create or replace function public.office_treasury(org uuid, zones jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with month as (select to_char(current_date, 'YYYY-MM') as m),
  scope as (
    select r.key from public.sync_records r
    where r.org_id = org and r.tbl = 'members'
      and r.data ->> 'deleted_at' is null
      and (zones is null or exists (
        select 1 from public.sync_records z
        where z.org_id = org and z.tbl = 'member_zones'
          and z.data ->> 'deleted_at' is null
          and z.data ->> 'member_id' = r.key
          and zones ? (z.data ->> 'zone_id')))
  ),
  pay as (
    select p.key, p.data from public.sync_records p, month
    where p.org_id = org and p.tbl = 'payments'
      and p.data ->> 'deleted_at' is null
      and (zones is null or p.data ->> 'member_id' in (select key from scope))
      and left(p.data ->> 'paid_on', 7) = month.m
  ),
  ok as (select * from pay where coalesce(data ->> 'status', 'valid') = 'valid'),
  dues as (
    select t.key, t.data from public.sync_records t
    where t.org_id = org and t.tbl = 'contribution_types'
      and t.data ->> 'deleted_at' is null
      and t.data ->> 'frequency' = 'monthly'
      and coalesce((t.data ->> 'applies_to_all')::int, 1) = 1
      and coalesce((t.data ->> 'is_active')::int, 1) = 1
    order by t.data ->> 'created_at' limit 1
  )
  select jsonb_build_object(
    'month', (select m from month),
    'zone_only', zones is not null,
    'received', (select coalesce(sum((data ->> 'amount')::bigint), 0) from ok),
    'receipts', (select count(*) from ok),
    'by_type', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', x.name, 'amount', x.amount, 'count', x.n)
        order by x.amount desc), '[]')
      from (select coalesce(t.data ->> 'name', 'Other') as name,
              sum((ok.data ->> 'amount')::bigint) as amount, count(*) as n
            from ok left join public.sync_records t on t.org_id = org
              and t.tbl = 'contribution_types'
              and t.key = ok.data ->> 'contribution_type_id'
            group by 1) x),
    'by_collector', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', x.name, 'amount', x.amount, 'count', x.n)
        order by x.amount desc), '[]')
      from (select coalesce(data ->> 'collector_name', 'Unknown') as name,
              sum((data ->> 'amount')::bigint) as amount, count(*) as n
            from ok group by 1) x),
    'voided', (select count(*) from pay
               where data ->> 'status' = 'voided'),
    'dues', (select jsonb_build_object(
        'name', d.data ->> 'name',
        'amount', (d.data ->> 'amount')::bigint,
        'paid', (select count(distinct ok.data ->> 'member_id') from ok
                 where ok.data ->> 'contribution_type_id' = d.key
                   and coalesce(ok.data ->> 'period', (select m from month))
                       = (select m from month)),
        'active', (select count(*) from scope s
                   join public.sync_records m on m.org_id = org
                     and m.tbl = 'members' and m.key = s.key
                   where m.data ->> 'status' = 'active'))
      from dues d),
    'spent', case when zones is null then (
        select coalesce(sum((e.data ->> 'amount')::bigint), 0)
        from public.sync_records e, month
        where e.org_id = org and e.tbl = 'expenses'
          and e.data ->> 'deleted_at' is null
          and coalesce(e.data ->> 'status', 'valid') = 'valid'
          and left(e.data ->> 'paid_on', 7) = month.m) end,
    'welfare_paid', case when zones is null then (
        select coalesce(sum((w.data ->> 'amount')::bigint), 0)
        from public.sync_records w, month
        where w.org_id = org and w.tbl = 'welfare_cases'
          and w.data ->> 'deleted_at' is null
          and w.data ->> 'status' = 'paid'
          and left(w.data ->> 'paid_on', 7) = month.m) end,
    'to_pay', case when zones is null then (
        select coalesce(sum((w.data ->> 'amount')::bigint), 0)
        from public.sync_records w
        where w.org_id = org and w.tbl = 'welfare_cases'
          and w.data ->> 'deleted_at' is null
          and w.data ->> 'status' = 'approved') end,
    'proposals', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', t.data ->> 'name',
        'amount', (t.data ->> 'amount')::bigint,
        'proposed', (t.data ->> 'proposed_amount')::bigint,
        'by', t.data ->> 'proposed_by_name')), '[]')
      from public.sync_records t
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
    'months', (select jsonb_agg(jsonb_build_object(
        'period', p,
        'steps', (select count(*) from public.office_tasks t
                  where t.org_id = org and t.committee = 'treasury'
                    and t.period = p and t.deleted_at is null),
        'steps_done', (select count(*) from public.office_tasks t
                       where t.org_id = org and t.committee = 'treasury'
                         and t.period = p and t.deleted_at is null
                         and t.status = 'done')) order by p desc)
      from unnest(array[to_char(current_date, 'YYYY-MM'),
        to_char(current_date - interval '1 month', 'YYYY-MM')]) p))
$$;
revoke all on function public.office_treasury(uuid, jsonb)
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
  end if;
  return out;
end;
$$;

-- The Treasurer: add the standard month-end steps to a month, once.
create or replace function public.office_add_month_steps(
  token text, committee text, period text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  org uuid := (me ->> 'org')::uuid;
  step text;
  n int := 0;
begin
  if not (me ->> 'lead')::boolean then
    raise exception 'Only the Treasurer can do this.' using errcode = 'P0001';
  end if;
  if me ->> 'committee' <> 'treasury' then
    raise exception 'This office has no month-end.' using errcode = 'P0001';
  end if;
  if period !~ '^\d{4}-(0[1-9]|1[0-2])$' then
    raise exception 'No such month.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.office_tasks t
             where t.org_id = org and t.committee = 'treasury'
               and t.period = office_add_month_steps.period
               and t.deleted_at is null) then
    raise exception 'This month already has its steps.'
      using errcode = 'P0001';
  end if;
  for step in select jsonb_array_elements_text(me -> 'checklist') loop
    n := n + 1;
    insert into public.office_tasks (org_id, committee, period, title,
      sort, created_by)
    values (org, me ->> 'committee', office_add_month_steps.period, step, n,
      me ->> 'member');
  end loop;
  perform public.office_write_log(me, 'Added the month-end steps', period);
  return jsonb_build_object('added', n);
end;
$$;
revoke all on function public.office_add_month_steps(text, text, text)
  from public;
grant execute on function public.office_add_month_steps(text, text, text)
  to anon, authenticated;
