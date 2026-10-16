-- Elections with a secret ballot.
--
-- Rules the database itself enforces (an app bug or a curious officer cannot
-- get round them):
--   * Only the Electoral Commission (Chairperson, Secretary) runs elections,
--     and a different EC officer must open it than the one who prepared it.
--   * The voters are frozen when the election opens (active members only).
--   * Candidates, posts and rules cannot change once it is open.
--   * One vote per member per post: a unique "voted" list, written in the
--     same transaction as the ballot.
--   * The ballot box holds no member, no time and no sequence number, only a
--     random id, so a ballot cannot be traced back to who cast it.
--   * Nobody, the Commission included, can see any count until the vote is
--     closed. While open only the turnout is visible.
--   * Every step is written to a chained log; changing an old entry breaks
--     every entry after it.
--   * No table is reachable from the app; everything goes through the
--     functions below.

create table if not exists public.elections (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  title text not null check (length(trim(title)) between 3 and 200),
  notes text,
  status text not null default 'draft'
    check (status in ('draft', 'open', 'closed', 'cancelled')),
  closes_at timestamptz not null,
  created_by text not null,
  opened_by text,
  opened_at timestamptz,
  closed_by text,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists elections_org_idx on public.elections (org_id);

create table if not exists public.election_posts (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.elections (id),
  title text not null check (length(trim(title)) between 2 and 120),
  seats int not null default 1 check (seats between 1 and 10),
  sort int not null default 0
);
create index if not exists election_posts_election_idx
  on public.election_posts (election_id);

create table if not exists public.election_candidates (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.election_posts (id),
  member_key text not null,
  name text not null,
  member_no text,
  manifesto text check (manifesto is null or length(manifesto) <= 1500),
  photo text check (photo is null or length(photo) <= 300000),
  unique (post_id, member_key)
);
create index if not exists election_candidates_post_idx
  on public.election_candidates (post_id);

-- Who may vote, frozen when the election opens.
create table if not exists public.election_voters (
  election_id uuid not null references public.elections (id),
  member_key text not null,
  primary key (election_id, member_key)
);

-- Who has voted on which post (no choice recorded here).
create table if not exists public.election_voted (
  post_id uuid not null references public.election_posts (id),
  member_key text not null,
  primary key (post_id, member_key)
);

-- The ballot box: a random id and the choice, nothing else.
create table if not exists public.election_ballots (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.election_posts (id),
  candidate_id uuid references public.election_candidates (id)
);
create index if not exists election_ballots_post_idx
  on public.election_ballots (post_id);
create index if not exists election_ballots_candidate_idx
  on public.election_ballots (candidate_id);

-- Chained log of what happened.
create table if not exists public.election_log (
  id bigint generated always as identity primary key,
  election_id uuid not null references public.elections (id),
  at timestamptz not null default now(),
  by_key text,
  event text not null,
  detail text,
  prev_hash text,
  hash text not null
);
create index if not exists election_log_election_idx
  on public.election_log (election_id, id);

alter table public.elections enable row level security;
alter table public.election_posts enable row level security;
alter table public.election_candidates enable row level security;
alter table public.election_voters enable row level security;
alter table public.election_voted enable row level security;
alter table public.election_ballots enable row level security;
alter table public.election_log enable row level security;
revoke all on public.elections, public.election_posts,
  public.election_candidates, public.election_voters, public.election_voted,
  public.election_ballots, public.election_log from public, anon, authenticated;

-- Written once, never changed.
create or replace function public.election_log_locked()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'The election log cannot be changed.';
end;
$$;
create or replace trigger election_log_no_change
  before update on public.election_log
  for each row execute function public.election_log_locked();

-- Ballots and the voted list cannot be edited either; the app roles have no access to remove them.
create or replace trigger election_ballots_no_change
  before update on public.election_ballots
  for each row execute function public.election_log_locked();
create or replace trigger election_voted_no_change
  before update on public.election_voted
  for each row execute function public.election_log_locked();

create or replace function public.election_write_log(
  eid uuid, by_key text, event text, detail text default null
) returns void
language plpgsql
set search_path = ''
as $$
declare
  prev text;
  stamp timestamptz := clock_timestamp();
begin
  select l.hash into prev from public.election_log l
  where l.election_id = eid order by l.id desc limit 1;
  insert into public.election_log (election_id, at, by_key, event, detail,
    prev_hash, hash)
  values (eid, stamp, by_key, event, detail, prev,
    encode(sha256(convert_to(
      coalesce(prev, '') || '|' || eid::text || '|' || stamp::text || '|' ||
      coalesce(by_key, '') || '|' || event || '|' || coalesce(detail, ''),
      'UTF8')), 'hex'));
end;
$$;
revoke all on function public.election_write_log(uuid, text, text, text)
  from public, anon, authenticated;

-- Who is calling: a member signed in with their own member ID, on a member
-- session or on a phone enrolled by member sign-in. Never a shared or
-- legacy login, because a vote must belong to one person.
create or replace function public.election_who(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, null);
  m jsonb;
begin
  if me ->> 'member' is null then
    raise exception 'Sign in with your own member ID to use elections.'
      using errcode = 'P0001';
  end if;
  select r.data into m from public.sync_records r
  where r.org_id = (me ->> 'org')::uuid and r.tbl = 'members'
    and r.key = me ->> 'member';
  return me || jsonb_build_object(
    'status', m ->> 'status',
    'member_no', m ->> 'member_no',
    'deleted', m ->> 'deleted_at' is not null,
    'is_ec', (me -> 'roles') ?| array['electoral_commission', 'ec_secretary']
      and coalesce((me -> 'permissions') ? 'elections.manage', false));
end;
$$;
revoke all on function public.election_who(text) from public, anon, authenticated;

-- Closed once the time is up, even if nobody pressed the button.
create or replace function public.election_state(e public.elections)
returns text
language sql
stable
set search_path = ''
as $$
  select case when e.status = 'open' and now() >= e.closes_at then 'closed'
              else e.status end;
$$;

-- Elections the caller can see: the Commission sees all, members see those
-- open or closed (not drafts), and whether the caller is on the Commission.
create or replace function public.election_list(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  org uuid := (me ->> 'org')::uuid;
begin
  return jsonb_build_object(
    'is_ec', (me ->> 'is_ec')::boolean,
    'elections', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', e.id, 'title', e.title, 'status', public.election_state(e),
        'closes_at', e.closes_at, 'opened_at', e.opened_at,
        'closed_at', e.closed_at,
        'can_vote', public.election_state(e) = 'open'
          and exists (select 1 from public.election_voters v
                      where v.election_id = e.id
                        and v.member_key = me ->> 'member'),
        'voted_all', exists (select 1 from public.election_posts p
                             where p.election_id = e.id)
          and not exists (
            select 1 from public.election_posts p
            where p.election_id = e.id and not exists (
              select 1 from public.election_voted d
              where d.post_id = p.id and d.member_key = me ->> 'member')))
        order by e.created_at desc), '[]')
      from public.elections e
      where e.org_id = org
        and ((me ->> 'is_ec')::boolean or e.status in ('open', 'closed'))));
end;
$$;

-- One election with its posts and candidates. Never any counts.
create or replace function public.election_get(token text, eid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  e public.elections;
  st text;
begin
  select * into e from public.elections
  where id = eid and org_id = (me ->> 'org')::uuid;
  if e.id is null then
    raise exception 'No such election.' using errcode = 'P0001';
  end if;
  st := public.election_state(e);
  if st in ('draft', 'cancelled') and not (me ->> 'is_ec')::boolean then
    raise exception 'No such election.' using errcode = 'P0001';
  end if;
  return jsonb_build_object(
    'id', e.id, 'title', e.title, 'notes', e.notes, 'status', st,
    'closes_at', e.closes_at, 'opened_at', e.opened_at,
    'closed_at', e.closed_at,
    'created_by_me', e.created_by = me ->> 'member',
    'opened_by_me', e.opened_by = me ->> 'member',
    'can_vote', st = 'open' and exists (
      select 1 from public.election_voters v
      where v.election_id = e.id and v.member_key = me ->> 'member'),
    'voters', (select count(*) from public.election_voters v
               where v.election_id = e.id),
    'posts', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'title', p.title, 'seats', p.seats,
        'voted', exists (select 1 from public.election_voted d
                         where d.post_id = p.id
                           and d.member_key = me ->> 'member'),
        'turnout', case when st = 'draft' then null else
          (select count(*) from public.election_voted d
           where d.post_id = p.id) end,
        'candidates', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', c.id, 'name', c.name, 'member_no', c.member_no,
            'manifesto', c.manifesto, 'photo', c.photo)
            order by c.name), '[]')
          from public.election_candidates c where c.post_id = p.id))
        order by p.sort, p.title), '[]')
      from public.election_posts p where p.election_id = e.id));
end;
$$;

-- Commission only: create an election with its posts. [posts] is
-- [{title, seats}].
create or replace function public.election_create(
  token text, title text, notes text, closes_at timestamptz, posts jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  eid uuid;
  p jsonb;
  n int := 0;
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can create elections.'
      using errcode = 'P0001';
  end if;
  if closes_at <= now() then
    raise exception 'Choose a closing time in the future.'
      using errcode = 'P0001';
  end if;
  if jsonb_typeof(posts) <> 'array' or jsonb_array_length(posts) = 0 then
    raise exception 'Add at least one post.' using errcode = 'P0001';
  end if;
  insert into public.elections (org_id, title, notes, closes_at, created_by)
  values ((me ->> 'org')::uuid, trim(title), nullif(trim(notes), ''),
    closes_at, me ->> 'member')
  returning id into eid;
  for p in select * from jsonb_array_elements(posts) loop
    n := n + 1;
    insert into public.election_posts (election_id, title, seats, sort)
    values (eid, trim(p ->> 'title'), coalesce((p ->> 'seats')::int, 1), n);
  end loop;
  perform public.election_write_log(eid, me ->> 'member', 'created', trim(title));
  return jsonb_build_object('id', eid);
end;
$$;

-- Commission only, while still a draft: find members to stand.
create or replace function public.election_find_member(token text, q text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can do this.'
      using errcode = 'P0001';
  end if;
  if length(trim(coalesce(q, ''))) < 2 then
    return '[]'::jsonb;
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'key', r.key, 'name', r.data ->> 'full_name',
      'member_no', r.data ->> 'member_no') order by r.data ->> 'full_name'),
      '[]')
    from (
      select * from public.sync_records r
      where r.org_id = (me ->> 'org')::uuid and r.tbl = 'members'
        and r.data ->> 'deleted_at' is null and r.data ->> 'status' = 'active'
        and ((r.data ->> 'full_name') ilike '%' || trim(q) || '%'
             or (r.data ->> 'member_no') ilike '%' || trim(q) || '%')
      order by r.data ->> 'full_name' limit 20) r);
end;
$$;

-- Commission only, draft only: add or replace a candidate.
create or replace function public.election_set_candidate(
  token text, post uuid, member text, manifesto text, photo text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  e public.elections;
  m public.sync_records;
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can do this.'
      using errcode = 'P0001';
  end if;
  select e2.* into e from public.elections e2
  join public.election_posts p on p.election_id = e2.id
  where p.id = post and e2.org_id = (me ->> 'org')::uuid;
  if e.id is null or e.status <> 'draft' then
    raise exception 'Candidates can only change before the election opens.'
      using errcode = 'P0001';
  end if;
  select * into m from public.sync_records r
  where r.org_id = e.org_id and r.tbl = 'members' and r.key = member
    and r.data ->> 'deleted_at' is null and r.data ->> 'status' = 'active';
  if m.key is null then
    raise exception 'Only active members can stand.' using errcode = 'P0001';
  end if;
  -- The Commission runs the election, so its officers cannot stand.
  if exists (select 1 from jsonb_array_elements(
               public.member_access(e.org_id, member) -> 'roles') x
             where x ->> 'key' in ('electoral_commission', 'ec_secretary')) then
    raise exception 'Electoral Commission officers cannot stand.'
      using errcode = 'P0001';
  end if;
  if photo is not null and photo not like 'data:image/%' then
    raise exception 'The picture must be an image.' using errcode = 'P0001';
  end if;
  insert into public.election_candidates (post_id, member_key, name, member_no,
    manifesto, photo)
  values (post, member, m.data ->> 'full_name', m.data ->> 'member_no',
    nullif(trim(manifesto), ''), photo)
  on conflict (post_id, member_key) do update
    set manifesto = excluded.manifesto,
        photo = coalesce(excluded.photo, public.election_candidates.photo);
  perform public.election_write_log(e.id, me ->> 'member', 'candidate',
    (m.data ->> 'member_no') || ' for ' ||
    (select title from public.election_posts where id = post));
  return jsonb_build_object('ok', true);
end;
$$;

-- Opening needs a different Commission officer from the one who prepared
-- the election, and every post needs at least one candidate. The voter list
-- is frozen here.
create or replace function public.election_open(token text, eid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  e public.elections;
  n int;
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can open elections.'
      using errcode = 'P0001';
  end if;
  select * into e from public.elections
  where id = eid and org_id = (me ->> 'org')::uuid for update;
  if e.id is null or e.status <> 'draft' then
    raise exception 'This election cannot be opened.' using errcode = 'P0001';
  end if;
  if e.created_by = me ->> 'member' then
    raise exception 'A different Commission officer must open it.'
      using errcode = 'P0001';
  end if;
  if e.closes_at <= now() + interval '10 minutes' then
    raise exception 'The closing time is too soon.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.election_posts p
             where p.election_id = e.id and
               (select count(*) from public.election_candidates c
                where c.post_id = p.id) < 1) then
    raise exception 'Every post needs a candidate.' using errcode = 'P0001';
  end if;
  insert into public.election_voters (election_id, member_key)
  select e.id, r.key from public.sync_records r
  where r.org_id = e.org_id and r.tbl = 'members'
    and r.data ->> 'deleted_at' is null and r.data ->> 'status' = 'active';
  get diagnostics n = row_count;
  update public.elections
  set status = 'open', opened_by = me ->> 'member', opened_at = now()
  where id = e.id;
  perform public.election_write_log(e.id, me ->> 'member', 'opened',
    n || ' voters');
  return jsonb_build_object('voters', n);
end;
$$;

-- Casting the vote. [choices] is {post_id: candidate_id}, or the word
-- "abstain". All posts are voted in one go; a post already voted on is
-- refused, so a repeat or a replay does nothing.
create or replace function public.election_vote(
  token text, eid uuid, choices jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  e public.elections;
  p record;
  pick text;
  cand uuid;
begin
  select * into e from public.elections
  where id = eid and org_id = (me ->> 'org')::uuid for share;
  if e.id is null or public.election_state(e) <> 'open' then
    raise exception 'Voting is not open.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.election_voters v
                 where v.election_id = e.id
                   and v.member_key = me ->> 'member') then
    raise exception 'You are not on the voters list.' using errcode = 'P0001';
  end if;
  -- Still an active member today.
  if (me ->> 'status') is distinct from 'active' or (me ->> 'deleted')::boolean then
    raise exception 'Only active members can vote.' using errcode = 'P0001';
  end if;
  if jsonb_typeof(choices) <> 'object' then
    raise exception 'Make your choices first.' using errcode = 'P0001';
  end if;
  for p in select * from public.election_posts where election_id = e.id
           order by sort loop
    pick := choices ->> p.id::text;
    if pick is null then
      raise exception 'Choose for every post, or abstain.'
        using errcode = 'P0001';
    end if;
    if pick = 'abstain' then
      cand := null;
    else
      select c.id into cand from public.election_candidates c
      where c.post_id = p.id and c.id::text = pick;
      if cand is null then
        raise exception 'That candidate is not standing for this post.'
          using errcode = 'P0001';
      end if;
    end if;
    begin
      insert into public.election_voted (post_id, member_key)
      values (p.id, me ->> 'member');
    exception when unique_violation then
      raise exception 'You have already voted.' using errcode = 'P0001';
    end;
    insert into public.election_ballots (post_id, candidate_id)
    values (p.id, cand);
  end loop;
  return jsonb_build_object('ok', true);
end;
$$;

-- Closing early needs a Commission officer other than the one who opened it.
create or replace function public.election_close(token text, eid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  e public.elections;
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can close elections.'
      using errcode = 'P0001';
  end if;
  select * into e from public.elections
  where id = eid and org_id = (me ->> 'org')::uuid for update;
  if e.id is null or e.status <> 'open' then
    raise exception 'This election is not open.' using errcode = 'P0001';
  end if;
  if now() < e.closes_at and e.opened_by = me ->> 'member' then
    raise exception 'A different Commission officer must close it early.'
      using errcode = 'P0001';
  end if;
  update public.elections
  set status = 'closed', closed_by = me ->> 'member', closed_at = now()
  where id = e.id;
  perform public.election_write_log(e.id, me ->> 'member', 'closed', null);
  return jsonb_build_object('ok', true);
end;
$$;

-- A draft can be called off by the Commission; an open one cannot.
create or replace function public.election_cancel(token text, eid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can do this.'
      using errcode = 'P0001';
  end if;
  update public.elections set status = 'cancelled'
  where id = eid and org_id = (me ->> 'org')::uuid and status = 'draft';
  if not found then
    raise exception 'Only a draft can be cancelled.' using errcode = 'P0001';
  end if;
  perform public.election_write_log(eid, me ->> 'member', 'cancelled', null);
  return jsonb_build_object('ok', true);
end;
$$;

-- Results, only once closed, to every member. Counts per candidate, turnout,
-- and a check that ballots match the voted list.
create or replace function public.election_results(token text, eid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  e public.elections;
begin
  select * into e from public.elections
  where id = eid and org_id = (me ->> 'org')::uuid;
  if e.id is null or public.election_state(e) <> 'closed' then
    raise exception 'Results appear when voting has closed.'
      using errcode = 'P0001';
  end if;
  return jsonb_build_object(
    'title', e.title, 'closed_at', coalesce(e.closed_at, e.closes_at),
    'voters', (select count(*) from public.election_voters v
               where v.election_id = e.id),
    'log_ok', not exists (
      select 1 from public.election_log l
      where l.election_id = e.id and l.prev_hash is distinct from (
        select l2.hash from public.election_log l2
        where l2.election_id = e.id and l2.id < l.id
        order by l2.id desc limit 1)),
    'posts', (
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'title', p.title, 'seats', p.seats,
        'ballots', (select count(*) from public.election_ballots b
                    where b.post_id = p.id),
        'voted', (select count(*) from public.election_voted d
                  where d.post_id = p.id),
        'abstained', (select count(*) from public.election_ballots b
                      where b.post_id = p.id and b.candidate_id is null),
        'candidates', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', c.id, 'name', c.name, 'member_no', c.member_no,
            'photo', c.photo,
            'votes', (select count(*) from public.election_ballots b
                      where b.candidate_id = c.id))
            order by (select count(*) from public.election_ballots b
                      where b.candidate_id = c.id) desc, c.name), '[]')
          from public.election_candidates c where c.post_id = p.id))
        order by p.sort)
      from public.election_posts p where p.election_id = e.id));
end;
$$;

-- The Commission can read the log of an election.
create or replace function public.election_history(token text, eid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can do this.'
      using errcode = 'P0001';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'at', l.at, 'event', l.event, 'detail', l.detail,
      'by', (select r.data ->> 'full_name' from public.sync_records r
             where r.org_id = (me ->> 'org')::uuid and r.tbl = 'members'
               and r.key = l.by_key)) order by l.id), '[]')
    from public.election_log l
    join public.elections e on e.id = l.election_id
    where l.election_id = eid and e.org_id = (me ->> 'org')::uuid);
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'election_list(text)', 'election_get(text, uuid)',
    'election_create(text, text, text, timestamptz, jsonb)',
    'election_find_member(text, text)',
    'election_set_candidate(text, uuid, text, text, text)',
    'election_open(text, uuid)', 'election_vote(text, uuid, jsonb)',
    'election_close(text, uuid)', 'election_cancel(text, uuid)',
    'election_results(text, uuid)', 'election_history(text, uuid)']
  loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end;
$$;
