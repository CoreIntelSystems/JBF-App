-- Members are known to each other by username in chats, not by full name, and
-- the member list shows only people in the caller's own zones.

-- The name shown in chats: the member's username, else their first name.
create or replace function public.chat_display_name(member jsonb, fallback text)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(nullif(trim(member ->> 'whatsapp_name'), ''),
                  nullif(split_part(trim(coalesce(fallback, '')), ' ', 1), ''),
                  'Member')
$$;

-- The zone ids a member may see the member list for; null means every zone
-- (national and board officers and admins). The holding zone never counts.
create or replace function public.member_zone_scope(org uuid, mid text)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  acc jsonb := public.member_access(org, mid);
begin
  if coalesce((acc ->> 'admin')::boolean, false) or exists (
       select 1 from jsonb_array_elements(coalesce(acc -> 'roles', '[]'::jsonb)) r
       where r ->> 'level' in ('national', 'board')) then
    return null;
  end if;
  return coalesce((
    select array_agg(distinct mz.data ->> 'zone_id')
    from public.sync_records mz
    join public.sync_records z on z.org_id = org and z.tbl = 'zones'
      and z.key = mz.data ->> 'zone_id'
    where mz.org_id = org and mz.tbl = 'member_zones'
      and mz.data ->> 'member_id' = mid and mz.data ->> 'deleted_at' is null
      and lower(z.data ->> 'name') <> 'unassigned'), array[]::text[]);
end;
$$;
revoke all on function public.member_zone_scope(uuid, text)
  from public, anon, authenticated;

do $do$
declare d text;
begin
  d := pg_get_functiondef('public.chat_messages(text,text,timestamptz,text)'::regprocedure);
  if position('chat_display_name' in d) = 0 then
    d := replace(d, $r$'author', x.author_name,$r$, $r$'author', public.chat_display_name(a.data, x.author_name),$r$);
    d := replace(d, $r$'author_whatsapp', a.data ->> 'whatsapp_name',$r$, $r$'author_whatsapp', null::text,$r$);
    d := replace(d, $r$'author', q.author_name,$r$, $r$'author', public.chat_display_name(qa.data, q.author_name),$r$);
    d := replace(d, E'      and q.org_id = x.org_id and q.deleted_at is null\n',
      E'      and q.org_id = x.org_id and q.deleted_at is null\n    left join public.sync_records qa on qa.org_id = q.org_id\n      and qa.tbl = ''members'' and qa.key = q.author_key\n');
    if position('qa.data' in d) = 0 or position('null::text' in d) = 0 then
      raise exception 'chat_messages patch did not match';
    end if;
    execute d;
  end if;

  d := pg_get_functiondef('public.chat_channels(text,text)'::regprocedure);
  if position('chat_display_name' in d) = 0 then
    d := replace(d, $r$else m.author_name || ': ' ||$r$,
      $r$else public.chat_display_name((select r.data from public.sync_records r
                  where r.org_id = m.org_id and r.tbl = 'members'
                    and r.key = m.author_key), m.author_name) || ': ' ||$r$);
    if position('chat_display_name' in d) = 0 then
      raise exception 'chat_channels patch did not match';
    end if;
    execute d;
  end if;

  d := pg_get_functiondef('public.member_home_pre_welfare(text)'::regprocedure);
  if position('member_zone_scope' in d) = 0 then
    d := replace(d, $r$and d.data ->> 'status' = 'active'));$r$,
      $r$and d.data ->> 'status' = 'active'
          and (public.member_zone_scope(s.org_id, s.member_key) is null
               or exists (
                 select 1 from public.sync_records mz2
                 where mz2.org_id = s.org_id and mz2.tbl = 'member_zones'
                   and mz2.data ->> 'member_id' = d.key
                   and mz2.data ->> 'deleted_at' is null
                   and mz2.data ->> 'zone_id' = any (
                     public.member_zone_scope(s.org_id, s.member_key))))));$r$);
    if position('member_zone_scope' in d) = 0 then
      raise exception 'member_home_pre_welfare patch did not match';
    end if;
    execute d;
  end if;
end
$do$;
