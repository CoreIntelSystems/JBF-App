-- Payment requests: the Treasury or the Welfare Committee asks members to
-- pay (dues, a levy, a Silver Collection), members say how they paid (for
-- example the Mobile Money reference), and a treasurer confirms. A
-- confirmed payment becomes a normal receipt that every phone receives by
-- sync, with its own receipt series (ONL-YYYY-000001) so it never clashes
-- with receipts written on phones.
--
-- Cloud-only, like the offices: everything goes through these functions
-- with the caller's token. Zone treasurers ask and confirm for their own
-- zones only.

create table if not exists public.pay_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  office text not null check (office in ('treasury', 'welfare')),
  title text not null check (length(trim(title)) between 2 and 200),
  details text check (length(details) <= 2000),
  type_id text not null,
  amount bigint check (amount > 0),
  period text check (period ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  due_on date,
  zone_ids jsonb,
  pay_to text check (length(pay_to) <= 500),
  by_key text not null,
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  closed_by text
);
create index if not exists pay_requests_org
  on public.pay_requests (org_id, created_at desc);
alter table public.pay_requests enable row level security;

create table if not exists public.pay_claims (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  request_id uuid not null references public.pay_requests (id),
  member_key text not null,
  amount bigint not null check (amount > 0),
  method text not null check (method in ('momo', 'bank', 'cash')),
  reference text check (length(reference) <= 100),
  paid_on date not null,
  note text check (length(note) <= 500),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'rejected')),
  decided_by text,
  decided_at timestamptz,
  decision_note text,
  receipt_no text unique,
  payment_key text,
  created_at timestamptz not null default now()
);
create unique index if not exists pay_claims_one_live
  on public.pay_claims (request_id, member_key) where status <> 'rejected';
create index if not exists pay_claims_request
  on public.pay_claims (request_id, status);
alter table public.pay_claims enable row level security;

-- Who the caller is and what they may do with payment requests.
create or replace function public.pay_who(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.chat_identity(token, null);
  perms jsonb := coalesce(me -> 'permissions', '[]');
  everything boolean := coalesce((me ->> 'all')::boolean, false);
begin
  if me ->> 'member' is null then
    raise exception 'Sign in with your own member ID to do this.'
      using errcode = 'P0001';
  end if;
  return me || jsonb_build_object(
    'can_confirm', everything or perms ?| array['payments.record', 'welfare.pay'],
    'can_ask_treasury', everything or perms ?| array['payments.record', 'dues.manage'],
    'can_ask_welfare', everything or perms ?| array['welfare.prepare',
      'welfare.approve', 'welfare.pay'])
    -- A zone officer's zones; left out (no limit) for everyone else.
    || case when not everything and jsonb_typeof(me -> 'zones') = 'array'
      then jsonb_build_object('scope', me -> 'zones') else '{}'::jsonb end;
end;
$$;
revoke all on function public.pay_who(text) from public, anon, authenticated;

-- Whether member [mkey] is asked by request [r].
create or replace function public.pay_targets(r public.pay_requests, mkey text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.sync_records m
    where m.org_id = r.org_id and m.tbl = 'members' and m.key = mkey
      and m.data ->> 'deleted_at' is null and m.data ->> 'status' = 'active')
  and (r.zone_ids is null or exists (
    select 1 from public.sync_records z
    where z.org_id = r.org_id and z.tbl = 'member_zones'
      and z.data ->> 'deleted_at' is null and z.data ->> 'member_id' = mkey
      and r.zone_ids ? (z.data ->> 'zone_id')))
$$;
revoke all on function public.pay_targets(public.pay_requests, text)
  from public, anon, authenticated;

-- Whether an officer with zone [scope] (null = everything) sees request r.
create or replace function public.pay_in_scope(r public.pay_requests, scope jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select scope is null or (r.zone_ids is not null
    and not exists (select 1 from jsonb_array_elements_text(r.zone_ids) z
                    where not scope ? z))
$$;
revoke all on function public.pay_in_scope(public.pay_requests, jsonb)
  from public, anon, authenticated;

create or replace function public.pay_request_json(r public.pay_requests)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id, 'office', r.office, 'title', r.title, 'details', r.details,
    'type_id', r.type_id,
    'type', (select t.data ->> 'name' from public.sync_records t
             where t.org_id = r.org_id and t.tbl = 'contribution_types'
               and t.key = r.type_id),
    'amount', r.amount, 'period', r.period, 'due_on', r.due_on,
    'pay_to', r.pay_to, 'at', r.created_at,
    'by', public.office_member_name(r.org_id, r.by_key),
    'zones', (select jsonb_agg(z.data ->> 'name' order by z.data ->> 'name')
              from public.sync_records z
              where z.org_id = r.org_id and z.tbl = 'zones'
                and r.zone_ids ? z.key),
    'closed', r.closed_at is not null)
$$;
revoke all on function public.pay_request_json(public.pay_requests)
  from public, anon, authenticated;

-- An officer asks members to pay. zones null = every active member.
create or replace function public.pay_request_create(
  token text, office text, title text, type_id text,
  amount bigint default null, period text default null,
  due_on date default null, zones jsonb default null,
  pay_to text default null, details text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
  scope jsonb := me -> 'scope';
  t jsonb;
  r public.pay_requests;
begin
  if office = 'treasury' and not (me ->> 'can_ask_treasury')::boolean
     or office = 'welfare' and not (me ->> 'can_ask_welfare')::boolean
     or office not in ('treasury', 'welfare') then
    raise exception 'You cannot ask members to pay.' using errcode = 'P0001';
  end if;
  select x.data into t from public.sync_records x
  where x.org_id = org and x.tbl = 'contribution_types'
    and x.key = pay_request_create.type_id
    and x.data ->> 'deleted_at' is null;
  if t is null then
    raise exception 'Choose what the payment is for.' using errcode = 'P0001';
  end if;
  if t ->> 'frequency' = 'monthly' and period is null then
    raise exception 'Choose the month being paid for.' using errcode = 'P0001';
  end if;
  if zones is not null and (jsonb_typeof(zones) <> 'array'
     or jsonb_array_length(zones) = 0) then
    zones := null;
  end if;
  if scope is not null then
    -- Zone officers ask their own zones only.
    if zones is null then
      zones := scope;
    elsif exists (select 1 from jsonb_array_elements_text(zones) z
                  where not scope ? z) then
      raise exception 'You can only ask members of your own zones.'
        using errcode = 'P0001';
    end if;
  end if;
  insert into public.pay_requests (org_id, office, title, details, type_id,
    amount, period, due_on, zone_ids, pay_to, by_key)
  values (org, office, trim(title), nullif(trim(details), ''),
    pay_request_create.type_id, amount, period, due_on, zones,
    nullif(trim(pay_to), ''), me ->> 'member')
  returning * into r;
  return jsonb_build_object('id', r.id);
end;
$$;
revoke all on function public.pay_request_create(text, text, text, text,
  bigint, text, date, jsonb, text, text) from public;
grant execute on function public.pay_request_create(text, text, text, text,
  bigint, text, date, jsonb, text, text) to anon, authenticated;

create or replace function public.pay_request_close(token text, id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  r public.pay_requests;
begin
  select * into r from public.pay_requests x
  where x.id = pay_request_close.id and x.org_id = (me ->> 'org')::uuid;
  if r.id is null or not public.pay_in_scope(r, me -> 'scope')
     or not (r.by_key = me ->> 'member' or (me ->> 'can_confirm')::boolean) then
    raise exception 'You cannot close this request.' using errcode = 'P0001';
  end if;
  update public.pay_requests set closed_at = now(), closed_by = me ->> 'member'
  where pay_requests.id = r.id and closed_at is null;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.pay_request_close(text, uuid) from public;
grant execute on function public.pay_request_close(text, uuid)
  to anon, authenticated;

-- A member: the open requests addressed to them, with what they reported.
create or replace function public.pay_requests_mine(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
  mkey text := me ->> 'member';
begin
  return (select coalesce(jsonb_agg(public.pay_request_json(r) ||
      jsonb_build_object('mine', (
        select jsonb_build_object('id', c.id, 'status', c.status,
          'amount', c.amount, 'method', c.method, 'reference', c.reference,
          'paid_on', c.paid_on, 'receipt_no', c.receipt_no,
          'decision_note', c.decision_note)
        from public.pay_claims c
        where c.request_id = r.id and c.member_key = mkey
        order by c.created_at desc limit 1))
      order by r.due_on nulls last, r.created_at desc), '[]')
    from public.pay_requests r
    where r.org_id = org
      and (r.closed_at is null or exists (
        select 1 from public.pay_claims c
        where c.request_id = r.id and c.member_key = mkey
          and c.created_at > now() - interval '30 days'))
      and r.created_at > now() - interval '1 year'
      and public.pay_targets(r, mkey));
end;
$$;
revoke all on function public.pay_requests_mine(text) from public;
grant execute on function public.pay_requests_mine(text) to anon, authenticated;

-- A member says they have paid.
create or replace function public.pay_claim_submit(
  token text, request uuid, amount bigint, method text,
  reference text default null, paid_on date default null,
  note text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
  mkey text := me ->> 'member';
  r public.pay_requests;
  c public.pay_claims;
begin
  select * into r from public.pay_requests x
  where x.id = request and x.org_id = org;
  if r.id is null or not public.pay_targets(r, mkey) then
    raise exception 'This request is not for you.' using errcode = 'P0001';
  end if;
  if r.closed_at is not null then
    raise exception 'This request is closed.' using errcode = 'P0001';
  end if;
  if amount is null or amount <= 0 then
    raise exception 'Enter the amount you paid.' using errcode = 'P0001';
  end if;
  if method not in ('momo', 'bank', 'cash') then
    raise exception 'Choose how you paid.' using errcode = 'P0001';
  end if;
  if method in ('momo', 'bank') and coalesce(trim(reference), '') = '' then
    raise exception 'Enter the transaction ID from your Mobile Money or bank message.'
      using errcode = 'P0001';
  end if;
  if exists (select 1 from public.pay_claims x
             where x.request_id = r.id and x.member_key = mkey
               and x.status <> 'rejected') then
    raise exception 'You have already told the Treasurer about this payment.'
      using errcode = 'P0001';
  end if;
  if exists (select 1 from public.pay_claims x
             where x.org_id = org and x.method <> 'cash'
               and lower(trim(x.reference)) = lower(trim(pay_claim_submit.reference))
               and x.status <> 'rejected') then
    raise exception 'This transaction ID has already been used.'
      using errcode = 'P0001';
  end if;
  insert into public.pay_claims (org_id, request_id, member_key, amount,
    method, reference, paid_on, note)
  values (org, r.id, mkey, amount, method, nullif(trim(reference), ''),
    coalesce(paid_on, current_date), nullif(trim(note), ''))
  returning * into c;
  return jsonb_build_object('id', c.id);
end;
$$;
revoke all on function public.pay_claim_submit(text, uuid, bigint, text,
  text, date, text) from public;
grant execute on function public.pay_claim_submit(text, uuid, bigint, text,
  text, date, text) to anon, authenticated;

-- Officers: the requests they can see, with how many have paid.
create or replace function public.pay_requests_list(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
begin
  if not ((me ->> 'can_confirm')::boolean
          or (me ->> 'can_ask_treasury')::boolean
          or (me ->> 'can_ask_welfare')::boolean) then
    raise exception 'Only treasurers and the Welfare team can see payment requests.'
      using errcode = 'P0001';
  end if;
  return jsonb_build_object(
    'can_confirm', (me ->> 'can_confirm')::boolean,
    'can_ask_treasury', (me ->> 'can_ask_treasury')::boolean,
    'can_ask_welfare', (me ->> 'can_ask_welfare')::boolean,
    'zone_only', me -> 'scope' is not null,
    'types', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.key, 'name', t.data ->> 'name',
        'frequency', t.data ->> 'frequency',
        'amount', (t.data ->> 'amount')::bigint)
        order by t.data ->> 'name'), '[]')
      from public.sync_records t
      where t.org_id = org and t.tbl = 'contribution_types'
        and t.data ->> 'deleted_at' is null
        and coalesce((t.data ->> 'is_active')::int, 1) = 1),
    'zones', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', z.key, 'name', z.data ->> 'name')
        order by coalesce((z.data ->> 'code')::int, 999)), '[]')
      from public.sync_records z
      where z.org_id = org and z.tbl = 'zones'
        and z.data ->> 'deleted_at' is null
        and coalesce((z.data ->> 'is_active')::int, 1) = 1
        and lower(z.data ->> 'name') <> 'unassigned'
        and (me -> 'scope' is null or (me -> 'scope') ? z.key)),
    'requests', (select coalesce(jsonb_agg(public.pay_request_json(r) ||
        jsonb_build_object(
          'asked', (select count(*) from public.sync_records m
                    where m.org_id = org and m.tbl = 'members'
                      and public.pay_targets(r, m.key)),
          'pending', (select count(*) from public.pay_claims c
                      where c.request_id = r.id and c.status = 'pending'),
          'confirmed', (select count(*) from public.pay_claims c
                        where c.request_id = r.id and c.status = 'confirmed'),
          'collected', (select coalesce(sum(c.amount), 0)
                        from public.pay_claims c
                        where c.request_id = r.id and c.status = 'confirmed'))
        order by r.closed_at is not null, r.created_at desc), '[]')
      from public.pay_requests r
      where r.org_id = org and public.pay_in_scope(r, me -> 'scope')
        and (r.closed_at is null or r.closed_at > now() - interval '90 days')));
end;
$$;
revoke all on function public.pay_requests_list(text) from public;
grant execute on function public.pay_requests_list(text) to anon, authenticated;

-- Officers: the payments members reported for one request.
create or replace function public.pay_claims_for(token text, request uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
  scope jsonb := me -> 'scope';
  r public.pay_requests;
begin
  select * into r from public.pay_requests x
  where x.id = request and x.org_id = org;
  if r.id is null or not public.pay_in_scope(r, scope)
     or not ((me ->> 'can_confirm')::boolean or r.by_key = me ->> 'member') then
    raise exception 'You cannot see these payments.' using errcode = 'P0001';
  end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'member', c.member_key,
      'member_name', public.office_member_name(org, c.member_key),
      'member_no', (select m.data ->> 'member_no' from public.sync_records m
                    where m.org_id = org and m.tbl = 'members'
                      and m.key = c.member_key),
      'amount', c.amount, 'method', c.method, 'reference', c.reference,
      'paid_on', c.paid_on, 'note', c.note, 'status', c.status,
      'at', c.created_at, 'receipt_no', c.receipt_no,
      'decided_by', public.office_member_name(org, c.decided_by),
      'decision_note', c.decision_note)
      order by c.status <> 'pending', c.created_at desc), '[]')
    from public.pay_claims c
    where c.request_id = r.id
      and (scope is null or exists (
        select 1 from public.sync_records z
        where z.org_id = org and z.tbl = 'member_zones'
          and z.data ->> 'deleted_at' is null
          and z.data ->> 'member_id' = c.member_key
          and scope ? (z.data ->> 'zone_id'))));
end;
$$;
revoke all on function public.pay_claims_for(text, uuid) from public;
grant execute on function public.pay_claims_for(text, uuid)
  to anon, authenticated;

-- A treasurer confirms (the money arrived) or rejects a reported payment.
-- Confirming writes a normal receipt to the shared records.
create or replace function public.pay_claim_decide(
  token text, claim uuid, confirm boolean, note text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
  scope jsonb := me -> 'scope';
  c public.pay_claims;
  r public.pay_requests;
  t jsonb;
  n int;
  rno text;
  pkey text := gen_random_uuid()::text;
  stamp text := to_char(now() at time zone 'utc',
    'YYYY-MM-DD"T"HH24:MI:SS.MS "+00:00"');
begin
  if not (me ->> 'can_confirm')::boolean then
    raise exception 'Only a treasurer can confirm payments.'
      using errcode = 'P0001';
  end if;
  select * into c from public.pay_claims x
  where x.id = claim and x.org_id = org for update;
  if c.id is null then
    raise exception 'No such payment.' using errcode = 'P0001';
  end if;
  select * into r from public.pay_requests x where x.id = c.request_id;
  if scope is not null and not exists (
       select 1 from public.sync_records z
       where z.org_id = org and z.tbl = 'member_zones'
         and z.data ->> 'deleted_at' is null
         and z.data ->> 'member_id' = c.member_key
         and scope ? (z.data ->> 'zone_id')) then
    raise exception 'This member is not in your zones.' using errcode = 'P0001';
  end if;
  if c.status <> 'pending' then
    raise exception 'This payment has already been decided.'
      using errcode = 'P0001';
  end if;
  if c.member_key = me ->> 'member' then
    raise exception 'Another treasurer must confirm your own payment.'
      using errcode = 'P0001';
  end if;
  if not confirm then
    if coalesce(trim(pay_claim_decide.note), '') = '' then
      raise exception 'Say why, so the member knows what to do.'
        using errcode = 'P0001';
    end if;
    update public.pay_claims set status = 'rejected',
      decided_by = me ->> 'member', decided_at = now(),
      decision_note = trim(pay_claim_decide.note)
    where id = c.id;
    return jsonb_build_object('ok', true);
  end if;

  select x.data into t from public.sync_records x
  where x.org_id = org and x.tbl = 'contribution_types' and x.key = r.type_id;
  perform pg_advisory_xact_lock(hashtext('pay_receipt:' || org::text));
  select coalesce(max(substring(x.receipt_no from '(\d+)$')::int), 0) + 1
    into n
  from public.pay_claims x
  where x.org_id = org and x.receipt_no like
    'ONL-' || to_char(current_date, 'YYYY') || '-%';
  rno := 'ONL-' || to_char(current_date, 'YYYY') || '-' || lpad(n::text, 6, '0');

  insert into public.sync_records (org_id, tbl, key, data, updated_at)
  values (org, 'payments', pkey, jsonb_build_object(
    'id', pkey, 'receipt_no', rno, 'member_id', c.member_key,
    'contribution_type_id', r.type_id,
    'period', case when t ->> 'frequency' = 'monthly' then r.period end,
    'amount', c.amount, 'method', c.method, 'reference', c.reference,
    'paid_on', to_char(c.paid_on, 'YYYY-MM-DD') || 'T12:00:00.000 +00:00',
    'collected_by', null,
    'collector_name', coalesce(public.office_member_name(org, me ->> 'member'),
      'Treasurer') || ' (online)',
    'remarks', left('Paid online: ' || r.title, 200),
    'status', 'valid', 'event_id', null,
    'created_at', stamp, 'updated_at', stamp, 'created_by', null,
    'device_id', null, 'deleted_at', null), now());

  update public.pay_claims set status = 'confirmed',
    decided_by = me ->> 'member', decided_at = now(),
    decision_note = nullif(trim(pay_claim_decide.note), ''), receipt_no = rno,
    payment_key = pkey
  where id = c.id;
  return jsonb_build_object('ok', true, 'receipt_no', rno);
end;
$$;
revoke all on function public.pay_claim_decide(text, uuid, boolean, text)
  from public;
grant execute on function public.pay_claim_decide(text, uuid, boolean, text)
  to anon, authenticated;
