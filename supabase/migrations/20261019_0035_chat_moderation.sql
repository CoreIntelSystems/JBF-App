-- Chat moderation (Google Play user-generated-content policy):
-- members can report a message and block another member; people with the
-- discipline permission (and the Founder) review reports and can remove
-- the message. Chat sign-ins also stop working after 30 days unused.

create table if not exists public.chat_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  message_id uuid not null references public.chat_messages (id),
  reporter_key text not null,
  reason text not null check (length(reason) <= 300),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by text,
  unique (message_id, reporter_key)
);
alter table public.chat_reports enable row level security;
revoke all on public.chat_reports from anon, authenticated;

create table if not exists public.chat_blocks (
  org_id uuid not null references public.sync_orgs (id),
  blocker_key text not null,
  blocked_key text not null,
  active boolean not null default true,
  primary key (org_id, blocker_key, blocked_key)
);
alter table public.chat_blocks enable row level security;
revoke all on public.chat_blocks from anon, authenticated;

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
  where token_hash = public.sync_hash(token) and revoked_at is null
    and coalesce(last_seen_at, created_at) > now() - interval '30 days';
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

create or replace function public.chat_report(
  token text, msg uuid, reason text, as_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  m public.chat_messages;
begin
  if me ->> 'member' is null then
    raise exception 'Sign in as a member to report a message.' using errcode = 'P0001';
  end if;
  select * into m from public.chat_messages
  where id = msg and org_id = (me ->> 'org')::uuid and deleted_at is null;
  if m.id is null or not exists (
    select 1 from jsonb_array_elements(public.chat_channels_for(me)) c
    where c ->> 'id' = m.channel) then
    raise exception 'That message is not available.' using errcode = 'P0001';
  end if;
  insert into public.chat_reports (org_id, message_id, reporter_key, reason)
  values (m.org_id, m.id, me ->> 'member', left(coalesce(trim(reason), ''), 300))
  on conflict (message_id, reporter_key) do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.chat_block(
  token text, target text, blocked boolean, as_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
begin
  if me ->> 'member' is null then
    raise exception 'Sign in as a member to block someone.' using errcode = 'P0001';
  end if;
  if target is null or target = me ->> 'member' then
    raise exception 'You cannot block yourself.' using errcode = 'P0001';
  end if;
  insert into public.chat_blocks as b (org_id, blocker_key, blocked_key, active)
  values ((me ->> 'org')::uuid, me ->> 'member', target, blocked)
  on conflict (org_id, blocker_key, blocked_key) do update set active = excluded.active;
  return jsonb_build_object('ok', true);
end;
$$;

-- The members I have blocked: [{key, name}].
create or replace function public.chat_blocks_list(token text, as_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'key', b.blocked_key,
      'name', coalesce(r.data ->> 'full_name', 'Member')))
    from public.chat_blocks b
    left join public.sync_records r on r.org_id = b.org_id
      and r.tbl = 'members' and r.key = b.blocked_key
    where b.org_id = (me ->> 'org')::uuid and b.blocker_key = me ->> 'member'
      and b.active), '[]'::jsonb);
end;
$$;

create or replace function public.chat_moderator(me jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce((me ->> 'all')::boolean, false)
    or (me -> 'permissions') ? 'discipline.handle'
$$;

-- Open reports, for the Founder and people who handle discipline.
create or replace function public.chat_reports_list(token text, as_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
begin
  if not public.chat_moderator(me) then
    raise exception 'Only the Founder and discipline officers can see reports.'
      using errcode = 'P0001';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id, 'message_id', m.id, 'channel', m.channel,
      'author', m.author_name, 'body', left(m.body, 500), 'kind', m.kind,
      'reason', r.reason, 'at', r.created_at,
      'removed', m.deleted_at is not null) order by r.created_at desc)
    from public.chat_reports r
    join public.chat_messages m on m.id = r.message_id
    where r.org_id = (me ->> 'org')::uuid and r.resolved_at is null), '[]'::jsonb);
end;
$$;

-- Close a report, and take the message down if it breaks the rules.
create or replace function public.chat_report_resolve(
  token text, report uuid, remove boolean, as_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  r public.chat_reports;
begin
  if not public.chat_moderator(me) then
    raise exception 'Only the Founder and discipline officers can do this.'
      using errcode = 'P0001';
  end if;
  select * into r from public.chat_reports
  where id = report and org_id = (me ->> 'org')::uuid;
  if r.id is null then
    raise exception 'Report not found.' using errcode = 'P0001';
  end if;
  update public.chat_reports
    set resolved_at = now(), resolved_by = coalesce(me ->> 'member', me ->> 'name')
  where message_id = r.message_id and resolved_at is null;
  if remove then
    update public.chat_messages set deleted_at = now() where id = r.message_id;
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.chat_report(text, uuid, text, text) to anon, authenticated;
grant execute on function public.chat_block(text, text, boolean, text) to anon, authenticated;
grant execute on function public.chat_blocks_list(text, text) to anon, authenticated;
grant execute on function public.chat_reports_list(text, text) to anon, authenticated;
grant execute on function public.chat_report_resolve(text, uuid, boolean, text) to anon, authenticated;
revoke all on function public.chat_moderator(jsonb) from public, anon, authenticated;
