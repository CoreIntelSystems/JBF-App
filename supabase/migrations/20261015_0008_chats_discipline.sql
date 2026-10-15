-- Group chats, announcements and discipline. These live only in the cloud
-- (phones read them online): who may read and post is worked out here from
-- each person's roles, so a chat never reaches a phone it should not.

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  channel text not null,
  author_key text,
  author_name text not null,
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists chat_messages_channel
  on public.chat_messages (org_id, channel, created_at desc);
alter table public.chat_messages enable row level security;
revoke all on public.chat_messages from anon, authenticated;

create table if not exists public.discipline_cases (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  member_key text not null,
  kind text not null check (kind in ('complaint', 'warning')),
  details text not null check (length(details) between 1 and 4000),
  by_key text,
  by_name text not null,
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now()
);
create index if not exists discipline_cases_member
  on public.discipline_cases (org_id, member_key);
alter table public.discipline_cases enable row level security;
revoke all on public.discipline_cases from anon, authenticated;

-- Who is calling: a member session or a synced phone. Old phones joined
-- with a code or username have no member; their main phone (admin) counts
-- as the Founder, others as an ordinary officer, named by [as_name].
create or replace function public.chat_identity(token text, as_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.member_sessions;
  d public.sync_devices;
  org uuid;
  mkey text;
  acc jsonb;
  name text;
begin
  select * into s from public.member_sessions
  where token_hash = public.sync_hash(token) and revoked_at is null;
  if s.id is not null then
    org := s.org_id;
    mkey := s.member_key;
  else
    d := public.sync_device_for(token);
    org := d.org_id;
    mkey := d.member_key;
    if mkey is null then
      return jsonb_build_object(
        'org', org, 'member', null,
        'name', coalesce(nullif(trim(as_name), ''), d.name),
        'roles', case when d.is_admin then '["founder"]'::jsonb
                      else '[]'::jsonb end,
        'permissions', case when d.is_admin
          then '["discipline.file", "discipline.handle", "announce.post"]'::jsonb
          else '[]'::jsonb end,
        'zones', null, 'all', d.is_admin);
    end if;
  end if;
  acc := public.member_access(org, mkey);
  select r.data ->> 'full_name' into name from public.sync_records r
  where r.org_id = org and r.tbl = 'members' and r.key = mkey;
  return jsonb_build_object(
    'org', org, 'member', mkey, 'name', coalesce(name, 'Member'),
    'roles', coalesce((select jsonb_agg(x ->> 'key')
                       from jsonb_array_elements(acc -> 'roles') x), '[]'),
    'role_zones', acc -> 'roles',
    'permissions', acc -> 'permissions',
    'zones', acc -> 'zones',
    'all', exists (select 1 from jsonb_array_elements(acc -> 'roles') x
                   where x ->> 'key' in ('super_admin', 'founder')));
end;
$$;

-- The chats a person is in: [{id, name, post}].
create or replace function public.chat_channels_for(me jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  roles jsonb := me -> 'roles';
  everything boolean := (me ->> 'all')::boolean;
  out jsonb := '[]'::jsonb;
  board text[] := array['founder', 'director', 'patron', 'general_secretary',
    'treasurer', 'organizer'];
  zone_exec text[] := array['zone_mayor', 'zone_deputy', 'zone_secretary',
    'zone_treasurer', 'zone_organizer', 'zone_welfare_officer'];
  z record;
begin
  out := out || jsonb_build_object('id', 'announcements',
    'name', 'Announcements',
    'post', coalesce((me -> 'permissions') ? 'announce.post', false));
  out := out || jsonb_build_object('id', 'members', 'name', 'All members',
    'post', true);
  if everything or roles ?| board then
    out := out || jsonb_build_object('id', 'board', 'name', 'Board',
      'post', true);
  end if;
  if everything or roles ?| (board || zone_exec) then
    out := out || jsonb_build_object('id', 'leadership',
      'name', 'Leadership Council', 'post', true);
  end if;
  if everything or roles ?| array['general_secretary', 'zone_secretary'] then
    out := out || jsonb_build_object('id', 'secretariat', 'name', 'Secretariat',
      'post', true);
  end if;
  if everything or roles ?| array['treasurer', 'zone_treasurer'] then
    out := out || jsonb_build_object('id', 'treasury', 'name', 'Treasury',
      'post', true);
  end if;
  if everything or roles ?| array['organizer', 'zone_organizer',
                                  'zone_organizing_helper'] then
    out := out || jsonb_build_object('id', 'organizing', 'name', 'Organizing',
      'post', true);
  end if;
  if everything or roles ?| array['welfare_chairman', 'welfare_secretary',
      'welfare_treasurer', 'welfare_member', 'zone_welfare_officer',
      'zone_welfare_helper'] then
    out := out || jsonb_build_object('id', 'welfare', 'name', 'Welfare',
      'post', true);
  end if;
  if everything or roles ? 'discipline_member' then
    out := out || jsonb_build_object('id', 'discipline',
      'name', 'Disciplinary Committee', 'post', true);
  end if;
  -- A chat for each zone the person has a zone role in (all zones for the
  -- Founder).
  for z in
    select zr.key as id, zr.data ->> 'name' as name
    from public.sync_records zr
    where zr.org_id = (me ->> 'org')::uuid and zr.tbl = 'zones'
      and zr.data ->> 'deleted_at' is null
      and (everything or exists (
        select 1 from jsonb_array_elements(me -> 'role_zones') x
        where x ->> 'level' = 'zone'
          and zr.key = any (string_to_array(x ->> 'zones', ','))))
    order by (zr.data ->> 'code')::int
  loop
    out := out || jsonb_build_object('id', 'zone:' || z.id,
      'name', z.name || ' executives', 'post', true);
  end loop;
  return out;
end;
$$;

create or replace function public.chat_channels(
  token text,
  as_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  org uuid := (me ->> 'org')::uuid;
begin
  return (
    select coalesce(jsonb_agg(c || jsonb_build_object(
      'last_at', m.created_at,
      'last', case when m.id is null then null
                   else m.author_name || ': ' || left(m.body, 80) end)
      order by m.created_at desc nulls last), '[]')
    from jsonb_array_elements(public.chat_channels_for(me)) c
    left join lateral (
      select * from public.chat_messages x
      where x.org_id = org and x.channel = c ->> 'id' and x.deleted_at is null
      order by x.created_at desc limit 1
    ) m on true
  );
end;
$$;

-- The newest messages of a chat (up to 200), oldest first; with [after],
-- only newer ones.
create or replace function public.chat_messages(
  token text,
  channel text,
  after timestamptz default null,
  as_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
begin
  if not exists (select 1 from jsonb_array_elements(
                   public.chat_channels_for(me)) c where c ->> 'id' = channel) then
    raise exception 'You are not in this chat.' using errcode = 'P0001';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', x.id, 'author', x.author_name, 'body', x.body,
      'at', x.created_at, 'mine', x.author_key = me ->> 'member')
      order by x.created_at), '[]')
    from (
      select * from public.chat_messages m
      where m.org_id = (me ->> 'org')::uuid and m.channel = chat_messages.channel
        and m.deleted_at is null and (after is null or m.created_at > after)
      order by m.created_at desc limit 200
    ) x
  );
end;
$$;

create or replace function public.chat_send(
  token text,
  channel text,
  body text,
  as_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  c jsonb;
begin
  select x into c from jsonb_array_elements(public.chat_channels_for(me)) x
  where x ->> 'id' = channel;
  if c is null then
    raise exception 'You are not in this chat.' using errcode = 'P0001';
  end if;
  if not (c ->> 'post')::boolean then
    raise exception 'Only the Founder and General Secretary post here.'
      using errcode = 'P0001';
  end if;
  if length(trim(coalesce(body, ''))) = 0 then
    raise exception 'Write a message first.' using errcode = 'P0001';
  end if;
  insert into public.chat_messages (org_id, channel, author_key, author_name,
    body)
  values ((me ->> 'org')::uuid, channel, me ->> 'member', me ->> 'name',
    left(trim(body), 4000));
  return jsonb_build_object('ok', true);
end;
$$;

-- A Zone Mayor or Zone Secretary (or the General Secretary) sends a
-- complaint about a member to the Disciplinary Committee.
create or replace function public.discipline_file(
  token text,
  member text,
  details text,
  as_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  org uuid := (me ->> 'org')::uuid;
begin
  if not coalesce((me -> 'permissions') ? 'discipline.file', false) then
    raise exception 'Your role cannot send complaints.' using errcode = 'P0001';
  end if;
  if jsonb_typeof(me -> 'zones') = 'array' and not exists (
    select 1 from public.sync_records mz
    where mz.org_id = org and mz.tbl = 'member_zones'
      and mz.data ->> 'member_id' = member and mz.data ->> 'deleted_at' is null
      and (me -> 'zones') ? (mz.data ->> 'zone_id')) then
    raise exception 'You can only report members of your own zone.'
      using errcode = 'P0001';
  end if;
  if length(trim(coalesce(details, ''))) = 0 then
    raise exception 'Describe the complaint.' using errcode = 'P0001';
  end if;
  insert into public.discipline_cases (org_id, member_key, kind, details,
    by_key, by_name)
  values (org, member, 'complaint', left(trim(details), 4000),
    me ->> 'member', me ->> 'name');
  return jsonb_build_object('ok', true);
end;
$$;

-- The Disciplinary Committee's view: every complaint and warning, newest
-- first, or one member's ([member]).
create or replace function public.discipline_list(
  token text,
  member text default null,
  as_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  org uuid := (me ->> 'org')::uuid;
begin
  if not coalesce((me -> 'permissions') ? 'discipline.handle', false) then
    raise exception 'Only the Disciplinary Committee can read these.'
      using errcode = 'P0001';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'member', c.member_key,
      'member_name', m.data ->> 'full_name',
      'member_no', m.data ->> 'member_no',
      'kind', c.kind, 'details', c.details, 'by', c.by_name,
      'status', c.status, 'at', c.created_at)
      order by c.created_at desc), '[]')
    from public.discipline_cases c
    left join public.sync_records m on m.org_id = org and m.tbl = 'members'
      and m.key = c.member_key
    where c.org_id = org and (member is null or c.member_key = member)
  );
end;
$$;

-- The committee sends a warning (the member sees it on their page), and
-- may close the complaint it answers.
create or replace function public.discipline_warn(
  token text,
  member text,
  details text,
  close_case uuid default null,
  as_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  org uuid := (me ->> 'org')::uuid;
begin
  if not coalesce((me -> 'permissions') ? 'discipline.handle', false) then
    raise exception 'Only the Disciplinary Committee can send warnings.'
      using errcode = 'P0001';
  end if;
  if details is not null and length(trim(details)) > 0 then
    insert into public.discipline_cases (org_id, member_key, kind, details,
      by_key, by_name)
    values (org, member, 'warning', left(trim(details), 4000),
      me ->> 'member', 'Disciplinary Committee');
  end if;
  if close_case is not null then
    update public.discipline_cases set status = 'closed'
    where id = close_case and org_id = org;
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Members see announcements and their own warnings on their page.
create or replace function public.member_notices(org uuid, mid text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'announcements', (
      select coalesce(jsonb_agg(x.body order by x.created_at desc), '[]')
      from (select * from public.chat_messages m
            where m.org_id = org and m.channel = 'announcements'
              and m.deleted_at is null
            order by m.created_at desc limit 10) x),
    'warnings', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'details', c.details, 'at', c.created_at)
        order by c.created_at desc), '[]')
      from public.discipline_cases c
      where c.org_id = org and c.member_key = mid and c.kind = 'warning')
  )
$$;

-- Everything an ordinary member sees, now with announcements and warnings.
alter function public.member_home(text) rename to member_home_base;
revoke all on function public.member_home_base(text) from public, anon, authenticated;

create or replace function public.member_home(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  home jsonb := public.member_home_base(token);
  s public.member_sessions := public.member_session_for(token);
begin
  return home || public.member_notices(s.org_id, s.member_key);
end;
$$;
grant execute on function public.member_home(text) to anon, authenticated;

revoke all on function public.chat_identity(text, text) from public, anon, authenticated;
revoke all on function public.chat_channels_for(jsonb) from public, anon, authenticated;
revoke all on function public.member_notices(uuid, text) from public, anon, authenticated;
grant execute on function public.chat_channels(text, text) to anon, authenticated;
grant execute on function public.chat_messages(text, text, timestamptz, text) to anon, authenticated;
grant execute on function public.chat_send(text, text, text, text) to anon, authenticated;
grant execute on function public.discipline_file(text, text, text, text) to anon, authenticated;
grant execute on function public.discipline_list(text, text, text) to anon, authenticated;
grant execute on function public.discipline_warn(text, text, text, uuid, text) to anon, authenticated;
