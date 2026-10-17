-- The name each member uses on WhatsApp. It lives in the member's record
-- (members.whatsapp_name, schema v12 on phones), so it syncs like any other
-- detail. Every member may set their own, even those whose other details are
-- kept by their Zone Secretary. It shows on their card, next to their name in
-- chats, and members can search the directory by it.

-- Saving the WhatsApp name first, then the rest through the earlier rules.
do $$
begin
  if not exists (select 1 from pg_proc p
                 join pg_namespace s on s.oid = p.pronamespace
                 where s.nspname = 'public'
                   and p.proname = 'member_update_profile_base') then
    alter function public.member_update_profile(text, jsonb, text[])
      rename to member_update_profile_base;
  end if;
end;
$$;
revoke all on function public.member_update_profile_base(text, jsonb, text[])
  from public, anon, authenticated;

create or replace function public.member_update_profile(
  token text,
  patch jsonb,
  zone_ids text[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.member_sessions := public.member_session_for(token);
  stamp text := to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS')
    || ' +00:00';
  wa text;
  rest jsonb := coalesce(patch, '{}') - 'whatsapp_name';
begin
  if coalesce(patch, '{}') ? 'whatsapp_name' then
    wa := nullif(btrim(regexp_replace(patch ->> 'whatsapp_name', '\s+', ' ',
      'g')), '');
    if length(coalesce(wa, '')) > 200 then
      raise exception 'That is too long.' using errcode = 'P0001';
    end if;
    update public.sync_records r
    set data = r.data || jsonb_build_object('whatsapp_name', wa,
          'updated_at', stamp),
        updated_at = now(), pushed_by = null
    where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key;
    if not found then
      raise exception 'Member not found.' using errcode = 'P0001';
    end if;
  end if;
  if rest <> '{}'::jsonb or zone_ids is not null then
    return public.member_update_profile_base(token, rest, zone_ids);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
grant execute on function public.member_update_profile(text, jsonb, text[])
  to anon, authenticated;

-- Members' home: their WhatsApp name (card and Me), and the directory with
-- WhatsApp names so they can search by them.
create or replace function public.member_home(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  home jsonb := public.member_home_base(token);
  s public.member_sessions := public.member_session_for(token);
  m jsonb;
  editable boolean;
  out jsonb;
begin
  select r.data into m from public.sync_records r
  where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key;
  editable := coalesce((m ->> 'self_edit')::int, 0) = 1;
  out := home || public.member_notices(s.org_id, s.member_key)
    || jsonb_build_object(
      'roles', public.member_role_labels(s.org_id, s.member_key),
      'self_edit', editable,
      'whatsapp_name', m ->> 'whatsapp_name',
      'member', (home -> 'member')
        || jsonb_build_object('whatsapp_name', m ->> 'whatsapp_name'),
      'directory', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'name', d.data ->> 'full_name',
          'whatsapp_name', d.data ->> 'whatsapp_name',
          'zones', (
            select coalesce(jsonb_agg(z.data ->> 'name'
              order by (z.data ->> 'code')::int), '[]')
            from public.sync_records mz
            join public.sync_records z on z.org_id = s.org_id
              and z.tbl = 'zones' and z.key = mz.data ->> 'zone_id'
            where mz.org_id = s.org_id and mz.tbl = 'member_zones'
              and mz.data ->> 'member_id' = d.key
              and mz.data ->> 'deleted_at' is null))
          order by d.data ->> 'full_name'), '[]')
        from public.sync_records d
        where d.org_id = s.org_id and d.tbl = 'members'
          and d.data ->> 'deleted_at' is null
          and d.data ->> 'status' = 'active'));
  if editable then
    out := out || jsonb_build_object(
      'zones_locked', exists (
        select 1 from public.member_zone_choice c
        where c.org_id = s.org_id and c.member_key = s.member_key),
      'profile', jsonb_build_object(
        'full_name', m ->> 'full_name',
        'whatsapp_name', m ->> 'whatsapp_name', 'gender', m ->> 'gender',
        'date_of_birth', left(m ->> 'date_of_birth', 10),
        'nationality', m ->> 'nationality', 'occupation', m ->> 'occupation',
        'marital_status', m ->> 'marital_status', 'location', m ->> 'location',
        'phone', m ->> 'phone', 'whatsapp', m ->> 'whatsapp',
        'email', m ->> 'email', 'address', m ->> 'address',
        'gps_address', m ->> 'gps_address',
        'emergency_name', m ->> 'emergency_name',
        'emergency_phone', m ->> 'emergency_phone'),
      'zone_options', coalesce((
        select jsonb_agg(jsonb_build_object('id', z.key,
          'code', (z.data ->> 'code')::int, 'name', z.data ->> 'name')
          order by (z.data ->> 'code')::int)
        from public.sync_records z
        where z.org_id = s.org_id and z.tbl = 'zones'
          and z.data ->> 'deleted_at' is null
          and coalesce((z.data ->> 'is_active')::int, 0) = 1), '[]'),
      'zone_ids', coalesce((
        select jsonb_agg(r.data ->> 'zone_id'
          order by (r.data ->> 'is_primary')::int desc)
        from public.sync_records r
        where r.org_id = s.org_id and r.tbl = 'member_zones'
          and r.data ->> 'member_id' = s.member_key
          and r.data ->> 'deleted_at' is null), '[]'));
  end if;
  return out;
end;
$$;
grant execute on function public.member_home(text) to anon, authenticated;

-- Chats: each message carries its sender's current WhatsApp name.
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
      'id', x.id, 'author', x.author_name,
      'author_whatsapp', a.data ->> 'whatsapp_name', 'body', x.body,
      'at', x.created_at, 'mine', x.author_key = me ->> 'member')
      order by x.created_at), '[]')
    from (
      select * from public.chat_messages m
      where m.org_id = (me ->> 'org')::uuid and m.channel = chat_messages.channel
        and m.deleted_at is null and (after is null or m.created_at > after)
      order by m.created_at desc limit 200
    ) x
    left join public.sync_records a on a.org_id = x.org_id
      and a.tbl = 'members' and a.key = x.author_key
  );
end;
$$;
