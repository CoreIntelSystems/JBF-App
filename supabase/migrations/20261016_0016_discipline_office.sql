-- The Disciplinary Committee's office (the second committee office).
--
-- Members are whoever holds the Disciplinary Committee roles; the new
-- Chairperson and Secretary roles lead. The office reuses the committee's
-- existing chat ('discipline'), shows the case book (complaints sent by the
-- zones and warnings sent), and the leads can add the standard hearing
-- steps to a complaint as tasks.

alter table public.office_committees add column if not exists chat text;
alter table public.office_tasks add column if not exists case_id uuid
  references public.discipline_cases (id);
create index if not exists office_tasks_case on public.office_tasks (case_id);

insert into public.office_committees (org_id, key, name, purpose, source,
  member_roles, lead_roles, checklist, sort, chat)
select null, 'discipline', 'Disciplinary Committee',
  'Hears complaints sent by the zones, decides on them and sends warnings to members.',
  'roles', '{discipline_member}', '{discipline_chair,discipline_secretary}',
  '["Acknowledge the complaint and tell the zone that sent it",
    "Tell the member about the complaint",
    "Hear the member''s side",
    "Hear the zone executives and any witnesses",
    "Decide as a committee and record the decision in Minutes",
    "Send the warning, or close the complaint"]'::jsonb, 2, 'discipline'
where not exists (select 1 from public.office_committees
                  where org_id is null and key = 'discipline');

-- Role names drop the committee's own name, so the office lists
-- "Chairperson", "Secretary" and "Member".
create or replace function public.office_members(
  org uuid, c public.office_committees
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with m as (
    select o.member_key as key, o.role,
      case o.role when 'chair' then 'Chairperson'
                  when 'secretary' then 'Secretary' else 'Member' end
        as role_name,
      case o.role when 'chair' then 0 when 'secretary' then 1 else 2 end
        as rank
    from public.election_officers o
    where c.source = 'election_officers' and o.org_id = org
      and o.ended_at is null
    union all
    (select distinct on (a.data ->> 'member_id') a.data ->> 'member_id',
      r.data ->> 'key',
      -- "Disciplinary Committee Chairperson" shows as "Chairperson".
      coalesce(nullif(trim(replace(r.data ->> 'name', c.name, '')), ''),
        'Member'),
      array_position(c.lead_roles || c.member_roles, r.data ->> 'key')
    from public.sync_records a
    join public.sync_records r on r.org_id = org and r.tbl = 'roles'
      and r.key = a.data ->> 'role_id'
    where c.source = 'roles' and a.org_id = org
      and a.tbl = 'role_assignments' and a.data ->> 'deleted_at' is null
      and (r.data ->> 'key') = any (c.member_roles || c.lead_roles)
      and (a.data ->> 'starts_on' is null
           or left(a.data ->> 'starts_on', 10)::date <= current_date)
      and (a.data ->> 'ends_on' is null
           or left(a.data ->> 'ends_on', 10)::date > current_date)
    order by a.data ->> 'member_id',
      array_position(c.lead_roles || c.member_roles, r.data ->> 'key'))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'key', m.key, 'name', coalesce(x.data ->> 'full_name', 'Member'),
    'member_no', x.data ->> 'member_no', 'role', m.role,
    'role_name', m.role_name, 'lead', m.role = any (c.lead_roles))
    order by m.rank, x.data ->> 'full_name'), '[]')
  from m
  left join public.sync_records x on x.org_id = org and x.tbl = 'members'
    and x.key = m.key
  where x.data ->> 'deleted_at' is null
$$;


-- The case book: counts and the latest complaints and warnings, open ones
-- first, with how far each complaint's steps have got.
create or replace function public.office_cases(org uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'open', count(*) filter (where d.kind = 'complaint' and d.status = 'open'),
    'closed', count(*) filter (where d.kind = 'complaint' and d.status = 'closed'),
    'warnings', count(*) filter (where d.kind = 'warning'),
    'recent', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', x.id, 'member', x.member_key,
        'member_name', m.data ->> 'full_name',
        'member_no', m.data ->> 'member_no',
        'kind', x.kind, 'details', x.details, 'by', x.by_name,
        'status', x.status, 'at', x.created_at,
        'steps', (select count(*) from public.office_tasks t
                  where t.case_id = x.id and t.deleted_at is null),
        'steps_done', (select count(*) from public.office_tasks t
                       where t.case_id = x.id and t.deleted_at is null
                         and t.status = 'done'))
        order by x.status = 'closed', x.created_at desc), '[]')
      from (select * from public.discipline_cases y
            where y.org_id = org
            order by y.status = 'closed', y.created_at desc limit 30) x
      left join public.sync_records m on m.org_id = org
        and m.tbl = 'members' and m.key = x.member_key))
  from public.discipline_cases d
  where d.org_id = org
$$;
revoke all on function public.office_cases(uuid)
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
  end if;
  return out;
end;
$$;


-- Leads: add the committee's standard hearing steps to a complaint, once.
create or replace function public.office_add_case_steps(
  token text, committee text, case_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  org uuid := (me ->> 'org')::uuid;
  d public.discipline_cases;
  who text;
  step text;
  n int := 0;
begin
  if not (me ->> 'lead')::boolean then
    raise exception 'Only the Chairperson or Secretary can do this.'
      using errcode = 'P0001';
  end if;
  if me ->> 'committee' <> 'discipline' then
    raise exception 'This office has no cases.' using errcode = 'P0001';
  end if;
  select * into d from public.discipline_cases x
  where x.id = office_add_case_steps.case_id and x.org_id = org
    and x.kind = 'complaint';
  if d.id is null then
    raise exception 'No such complaint.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.office_tasks t
             where t.case_id = d.id and t.deleted_at is null) then
    raise exception 'This complaint already has its steps.'
      using errcode = 'P0001';
  end if;
  who := coalesce(public.office_member_name(org, d.member_key), 'a member');
  for step in select jsonb_array_elements_text(me -> 'checklist') loop
    n := n + 1;
    insert into public.office_tasks (org_id, committee, case_id, title,
      sort, created_by)
    values (org, me ->> 'committee', d.id, step, n, me ->> 'member');
  end loop;
  perform public.office_write_log(me, 'Added the hearing steps',
    'Complaint about ' || who);
  return jsonb_build_object('added', n);
end;
$$;
revoke all on function public.office_add_case_steps(text, text, uuid)
  from public;
grant execute on function public.office_add_case_steps(text, text, uuid)
  to anon, authenticated;

-- An office can use a chat that already exists (the Disciplinary
-- Committee's 'discipline' chat) instead of a new one; its leads join it.
create or replace function public.chat_channels_for(me jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with base as (select public.chat_channels_base(me) as b)
  select b || coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', coalesce(c.chat, 'office:' || c.key),
      'name', c.name, 'post', true) order by c.sort, c.name)
    from public.office_defs((me ->> 'org')::uuid) c
    where me ->> 'member' is not null
      and public.office_seat(me, c) is not null
      and not exists (
        select 1 from jsonb_array_elements(b) x
        where x ->> 'id' = coalesce(c.chat, 'office:' || c.key))), '[]'::jsonb)
  from base
$$;
revoke all on function public.chat_channels_for(jsonb)
  from public, anon, authenticated;
