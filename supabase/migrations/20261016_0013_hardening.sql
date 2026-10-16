-- Hardening: lock down a helper nobody should call, index foreign keys,
-- keep daily snapshots of every organisation's records, and let officers
-- see how many members have activated their accounts.

revoke all on function public.rls_auto_enable() from public, anon, authenticated;

create index if not exists member_sessions_org_idx on public.member_sessions (org_id);
create index if not exists sync_codes_org_idx on public.sync_codes (org_id);
create index if not exists sync_codes_created_by_idx on public.sync_codes (created_by);
create index if not exists sync_codes_used_by_idx on public.sync_codes (used_by);
create index if not exists sync_records_pushed_by_idx on public.sync_records (pushed_by);

-- Daily snapshots in seven rolling slots (one per weekday), so the last
-- week is always kept and nothing needs deleting. Only the service role can
-- read them.
create table if not exists public.sync_backups (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.sync_orgs (id),
  slot smallint not null,
  taken_at timestamptz not null default now(),
  records int not null,
  data jsonb not null,
  unique (org_id, slot)
);
alter table public.sync_backups enable row level security;
revoke all on public.sync_backups from public, anon, authenticated;

create or replace function public.sync_take_backup()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  o record;
  n int := 0;
begin
  for o in select id from public.sync_orgs loop
    insert into public.sync_backups (org_id, slot, taken_at, records, data)
    select o.id, extract(dow from now())::smallint, now(), count(*)::int,
      coalesce(jsonb_agg(jsonb_build_object('tbl', r.tbl, 'key', r.key,
        'data', r.data, 'updated_at', r.updated_at)), '[]'::jsonb)
    from public.sync_records r where r.org_id = o.id
    on conflict (org_id, slot) do update
      set taken_at = excluded.taken_at, records = excluded.records,
          data = excluded.data;
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function public.sync_take_backup() from public, anon, authenticated;

-- Puts a snapshot's records back (newest wins is not applied: the snapshot
-- replaces what is there). Run by CoreIntel support only.
create or replace function public.sync_restore_backup(backup bigint)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.sync_backups;
  n int;
begin
  select * into b from public.sync_backups where id = backup;
  if b.id is null then
    raise exception 'No such backup.';
  end if;
  insert into public.sync_records (org_id, tbl, key, data, updated_at)
  select b.org_id, x ->> 'tbl', x ->> 'key', x -> 'data',
    (x ->> 'updated_at')::timestamptz
  from jsonb_array_elements(b.data) x
  on conflict (org_id, tbl, key) do update
    set data = excluded.data, updated_at = excluded.updated_at;
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.sync_restore_backup(bigint) from public, anon, authenticated;

-- How many members have activated their sign-in (for officers' phones).
create or replace function public.activation_summary(token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  d public.sync_devices := public.sync_device_for(token);
begin
  if d.member_key is not null and
     not coalesce((public.member_access(d.org_id, d.member_key) ->> 'officer')::boolean, false) then
    raise exception 'Only officers can see this.' using errcode = 'P0001';
  end if;
  return jsonb_build_object(
    'members', (select count(*) from public.sync_records m
                where m.org_id = d.org_id and m.tbl = 'members'
                  and m.data ->> 'deleted_at' is null),
    'activated', (select count(*) from public.member_accounts a
                  where a.org_id = d.org_id and a.activated_at is not null
                    and a.password_hash is not null)
  );
end;
$$;
revoke all on function public.activation_summary(text) from public;
grant execute on function public.activation_summary(text) to anon, authenticated;

-- Take the snapshot every day at 02:00 (Ghana time is UTC).
create extension if not exists pg_cron;
select cron.schedule('jbf-daily-backup', '0 2 * * *', 'select public.sync_take_backup()');
