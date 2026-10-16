-- Committee offices: a shared workspace for each committee (tasks, meeting
-- minutes and decisions, notices to members, a private chat and a log).
--
-- Committees are rows, not code, so another organisation (or the next JBF
-- committee) is added with an insert:
--   * source 'election_officers': members are the Electoral Commission
--     appointees (election_officers), roles chair / secretary / member.
--   * source 'roles': members are whoever holds one of member_roles in
--     role_assignments; lead_roles may post notices and tidy up.
-- A row with org_id null is the default for every organisation; a row for
-- one organisation replaces the default with the same key.
--
-- Like elections, everything lives in the cloud and is reached only
-- through the functions below; the office is private to its members (the
-- Founder sees the Commission's names, not its working papers).

create table if not exists public.office_committees (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.sync_orgs (id),
  key text not null check (key ~ '^[a-z][a-z0-9_]{1,30}$'),
  name text not null,
  purpose text,
  source text not null default 'roles'
    check (source in ('election_officers', 'roles')),
  member_roles text[] not null default '{}',
  lead_roles text[] not null default '{}',
  -- Standard steps added to an election (or other piece of work) in one tap.
  checklist jsonb not null default '[]',
  sort int not null default 0,
  active boolean not null default true
);
create unique index if not exists office_committees_key
  on public.office_committees (
    coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid), key);
alter table public.office_committees enable row level security;
revoke all on public.office_committees from public, anon, authenticated;

insert into public.office_committees (org_id, key, name, purpose, source,
  lead_roles, checklist, sort)
select null, 'ec', 'Electoral Commission',
  'Prepares and runs the elections, keeps the voter roll and announces the results.',
  'election_officers', '{chair,secretary}',
  '["Agree the election timetable",
    "Publish the timetable and rules to members",
    "Check the voter roll and remind members to activate their sign-in",
    "Open nominations",
    "Close nominations and vet the candidates",
    "Publish the final list of candidates",
    "Add the candidates and photos to the ballot",
    "A second officer checks the ballot and opens voting",
    "Remind members to vote",
    "Close voting and publish the results",
    "Settle any ties or complaints"]'::jsonb, 1
where not exists (select 1 from public.office_committees
                  where org_id is null and key = 'ec');

create table if not exists public.office_tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  committee text not null,
  election_id uuid references public.elections (id),
  title text not null check (length(trim(title)) between 2 and 200),
  details text check (details is null or length(details) <= 4000),
  assignee_key text,
  due_on date,
  status text not null default 'open' check (status in ('open', 'done')),
  sort int not null default 0,
  created_by text not null,
  created_at timestamptz not null default now(),
  done_by text,
  done_at timestamptz,
  deleted_at timestamptz
);
create index if not exists office_tasks_committee
  on public.office_tasks (org_id, committee);

create table if not exists public.office_notes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  committee text not null,
  kind text not null check (kind in ('meeting', 'decision', 'note')),
  title text not null check (length(trim(title)) between 2 and 200),
  body text not null check (length(body) between 1 and 20000),
  met_on date,
  by_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  deleted_at timestamptz
);
create index if not exists office_notes_committee
  on public.office_notes (org_id, committee, created_at desc);

-- Notices from a committee to every member (for the Commission: timetable,
-- nominations, candidate list, results).
create table if not exists public.office_notices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  committee text not null,
  title text not null check (length(trim(title)) between 2 and 200),
  body text not null check (length(body) between 1 and 4000),
  by_key text not null,
  created_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  withdrawn_by text
);
create index if not exists office_notices_org
  on public.office_notices (org_id, created_at desc);

create table if not exists public.office_log (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.sync_orgs (id),
  committee text not null,
  at timestamptz not null default now(),
  by_key text,
  event text not null,
  detail text
);
create index if not exists office_log_committee
  on public.office_log (org_id, committee, id desc);

alter table public.office_tasks enable row level security;
alter table public.office_notes enable row level security;
alter table public.office_notices enable row level security;
alter table public.office_log enable row level security;
revoke all on public.office_tasks, public.office_notes, public.office_notices,
  public.office_log from public, anon, authenticated;

create or replace function public.office_log_locked()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'The office log cannot be changed.';
end;
$$;
create or replace trigger office_log_no_change
  before update on public.office_log
  for each row execute function public.office_log_locked();

-- The committees of an organisation (its own rows, else the defaults).
create or replace function public.office_defs(org uuid)
returns setof public.office_committees
language sql
stable
security definer
set search_path = ''
as $$
  select c.* from public.office_committees c
  where c.active
    and (c.org_id = org
         or (c.org_id is null and not exists (
               select 1 from public.office_committees o
               where o.org_id = org and o.key = c.key)))
  order by c.sort, c.name
$$;

-- Everyone in a committee: [{key, name, member_no, role, role_name, lead}].
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
      r.data ->> 'key', coalesce(r.data ->> 'name', r.data ->> 'key'),
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

-- The caller's seat in a committee, or null.
create or replace function public.office_seat(
  me jsonb, c public.office_committees
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select s from jsonb_array_elements(
    public.office_members((me ->> 'org')::uuid, c)) s
  where me ->> 'member' is not null and s ->> 'key' = me ->> 'member'
  limit 1
$$;

-- Who is calling, in which office. Only the office's own members get in,
-- and only signed in with their own member ID.
create or replace function public.office_who(token text, committee text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, null);
  c public.office_committees;
  seat jsonb;
begin
  if me ->> 'member' is null then
    raise exception 'Sign in with your own member ID to use the office.'
      using errcode = 'P0001';
  end if;
  select * into c from public.office_defs((me ->> 'org')::uuid) d
  where d.key = committee;
  if c.id is null then
    raise exception 'No such office.' using errcode = 'P0001';
  end if;
  seat := public.office_seat(me, c);
  if seat is null then
    raise exception 'Only members of the % can open this office.', c.name
      using errcode = 'P0001';
  end if;
  return me || jsonb_build_object(
    'committee', c.key, 'committee_name', c.name,
    'source', c.source, 'checklist', c.checklist,
    'role', seat ->> 'role', 'role_name', seat ->> 'role_name',
    'lead', (seat ->> 'lead')::boolean);
end;
$$;

create or replace function public.office_write_log(
  me jsonb, event text, detail text default null
) returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.office_log (org_id, committee, by_key, event, detail)
  values ((me ->> 'org')::uuid, me ->> 'committee', me ->> 'member', event,
    left(detail, 300))
$$;

create or replace function public.office_member_name(org uuid, mkey text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select r.data ->> 'full_name' from public.sync_records r
  where r.org_id = org and r.tbl = 'members' and r.key = mkey
$$;

-- The offices the caller sits in, with their open work.
create or replace function public.office_list(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, null);
  org uuid := (me ->> 'org')::uuid;
begin
  if me ->> 'member' is null then
    return '[]'::jsonb;
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'key', c.key, 'name', c.name, 'purpose', c.purpose,
      'role', s ->> 'role', 'role_name', s ->> 'role_name',
      'lead', (s ->> 'lead')::boolean,
      'open_tasks', (select count(*) from public.office_tasks t
                     where t.org_id = org and t.committee = c.key
                       and t.status = 'open' and t.deleted_at is null),
      'my_tasks', (select count(*) from public.office_tasks t
                   where t.org_id = org and t.committee = c.key
                     and t.status = 'open' and t.deleted_at is null
                     and t.assignee_key = me ->> 'member'))
      order by c.sort, c.name), '[]')
    from public.office_defs(org) c
    cross join lateral (select public.office_seat(me, c) as s) seat
    where s is not null);
end;
$$;

-- For the Commission: active members (the voter roll if voting opened now)
-- and how many of them can sign in, overall and by zone.
create or replace function public.office_voter_roll(org uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with m as (
    select r.key, exists (select 1 from public.member_accounts a
                          where a.org_id = org and a.member_key = r.key
                            and a.activated_at is not null) as ready
    from public.sync_records r
    where r.org_id = org and r.tbl = 'members'
      and r.data ->> 'deleted_at' is null and r.data ->> 'status' = 'active'
  ), z as (
    select coalesce(zn.data ->> 'name', 'No zone') as zone,
      min(coalesce((zn.data ->> 'code')::int, 999)) as code,
      count(distinct m.key) as active,
      count(distinct m.key) filter (where m.ready) as ready
    from m
    left join public.sync_records mz on mz.org_id = org
      and mz.tbl = 'member_zones' and mz.data ->> 'member_id' = m.key
      and mz.data ->> 'deleted_at' is null
    left join public.sync_records zn on zn.org_id = org and zn.tbl = 'zones'
      and zn.key = mz.data ->> 'zone_id'
    group by 1
  )
  select jsonb_build_object(
    'active', (select count(*) from m),
    'ready', (select count(*) from m where ready),
    'zones', (select coalesce(jsonb_agg(jsonb_build_object(
      'zone', zone, 'active', active, 'ready', ready)
      order by code, zone), '[]') from z))
$$;

-- Everything on the office's desk.
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
    'members', public.office_members(org, c),
    'tasks', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.id, 'title', t.title, 'details', t.details,
        'election_id', t.election_id, 'assignee', t.assignee_key,
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
  end if;
  return out;
end;
$$;

-- Add or change a task. Anyone in the office adds; the person who added
-- it, the person it is given to, or a lead changes it.
create or replace function public.office_task_save(
  token text, committee text, id uuid, title text, details text,
  assignee text, due_on date, election uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  org uuid := (me ->> 'org')::uuid;
  c public.office_committees;
  t public.office_tasks;
  tid uuid;
begin
  select * into c from public.office_defs(org) d where d.key = committee;
  if length(trim(coalesce(title, ''))) < 2 then
    raise exception 'Say what needs doing.' using errcode = 'P0001';
  end if;
  if nullif(assignee, '') is not null and not exists (
      select 1 from jsonb_array_elements(public.office_members(org, c)) s
      where s ->> 'key' = assignee) then
    raise exception 'Give the task to someone in the office.'
      using errcode = 'P0001';
  end if;
  if election is not null and not exists (
      select 1 from public.elections e where e.id = election and e.org_id = org) then
    raise exception 'No such election.' using errcode = 'P0001';
  end if;
  if office_task_save.id is null then
    insert into public.office_tasks (org_id, committee, election_id, title,
      details, assignee_key, due_on, created_by)
    values (org, c.key, election, trim(title), nullif(trim(details), ''),
      nullif(assignee, ''), due_on, me ->> 'member')
    returning public.office_tasks.id into tid;
    perform public.office_write_log(me, 'Added a task', trim(title));
  else
    select * into t from public.office_tasks x
    where x.id = office_task_save.id and x.org_id = org
      and x.committee = c.key and x.deleted_at is null;
    if t.id is null then
      raise exception 'No such task.' using errcode = 'P0001';
    end if;
    if not ((me ->> 'lead')::boolean or t.created_by = me ->> 'member'
            or t.assignee_key = me ->> 'member') then
      raise exception 'Only the person who added it, the person doing it or a lead can change this task.'
        using errcode = 'P0001';
    end if;
    update public.office_tasks x set
      title = trim(office_task_save.title),
      details = nullif(trim(office_task_save.details), ''),
      assignee_key = nullif(office_task_save.assignee, ''),
      due_on = office_task_save.due_on,
      election_id = office_task_save.election
    where x.id = t.id;
    tid := t.id;
    perform public.office_write_log(me, 'Changed a task', trim(title));
  end if;
  return jsonb_build_object('id', tid);
end;
$$;

-- Tick a task done (or open it again). Anyone in the office.
create or replace function public.office_task_done(
  token text, committee text, id uuid, done boolean
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  t public.office_tasks;
begin
  update public.office_tasks x set
    status = case when done then 'done' else 'open' end,
    done_by = case when done then me ->> 'member' end,
    done_at = case when done then now() end
  where x.id = office_task_done.id and x.org_id = (me ->> 'org')::uuid
    and x.committee = me ->> 'committee' and x.deleted_at is null
  returning * into t;
  if t.id is null then
    raise exception 'No such task.' using errcode = 'P0001';
  end if;
  perform public.office_write_log(me,
    case when done then 'Finished a task' else 'Reopened a task' end, t.title);
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.office_task_remove(
  token text, committee text, id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  t public.office_tasks;
begin
  select * into t from public.office_tasks x
  where x.id = office_task_remove.id and x.org_id = (me ->> 'org')::uuid
    and x.committee = me ->> 'committee' and x.deleted_at is null;
  if t.id is null then
    raise exception 'No such task.' using errcode = 'P0001';
  end if;
  if not ((me ->> 'lead')::boolean or t.created_by = me ->> 'member') then
    raise exception 'Only the person who added it or a lead can remove this task.'
      using errcode = 'P0001';
  end if;
  update public.office_tasks x set deleted_at = now() where x.id = t.id;
  perform public.office_write_log(me, 'Removed a task', t.title);
  return jsonb_build_object('ok', true);
end;
$$;

-- Leads: add the committee's standard steps to an election, once.
create or replace function public.office_add_checklist(
  token text, committee text, election uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  org uuid := (me ->> 'org')::uuid;
  e public.elections;
  step text;
  n int := 0;
begin
  if not (me ->> 'lead')::boolean then
    raise exception 'Only the Chairperson or Secretary can do this.'
      using errcode = 'P0001';
  end if;
  select * into e from public.elections x
  where x.id = election and x.org_id = org;
  if e.id is null then
    raise exception 'No such election.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.office_tasks t
             where t.election_id = e.id and t.committee = me ->> 'committee'
               and t.deleted_at is null) then
    raise exception 'This election already has its steps.'
      using errcode = 'P0001';
  end if;
  for step in select jsonb_array_elements_text(me -> 'checklist') loop
    n := n + 1;
    insert into public.office_tasks (org_id, committee, election_id, title,
      sort, created_by)
    values (org, me ->> 'committee', e.id, step, n, me ->> 'member');
  end loop;
  perform public.office_write_log(me, 'Added the election steps', e.title);
  return jsonb_build_object('added', n);
end;
$$;

-- Meeting minutes, decisions and notes. Anyone in the office writes; the
-- writer or a lead changes or removes.
create or replace function public.office_note_save(
  token text, committee text, id uuid, kind text, title text, body text,
  met_on date
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  org uuid := (me ->> 'org')::uuid;
  n public.office_notes;
  nid uuid;
  label text := case kind when 'meeting' then 'meeting minutes'
                          when 'decision' then 'a decision' else 'a note' end;
begin
  if kind not in ('meeting', 'decision', 'note') then
    raise exception 'Choose minutes, decision or note.' using errcode = 'P0001';
  end if;
  if length(trim(coalesce(title, ''))) < 2
     or length(trim(coalesce(body, ''))) = 0 then
    raise exception 'Give it a title and write something.'
      using errcode = 'P0001';
  end if;
  if office_note_save.id is null then
    insert into public.office_notes (org_id, committee, kind, title, body,
      met_on, by_key)
    values (org, me ->> 'committee', kind, trim(title), trim(body), met_on,
      me ->> 'member')
    returning public.office_notes.id into nid;
    perform public.office_write_log(me, 'Wrote ' || label, trim(title));
  else
    select * into n from public.office_notes x
    where x.id = office_note_save.id and x.org_id = org
      and x.committee = me ->> 'committee' and x.deleted_at is null;
    if n.id is null then
      raise exception 'No such entry.' using errcode = 'P0001';
    end if;
    if not ((me ->> 'lead')::boolean or n.by_key = me ->> 'member') then
      raise exception 'Only the writer or a lead can change this.'
        using errcode = 'P0001';
    end if;
    update public.office_notes x set
      kind = office_note_save.kind, title = trim(office_note_save.title),
      body = trim(office_note_save.body), met_on = office_note_save.met_on,
      updated_at = now()
    where x.id = n.id;
    nid := n.id;
    perform public.office_write_log(me, 'Changed ' || label, trim(title));
  end if;
  return jsonb_build_object('id', nid);
end;
$$;

create or replace function public.office_note_remove(
  token text, committee text, id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  n public.office_notes;
begin
  select * into n from public.office_notes x
  where x.id = office_note_remove.id and x.org_id = (me ->> 'org')::uuid
    and x.committee = me ->> 'committee' and x.deleted_at is null;
  if n.id is null then
    raise exception 'No such entry.' using errcode = 'P0001';
  end if;
  if not ((me ->> 'lead')::boolean or n.by_key = me ->> 'member') then
    raise exception 'Only the writer or a lead can remove this.'
      using errcode = 'P0001';
  end if;
  update public.office_notes x set deleted_at = now() where x.id = n.id;
  perform public.office_write_log(me, 'Removed an entry', n.title);
  return jsonb_build_object('ok', true);
end;
$$;

-- Leads: a notice every member sees.
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
  if not (me ->> 'lead')::boolean then
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

create or replace function public.office_notice_withdraw(
  token text, committee text, id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.office_who(token, committee);
  n public.office_notices;
begin
  if not (me ->> 'lead')::boolean then
    raise exception 'Only the Chairperson or Secretary can withdraw notices.'
      using errcode = 'P0001';
  end if;
  update public.office_notices x
  set withdrawn_at = now(), withdrawn_by = me ->> 'member'
  where x.id = office_notice_withdraw.id and x.org_id = (me ->> 'org')::uuid
    and x.committee = me ->> 'committee' and x.withdrawn_at is null
  returning * into n;
  if n.id is null then
    raise exception 'No such notice.' using errcode = 'P0001';
  end if;
  perform public.office_write_log(me, 'Withdrew a notice', n.title);
  return jsonb_build_object('ok', true);
end;
$$;

-- What every member sees: the latest notices from all committees.
create or replace function public.office_notices(
  token text, committee text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, null);
  org uuid := (me ->> 'org')::uuid;
begin
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', n.id, 'committee', n.committee, 'from', c.name,
      'title', n.title, 'body', n.body, 'at', n.created_at)
      order by n.created_at desc), '[]')
    from (select * from public.office_notices x
          where x.org_id = org and x.withdrawn_at is null
            and (office_notices.committee is null
                 or x.committee = office_notices.committee)
          order by x.created_at desc limit 20) n
    left join public.office_defs(org) c on c.key = n.committee);
end;
$$;

-- Each office gets its own private chat, next to the role chats.
do $$
begin
  if not exists (select 1 from pg_proc p
                 join pg_namespace s on s.oid = p.pronamespace
                 where s.nspname = 'public'
                   and p.proname = 'chat_channels_base') then
    alter function public.chat_channels_for(jsonb) rename to chat_channels_base;
  end if;
end;
$$;
revoke all on function public.chat_channels_base(jsonb)
  from public, anon, authenticated;

create or replace function public.chat_channels_for(me jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select public.chat_channels_base(me) || coalesce((
    select jsonb_agg(jsonb_build_object('id', 'office:' || c.key,
      'name', c.name, 'post', true) order by c.sort, c.name)
    from public.office_defs((me ->> 'org')::uuid) c
    where me ->> 'member' is not null
      and public.office_seat(me, c) is not null), '[]'::jsonb)
$$;
revoke all on function public.chat_channels_for(jsonb)
  from public, anon, authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'office_defs(uuid)',
    'office_members(uuid, public.office_committees)',
    'office_seat(jsonb, public.office_committees)',
    'office_who(text, text)', 'office_write_log(jsonb, text, text)',
    'office_member_name(uuid, text)', 'office_voter_roll(uuid)']
  loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array[
    'office_list(text)', 'office_home(text, text)',
    'office_task_save(text, text, uuid, text, text, text, date, uuid)',
    'office_task_done(text, text, uuid, boolean)',
    'office_task_remove(text, text, uuid)',
    'office_add_checklist(text, text, uuid)',
    'office_note_save(text, text, uuid, text, text, text, date)',
    'office_note_remove(text, text, uuid)',
    'office_notice_post(text, text, text, text)',
    'office_notice_withdraw(text, text, uuid)',
    'office_notices(text, text)']
  loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end;
$$;
