-- Every zone gets a chat for all of its members. A member sees the chat of each
-- zone they belong to; zone executives see their zones' chats; the Founder and
-- others with full access see every zone's. The old executives-only chat
-- ('zone:<id>') stays as it was.
create or replace function public.zone_chat_channels(me jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select mz.data ->> 'zone_id' as zid
    from public.sync_records mz
    where mz.org_id = (me ->> 'org')::uuid and mz.tbl = 'member_zones'
      and mz.data ->> 'deleted_at' is null
      and me ->> 'member' is not null
      and mz.data ->> 'member_id' = me ->> 'member'
    union
    select unnest(string_to_array(x ->> 'zones', ','))
    from jsonb_array_elements(coalesce(me -> 'role_zones', '[]'::jsonb)) x
    where x ->> 'level' = 'zone'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', 'zonechat:' || z.key,
      'name', (z.data ->> 'name') || ' chat',
      'post', true)
      order by coalesce((z.data ->> 'code')::int, 999)), '[]'::jsonb)
  from public.sync_records z
  where z.org_id = (me ->> 'org')::uuid and z.tbl = 'zones'
    and z.data ->> 'deleted_at' is null
    and lower(z.data ->> 'name') <> 'unassigned'
    and (coalesce((me ->> 'all')::boolean, false)
         or z.key in (select zid from mine))
$$;
revoke all on function public.zone_chat_channels(jsonb)
  from public, anon, authenticated;

do $do$
declare d text := pg_get_functiondef('public.chat_channels_base(jsonb)'::regprocedure);
begin
  if position('zone_chat_channels' in d) = 0 then
    d := replace(d, '|| public.announce_zone_channels(me);',
      '|| public.announce_zone_channels(me) || public.zone_chat_channels(me);');
    if position('zone_chat_channels' in d) = 0 then
      raise exception 'chat_channels_base patch did not match';
    end if;
    execute d;
  end if;
end
$do$;
