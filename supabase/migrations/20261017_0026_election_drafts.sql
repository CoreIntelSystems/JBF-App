-- While an election is still a draft, the Electoral Commission can change
-- it: the name, notes and closing time, the posts and their seats, and the
-- candidates (change their picture or message, swap them, or take them off).
-- Nothing here touches an election once voting has opened. Cancelled drafts
-- no longer show in the list of elections.

-- Nothing is erased: removed posts and candidates move to one cancelled
-- "Removed from drafts" election per organisation, which no list shows, so
-- what was there stays on record.
create or replace function public.election_bin(org uuid, by_key text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  bin uuid;
begin
  select e.id into bin from public.elections e
  where e.org_id = org and e.status = 'cancelled'
    and e.notes = 'election-bin' limit 1;
  if bin is null then
    insert into public.elections (org_id, title, notes, status, closes_at,
      created_by)
    values (org, 'Removed from draft elections', 'election-bin', 'cancelled',
      now(), coalesce(by_key, 'system'))
    returning id into bin;
  end if;
  return bin;
end;
$$;
revoke all on function public.election_bin(uuid, text)
  from public, anon, authenticated;

-- Commission only, draft only. [posts] is [{id?, title, seats}]: a post with
-- an id is updated, one without is added, and posts left out are removed
-- together with their candidates.
create or replace function public.election_update(
  token text, eid uuid, title text, notes text, closes_at timestamptz,
  posts jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  e public.elections;
  p jsonb;
  keep uuid[] := '{}';
  pid uuid;
  n int := 0;
  changes text[] := '{}';
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can do this.'
      using errcode = 'P0001';
  end if;
  select * into e from public.elections
  where id = eid and org_id = (me ->> 'org')::uuid for update;
  if e.id is null or e.status <> 'draft' then
    raise exception 'An election can only be changed before voting opens.'
      using errcode = 'P0001';
  end if;
  if length(trim(coalesce(title, ''))) < 3 then
    raise exception 'Give the election a name.' using errcode = 'P0001';
  end if;
  if closes_at <= now() then
    raise exception 'Choose a closing time in the future.'
      using errcode = 'P0001';
  end if;
  if jsonb_typeof(posts) <> 'array' or jsonb_array_length(posts) = 0 then
    raise exception 'Add at least one post.' using errcode = 'P0001';
  end if;
  for p in select * from jsonb_array_elements(posts) loop
    if length(trim(coalesce(p ->> 'title', ''))) < 2 then
      raise exception 'Give every post a name.' using errcode = 'P0001';
    end if;
    if coalesce((p ->> 'seats')::int, 1) not between 1 and 10 then
      raise exception 'A post has 1 to 10 seats.' using errcode = 'P0001';
    end if;
    if p ->> 'id' is not null then
      if not exists (select 1 from public.election_posts x
                     where x.id = (p ->> 'id')::uuid
                       and x.election_id = e.id) then
        raise exception 'That post is not in this election.'
          using errcode = 'P0001';
      end if;
      keep := keep || (p ->> 'id')::uuid;
    end if;
  end loop;

  if trim(title) <> e.title then
    changes := changes || ('name: ' || trim(title));
  end if;
  if closes_at <> e.closes_at then
    changes := changes || ('closes: ' || to_char(closes_at at time zone 'utc',
      'YYYY-MM-DD HH24:MI') || ' UTC');
  end if;
  update public.elections x
  set title = trim(election_update.title),
      notes = nullif(trim(election_update.notes), ''),
      closes_at = election_update.closes_at
  where x.id = e.id;

  -- Posts taken out go, with their candidates, to the removed list.
  for pid in select x.id from public.election_posts x
             where x.election_id = e.id and not (x.id = any (keep)) loop
    changes := changes || ('removed post: ' ||
      (select x.title from public.election_posts x where x.id = pid));
    update public.election_posts x
    set election_id = public.election_bin(e.org_id, me ->> 'member')
    where x.id = pid;
  end loop;

  for p in select * from jsonb_array_elements(posts) loop
    n := n + 1;
    if p ->> 'id' is null then
      insert into public.election_posts (election_id, title, seats, sort)
      values (e.id, trim(p ->> 'title'), coalesce((p ->> 'seats')::int, 1), n);
      changes := changes || ('added post: ' || trim(p ->> 'title'));
    else
      update public.election_posts x
      set title = trim(p ->> 'title'),
          seats = coalesce((p ->> 'seats')::int, 1), sort = n
      where x.id = (p ->> 'id')::uuid;
    end if;
  end loop;

  perform public.election_write_log(e.id, me ->> 'member', 'edited',
    nullif(array_to_string(changes, '; '), ''));
  return jsonb_build_object('ok', true);
end;
$$;

-- Commission only, draft only: take a candidate off a post.
create or replace function public.election_remove_candidate(
  token text, cid uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.election_who(token);
  e public.elections;
  c public.election_candidates;
  post_title text;
  bin_post uuid;
begin
  if not (me ->> 'is_ec')::boolean then
    raise exception 'Only the Electoral Commission can do this.'
      using errcode = 'P0001';
  end if;
  select c2.* into c from public.election_candidates c2 where c2.id = cid;
  select e2.* into e from public.elections e2
  join public.election_posts p on p.election_id = e2.id
  where p.id = c.post_id and e2.org_id = (me ->> 'org')::uuid;
  if c.id is null or e.id is null or e.status <> 'draft' then
    raise exception 'Candidates can only change before the election opens.'
      using errcode = 'P0001';
  end if;
  select p.title into post_title from public.election_posts p
  where p.id = c.post_id;
  -- Moved to a post of its own in the removed list (see election_bin).
  insert into public.election_posts (election_id, title, seats, sort)
  values (public.election_bin(e.org_id, me ->> 'member'),
    left(post_title || ' (removed)', 120), 1, 0)
  returning id into bin_post;
  update public.election_candidates c2 set post_id = bin_post
  where c2.id = c.id;
  perform public.election_write_log(e.id, me ->> 'member', 'candidate removed',
    coalesce(c.member_no, c.name) || ' from ' || post_title);
  return jsonb_build_object('ok', true);
end;
$$;

-- The same as before, plus each candidate's member for the Commission, so a
-- draft candidate can be edited.
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
  ec boolean := (me ->> 'is_ec')::boolean;
begin
  select * into e from public.elections
  where id = eid and org_id = (me ->> 'org')::uuid;
  if e.id is null then
    raise exception 'No such election.' using errcode = 'P0001';
  end if;
  st := public.election_state(e);
  if st in ('draft', 'cancelled') and not ec then
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
            'manifesto', c.manifesto, 'photo', c.photo,
            'member_key', case when ec then c.member_key end)
            order by c.name), '[]')
          from public.election_candidates c where c.post_id = p.id))
        order by p.sort, p.title), '[]')
      from public.election_posts p where p.election_id = e.id));
end;
$$;

-- Cancelled elections leave the list. They stay in the record (and their
-- log), but nobody needs to see them among the elections.
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
        and (e.status in ('open', 'closed')
             or ((me ->> 'is_ec')::boolean and e.status = 'draft'))));
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'election_update(text, uuid, text, text, timestamptz, jsonb)',
    'election_remove_candidate(text, uuid)']
  loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end;
$$;
