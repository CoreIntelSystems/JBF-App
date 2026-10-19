-- WhatsApp-style chats: reply to (quote) a message, a profile picture for
-- each member, and the sender's WhatsApp name and zones on every message.

alter table public.chat_messages add column if not exists reply_to uuid;

-- A member's chat picture: a small image (data URL) they choose themselves.
create table if not exists public.member_avatars (
  org_id uuid not null references public.sync_orgs (id),
  member_key text not null,
  photo text not null check (length(photo) <= 150000),
  updated_at timestamptz not null default now(),
  primary key (org_id, member_key)
);
alter table public.member_avatars enable row level security;
revoke all on public.member_avatars from anon, authenticated;

-- Set (photo) or clear (null) my own picture.
create or replace function public.avatar_set(
  token text, photo text, as_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  org uuid := (me ->> 'org')::uuid;
  mkey text := me ->> 'member';
begin
  if mkey is null then
    raise exception 'Sign in as a member to set a picture.' using errcode = 'P0001';
  end if;
  if photo is null or photo = '' then
    delete from public.member_avatars a
    where a.org_id = org and a.member_key = mkey;
  else
    if photo !~ '^data:image/(jpeg|png|webp);base64,' or length(photo) > 150000 then
      raise exception 'That picture is not allowed. Choose a smaller photo.'
        using errcode = 'P0001';
    end if;
    insert into public.member_avatars (org_id, member_key, photo)
    values (org, mkey, photo)
    on conflict (org_id, member_key)
    do update set photo = excluded.photo, updated_at = now();
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
grant execute on function public.avatar_set(text, text, text) to anon, authenticated;

-- Pictures of everyone who has written in this chat recently, by member key.
create or replace function public.chat_avatars(
  token text, channel text, as_name text default null
) returns jsonb
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
    select coalesce(jsonb_object_agg(a.member_key, a.photo), '{}')
    from public.member_avatars a
    where a.org_id = (me ->> 'org')::uuid
      and a.member_key in (
        select m.author_key from public.chat_messages m
        where m.org_id = (me ->> 'org')::uuid
          and m.channel = chat_avatars.channel and m.deleted_at is null)
  );
end;
$$;
grant execute on function public.chat_avatars(text, text, text) to anon, authenticated;

-- Send a message, optionally as a reply to another one in the same chat.
create or replace function public.chat_reply(
  token text, channel text, body text, reply_to uuid default null,
  as_name text default null
) returns jsonb
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
  if reply_to is not null and not exists (
       select 1 from public.chat_messages q
       where q.id = chat_reply.reply_to and q.org_id = (me ->> 'org')::uuid
         and q.channel = chat_reply.channel) then
    chat_reply.reply_to := null;
  end if;
  insert into public.chat_messages (org_id, channel, author_key, author_name,
    body, reply_to)
  values ((me ->> 'org')::uuid, channel, me ->> 'member', me ->> 'name',
    left(trim(body), 4000), reply_to);
  return jsonb_build_object('ok', true);
end;
$$;
grant execute on function public.chat_reply(text, text, text, uuid, text)
  to anon, authenticated;

-- Messages now carry the sender's key, zones, and the message replied to.
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
      'id', x.id, 'author', x.author_name, 'author_key', x.author_key,
      'author_whatsapp', a.data ->> 'whatsapp_name', 'body', x.body,
      'at', x.created_at, 'mine', x.author_key = me ->> 'member',
      'zones', (
        select coalesce(jsonb_agg(z.data ->> 'name'
          order by (z.data ->> 'code')::int), '[]')
        from public.sync_records mz
        join public.sync_records z on z.org_id = x.org_id
          and z.tbl = 'zones' and z.key = mz.data ->> 'zone_id'
        where mz.org_id = x.org_id and mz.tbl = 'member_zones'
          and mz.data ->> 'member_id' = x.author_key
          and mz.data ->> 'deleted_at' is null),
      'reply', case when q.id is null then null else jsonb_build_object(
        'id', q.id, 'author', q.author_name, 'body', left(q.body, 160)) end)
      order by x.created_at), '[]')
    from (
      select * from public.chat_messages m
      where m.org_id = (me ->> 'org')::uuid and m.channel = chat_messages.channel
        and m.deleted_at is null and (after is null or m.created_at > after)
      order by m.created_at desc limit 200
    ) x
    left join public.sync_records a on a.org_id = x.org_id
      and a.tbl = 'members' and a.key = x.author_key
    left join public.chat_messages q on q.id = x.reply_to
      and q.org_id = x.org_id and q.deleted_at is null
  );
end;
$$;
grant execute on function public.chat_messages(text, text, timestamptz, text)
  to anon, authenticated;

-- Pictures, documents and stickers in chats. Files are kept in the cloud
-- (at most 3 MB each) and fetched when a member opens them.
alter table public.chat_messages
  add column if not exists kind text not null default 'text',
  add column if not exists file_id uuid,
  add column if not exists file_name text,
  add column if not exists file_mime text,
  add column if not exists file_size integer;

create table if not exists public.chat_files (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  channel text not null,
  data text not null check (length(data) <= 4100000),
  created_at timestamptz not null default now()
);
alter table public.chat_files enable row level security;
revoke all on public.chat_files from anon, authenticated;

create or replace function public.chat_post(
  token text, channel text, body text, reply_to uuid default null,
  kind text default 'text', file_name text default null,
  file_mime text default null, file_data text default null,
  as_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  org uuid := (me ->> 'org')::uuid;
  c jsonb;
  fid uuid;
  fsize int;
  fname text;
  fmime text;
  txt text := left(trim(coalesce(body, '')), 4000);
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
  if kind not in ('text', 'image', 'file', 'sticker') then
    raise exception 'Not supported.' using errcode = 'P0001';
  end if;
  if kind = 'text' and txt = '' then
    raise exception 'Write a message first.' using errcode = 'P0001';
  end if;
  if kind = 'sticker' and (txt = '' or length(txt) > 16) then
    raise exception 'Choose a sticker.' using errcode = 'P0001';
  end if;
  if kind in ('image', 'file') then
    if file_data is null or file_data = '' then
      raise exception 'Choose a file to send.' using errcode = 'P0001';
    end if;
    if length(file_data) > 4000000 then
      raise exception 'That file is too big. The most you can send is 3 MB.'
        using errcode = 'P0001';
    end if;
    fmime := lower(coalesce(file_mime, 'application/octet-stream'));
    if fmime !~ '^[a-z0-9.+-]+/[a-z0-9.+-]+$' then
      fmime := 'application/octet-stream';
    end if;
    if kind = 'image' and fmime not like 'image/%' then
      raise exception 'That is not a picture.' using errcode = 'P0001';
    end if;
    fname := left(regexp_replace(coalesce(nullif(trim(file_name), ''), 'file'),
      '[\\/[:cntrl:]]', '_', 'g'), 120);
    fsize := (length(file_data) * 3) / 4;
    insert into public.chat_files (org_id, channel, data)
    values (org, chat_post.channel, file_data) returning id into fid;
  end if;
  if reply_to is not null and not exists (
       select 1 from public.chat_messages q
       where q.id = chat_post.reply_to and q.org_id = org
         and q.channel = chat_post.channel) then
    chat_post.reply_to := null;
  end if;
  insert into public.chat_messages (org_id, channel, author_key, author_name,
    body, reply_to, kind, file_id, file_name, file_mime, file_size)
  values (org, channel, me ->> 'member', me ->> 'name', txt, reply_to, kind,
    fid, fname, fmime, fsize);
  return jsonb_build_object('ok', true);
end;
$$;
grant execute on function public.chat_post(text, text, text, uuid, text, text,
  text, text, text) to anon, authenticated;

create or replace function public.chat_reply(
  token text, channel text, body text, reply_to uuid default null,
  as_name text default null
) returns jsonb
language sql
security definer
set search_path = ''
as $$
  select public.chat_post(token, channel, body, reply_to, 'text', null, null,
    null, as_name)
$$;

-- Open a picture or document from a chat I am in.
create or replace function public.chat_file(
  token text, channel text, file_id uuid, as_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
  m public.chat_messages;
begin
  if not exists (select 1 from jsonb_array_elements(
                   public.chat_channels_for(me)) c where c ->> 'id' = channel) then
    raise exception 'You are not in this chat.' using errcode = 'P0001';
  end if;
  select * into m from public.chat_messages x
  where x.file_id = chat_file.file_id and x.channel = chat_file.channel
    and x.org_id = (me ->> 'org')::uuid and x.deleted_at is null;
  if m.id is null then
    raise exception 'That file is not available.' using errcode = 'P0001';
  end if;
  return (select jsonb_build_object('name', m.file_name, 'mime', m.file_mime,
    'data', f.data) from public.chat_files f where f.id = m.file_id);
end;
$$;
grant execute on function public.chat_file(text, text, uuid, text)
  to anon, authenticated;

-- Messages also say what they carry (text, picture, document, sticker).
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
      'id', x.id, 'author', x.author_name, 'author_key', x.author_key,
      'author_whatsapp', a.data ->> 'whatsapp_name', 'body', x.body,
      'at', x.created_at, 'mine', x.author_key = me ->> 'member',
      'kind', x.kind,
      'file', case when x.file_id is null then null else jsonb_build_object(
        'id', x.file_id, 'name', x.file_name, 'mime', x.file_mime,
        'size', x.file_size) end,
      'zones', (
        select coalesce(jsonb_agg(z.data ->> 'name'
          order by (z.data ->> 'code')::int), '[]')
        from public.sync_records mz
        join public.sync_records z on z.org_id = x.org_id
          and z.tbl = 'zones' and z.key = mz.data ->> 'zone_id'
        where mz.org_id = x.org_id and mz.tbl = 'member_zones'
          and mz.data ->> 'member_id' = x.author_key
          and mz.data ->> 'deleted_at' is null),
      'reply', case when q.id is null then null else jsonb_build_object(
        'id', q.id, 'author', q.author_name, 'kind', q.kind,
        'body', left(q.body, 160)) end)
      order by x.created_at), '[]')
    from (
      select * from public.chat_messages m
      where m.org_id = (me ->> 'org')::uuid and m.channel = chat_messages.channel
        and m.deleted_at is null and (after is null or m.created_at > after)
      order by m.created_at desc limit 200
    ) x
    left join public.sync_records a on a.org_id = x.org_id
      and a.tbl = 'members' and a.key = x.author_key
    left join public.chat_messages q on q.id = x.reply_to
      and q.org_id = x.org_id and q.deleted_at is null
  );
end;
$$;
grant execute on function public.chat_messages(text, text, timestamptz, text)
  to anon, authenticated;

-- My own chat picture, for the Me page.
create or replace function public.avatar_get(token text, as_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, as_name);
begin
  return jsonb_build_object('photo', (
    select a.photo from public.member_avatars a
    where a.org_id = (me ->> 'org')::uuid and a.member_key = me ->> 'member'));
end;
$$;
grant execute on function public.avatar_get(text, text) to anon, authenticated;
