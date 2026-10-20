-- Slow down password guessing from one network address (2026-10-20).
-- The per-member lock (5 wrong passwords, 15 minutes) does not stop someone
-- trying one common password against many member IDs. This counts wrong
-- attempts per network address instead. Addresses are stored hashed.
-- Mobile networks share addresses between many people, so the limit is
-- generous: 40 wrong attempts in 15 minutes.

create table if not exists public.auth_ip_guard (
  ip_hash text primary key,
  failures int not null default 0,
  window_start timestamptz not null default now()
);
alter table public.auth_ip_guard enable row level security;
revoke all on public.auth_ip_guard from anon, authenticated;

-- Refuses the attempt when this address has already failed too often.
create or replace function public.auth_ip_gate(ip text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.auth_ip_guard;
begin
  select * into g from public.auth_ip_guard where ip_hash = public.sync_hash(ip);
  if g.ip_hash is not null and g.window_start > now() - interval '15 minutes'
     and g.failures >= 40 then
    raise exception 'Too many wrong attempts from this network. Please try again in a few minutes.'
      using errcode = 'P0001';
  end if;
end;
$$;

-- Counts one wrong attempt, starting a fresh window when the old one ended.
create or replace function public.auth_ip_failed(ip text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.auth_ip_guard as g (ip_hash, failures, window_start)
  values (public.sync_hash(ip), 1, now())
  on conflict (ip_hash) do update
    set failures = case when g.window_start > now() - interval '15 minutes'
                        then g.failures + 1 else 1 end,
        window_start = case when g.window_start > now() - interval '15 minutes'
                            then g.window_start else now() end;
end;
$$;

revoke all on function public.auth_ip_gate(text) from public, anon, authenticated;
revoke all on function public.auth_ip_failed(text) from public, anon, authenticated;
grant execute on function public.auth_ip_gate(text) to service_role;
grant execute on function public.auth_ip_failed(text) to service_role;
