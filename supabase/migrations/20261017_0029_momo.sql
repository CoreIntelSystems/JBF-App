-- Pay by MTN Mobile Money inside the app. The edge function `momo` asks MTN
-- (Collection API, request to pay) for the member's approval on their
-- phone; when MTN says the payment succeeded, momo_finish writes the
-- receipt with no treasurer step. These functions are for that edge
-- function only (service role): members never call them directly, so the
-- app cannot claim a payment MTN did not confirm.

create table if not exists public.momo_payments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.sync_orgs (id),
  member_key text not null,
  request_id uuid not null references public.pay_requests (id),
  amount bigint not null check (amount > 0),
  phone text not null,
  status text not null default 'pending'
    check (status in ('pending', 'successful', 'failed')),
  reason text,
  financial_id text,
  receipt_no text,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create index if not exists momo_payments_member
  on public.momo_payments (org_id, member_key, created_at desc);
alter table public.momo_payments enable row level security;
revoke all on public.momo_payments from anon, authenticated;

-- A member starts a payment: checks who they are, finds or makes the
-- standing request for what they pay, and records a pending payment.
create or replace function public.momo_prepare(
  token text, type_id text, period text, amount bigint, phone text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
  mkey text := me ->> 'member';
  r jsonb := public.pay_self_request(token, type_id, period);
  st text := r -> 'mine' ->> 'status';
  least_amount bigint := (r ->> 'minimum')::bigint;
  digits text := regexp_replace(coalesce(phone, ''), '\D', '', 'g');
  p public.momo_payments;
begin
  if st in ('pending', 'confirmed') then
    raise exception 'You have already paid or reported this one.'
      using errcode = 'P0001';
  end if;
  if amount is null or amount <= 0 or amount > 100000000 then
    raise exception 'Enter the amount you are paying.' using errcode = 'P0001';
  end if;
  if least_amount is not null and amount < least_amount then
    raise exception 'The least you can pay for this is GHS %. Enter that or more.',
      to_char(least_amount / 100.0, 'FM999999990.00') using errcode = 'P0001';
  end if;
  if digits ~ '^0\d{9}$' then
    digits := '233' || substring(digits from 2);
  end if;
  if digits !~ '^233\d{9}$' then
    raise exception 'Enter your MTN Mobile Money number, for example 024 123 4567.'
      using errcode = 'P0001';
  end if;
  if exists (select 1 from public.momo_payments x
             where x.org_id = org and x.member_key = mkey
               and x.request_id = (r ->> 'id')::uuid
               and x.status = 'pending'
               and x.created_at > now() - interval '10 minutes') then
    raise exception 'A payment is already waiting for your approval on your phone.'
      using errcode = 'P0001';
  end if;
  insert into public.momo_payments (org_id, member_key, request_id, amount, phone)
  values (org, mkey, (r ->> 'id')::uuid, amount, digits)
  returning * into p;
  return jsonb_build_object('id', p.id, 'amount', p.amount, 'phone', p.phone,
    'title', r ->> 'title');
end;
$$;
revoke all on function public.momo_prepare(text, text, text, bigint, text)
  from public, anon, authenticated;
grant execute on function public.momo_prepare(text, text, text, bigint, text)
  to service_role;

-- The member's own payment, for the status check. Includes the amount and
-- phone MTN must report back.
create or replace function public.momo_get(token text, pid uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  p public.momo_payments;
begin
  select * into p from public.momo_payments x
  where x.id = pid and x.org_id = (me ->> 'org')::uuid
    and x.member_key = me ->> 'member';
  if p.id is null then
    raise exception 'No such payment.' using errcode = 'P0001';
  end if;
  return jsonb_build_object('id', p.id, 'status', p.status, 'reason', p.reason,
    'amount', p.amount, 'phone', p.phone, 'receipt_no', p.receipt_no,
    'created_at', p.created_at);
end;
$$;
revoke all on function public.momo_get(text, uuid)
  from public, anon, authenticated;
grant execute on function public.momo_get(text, uuid) to service_role;

-- The same, without a member token: for the MTN callback, which carries
-- only the payment id (and is re-checked with MTN before anything is done).
create or replace function public.momo_row(pid uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', p.id, 'status', p.status, 'amount', p.amount,
    'phone', p.phone, 'receipt_no', p.receipt_no, 'created_at', p.created_at)
  from public.momo_payments p where p.id = pid
$$;
revoke all on function public.momo_row(uuid) from public, anon, authenticated;
grant execute on function public.momo_row(uuid) to service_role;

-- MTN answered. ok = the payment succeeded: write the confirmed report and
-- the receipt; otherwise mark it failed. Safe to call again.
create or replace function public.momo_finish(
  pid uuid, ok boolean, financial_id text default null,
  reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.momo_payments;
  r public.pay_requests;
  t jsonb;
  m jsonb;
  c public.pay_claims;
  n int;
  rno text;
  pkey text := gen_random_uuid()::text;
  stamp text := to_char(now() at time zone 'utc',
    'YYYY-MM-DD"T"HH24:MI:SS.MS "+00:00"');
  rule text;
begin
  select * into p from public.momo_payments x where x.id = pid for update;
  if p.id is null then
    raise exception 'No such payment.' using errcode = 'P0001';
  end if;
  if p.status <> 'pending' then
    return jsonb_build_object('status', p.status, 'receipt_no', p.receipt_no,
      'reason', p.reason);
  end if;
  if not ok then
    update public.momo_payments set status = 'failed',
      reason = left(coalesce(momo_finish.reason, 'The payment was not approved.'), 300),
      finished_at = now()
    where id = p.id;
    return jsonb_build_object('status', 'failed',
      'reason', coalesce(momo_finish.reason, 'The payment was not approved.'));
  end if;

  select * into r from public.pay_requests x where x.id = p.request_id;
  select x.data into t from public.sync_records x
  where x.org_id = p.org_id and x.tbl = 'contribution_types' and x.key = r.type_id;
  perform pg_advisory_xact_lock(hashtext('pay_receipt:' || p.org_id::text));
  select coalesce(max(substring(x.receipt_no from '(\d+)$')::int), 0) + 1
    into n
  from public.pay_claims x
  where x.org_id = p.org_id and x.receipt_no like
    'ONL-' || to_char(current_date, 'YYYY') || '-%';
  rno := 'ONL-' || to_char(current_date, 'YYYY') || '-' || lpad(n::text, 6, '0');

  insert into public.sync_records (org_id, tbl, key, data, updated_at)
  values (p.org_id, 'payments', pkey, jsonb_build_object(
    'id', pkey, 'receipt_no', rno, 'member_id', p.member_key,
    'contribution_type_id', r.type_id,
    'period', case when t ->> 'frequency' = 'monthly' then r.period end,
    'amount', p.amount, 'method', 'momo',
    'reference', coalesce(momo_finish.financial_id, p.id::text),
    'paid_on', to_char(current_date, 'YYYY-MM-DD') || 'T12:00:00.000 +00:00',
    'collected_by', null, 'collector_name', 'MTN MoMo (in the app)',
    'remarks', left('Paid by MTN MoMo: ' || r.title, 200),
    'status', 'valid', 'event_id', null,
    'created_at', stamp, 'updated_at', stamp, 'created_by', null,
    'device_id', null, 'deleted_at', null), now());

  begin
    insert into public.pay_claims (org_id, request_id, member_key, amount,
      method, reference, paid_on, note, status, decided_at, decision_note,
      receipt_no, payment_key)
    values (p.org_id, p.request_id, p.member_key, p.amount, 'momo',
      coalesce(momo_finish.financial_id, p.id::text), current_date,
      'Paid by MTN MoMo in the app', 'confirmed', now(),
      'Confirmed by MTN automatically', rno, pkey)
    returning * into c;
  exception when unique_violation then
    -- The member had already reported this one by hand: the money is real,
    -- so keep the receipt and leave the earlier report for the treasurer.
    null;
  end;

  select x.data into m from public.sync_records x
  where x.org_id = p.org_id and x.tbl = 'members' and x.key = p.member_key;
  rule := coalesce(t ->> 'welfare_rule', 'none');
  if rule in ('dues', 'contribution')
     and coalesce(m ->> 'welfare_membership', 'none') = 'none' then
    perform public.welfare_set(p.org_id, p.member_key, jsonb_build_object(
      'welfare_membership', 'member',
      'welfare_since', to_char(
        least(current_date, coalesce((r.period || '-01')::date, current_date)),
        'YYYY-MM-DD') || 'T12:00:00.000 +00:00',
      'welfare_ended_on', null, 'welfare_note', null));
  end if;

  update public.momo_payments set status = 'successful',
    financial_id = momo_finish.financial_id, receipt_no = rno,
    finished_at = now()
  where id = p.id;
  return jsonb_build_object('status', 'successful', 'receipt_no', rno);
end;
$$;
revoke all on function public.momo_finish(uuid, boolean, text, text)
  from public, anon, authenticated;
grant execute on function public.momo_finish(uuid, boolean, text, text)
  to service_role;
