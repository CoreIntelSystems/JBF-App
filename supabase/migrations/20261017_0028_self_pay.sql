-- Members pay on their own: no request is needed. The member picks what
-- they are paying (monthly dues, a welfare contribution, ...), pays the
-- Treasury's Mobile Money number and tells the app the transaction ID. It
-- is the same report a payment request takes, so the Treasurer confirms it
-- the same way and it becomes a normal receipt.
--
-- Behind the scenes each (contribution type, month) gets one standing
-- request (self_key) that only shows to a member once they have reported on
-- it. The Treasury's Mobile Money number is kept once for the whole
-- organization (sync_orgs.pay_to).

alter table public.pay_requests add column if not exists self_key text;
create unique index if not exists pay_requests_self
  on public.pay_requests (org_id, self_key) where self_key is not null;
alter table public.sync_orgs add column if not exists pay_to text;

-- Members only see requests that were asked of them, and their own
-- standing ones once they have reported a payment on it.
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
      and (r.self_key is null or exists (
        select 1 from public.pay_claims c
        where c.request_id = r.id and c.member_key = mkey
          and c.created_at > now() - interval '30 days'))
      and public.pay_targets(r, mkey));
end;
$$;
revoke all on function public.pay_requests_mine(text) from public;
grant execute on function public.pay_requests_mine(text) to anon, authenticated;

-- What a member can pay on their own, and where to send the money.
create or replace function public.pay_self_options(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
begin
  return jsonb_build_object(
    'pay_to', (select o.pay_to from public.sync_orgs o where o.id = org),
    'can_set_pay_to', (me ->> 'can_confirm')::boolean,
    'types', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.key, 'name', t.data ->> 'name',
        'frequency', t.data ->> 'frequency',
        'amount', (t.data ->> 'amount')::bigint,
        'minimum', (t.data ->> 'minimum_amount')::bigint)
        order by t.data ->> 'name'), '[]')
      from public.sync_records t
      where t.org_id = org and t.tbl = 'contribution_types'
        and t.data ->> 'deleted_at' is null
        and coalesce((t.data ->> 'is_active')::int, 1) = 1));
end;
$$;
revoke all on function public.pay_self_options(text) from public;
grant execute on function public.pay_self_options(text) to anon, authenticated;

-- A treasurer sets the Mobile Money number members pay to.
create or replace function public.pay_to_set(token text, pay_to text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
  v text := nullif(trim(pay_to_set.pay_to), '');
begin
  if not (me ->> 'can_confirm')::boolean then
    raise exception 'Only a treasurer can set where members pay.'
      using errcode = 'P0001';
  end if;
  if v is not null and length(v) > 500 then
    raise exception 'That is too long.' using errcode = 'P0001';
  end if;
  update public.sync_orgs set pay_to = v where id = org;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.pay_to_set(text, text) from public;
grant execute on function public.pay_to_set(text, text) to anon, authenticated;

-- The standing request a member reports their own payment on. One per
-- contribution type and month; created the first time anyone needs it.
create or replace function public.pay_self_request(
  token text, type_id text, period text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me jsonb := public.pay_who(token);
  org uuid := (me ->> 'org')::uuid;
  mkey text := me ->> 'member';
  t jsonb;
  p text := nullif(trim(pay_self_request.period), '');
  skey text;
  r public.pay_requests;
  pto text;
begin
  if not exists (
       select 1 from public.sync_records m
       where m.org_id = org and m.tbl = 'members' and m.key = mkey
         and m.data ->> 'deleted_at' is null
         and m.data ->> 'status' = 'active') then
    raise exception 'Only active members can pay here.' using errcode = 'P0001';
  end if;
  select x.data into t from public.sync_records x
  where x.org_id = org and x.tbl = 'contribution_types'
    and x.key = pay_self_request.type_id
    and x.data ->> 'deleted_at' is null
    and coalesce((x.data ->> 'is_active')::int, 1) = 1;
  if t is null then
    raise exception 'Choose what you are paying for.' using errcode = 'P0001';
  end if;
  if t ->> 'frequency' = 'monthly' then
    if p is null or p !~ '^\d{4}-(0[1-9]|1[0-2])$' then
      raise exception 'Choose the month you are paying for.'
        using errcode = 'P0001';
    end if;
  else
    p := null;
  end if;
  skey := pay_self_request.type_id || ':' ||
    coalesce(p, to_char(current_date, 'YYYY-MM'));
  select o.pay_to into pto from public.sync_orgs o where o.id = org;

  select * into r from public.pay_requests x
  where x.org_id = org and x.self_key = skey;
  if r.id is null then
    insert into public.pay_requests (org_id, office, title, type_id, amount,
      period, pay_to, by_key, self_key)
    values (org,
      case when coalesce(t ->> 'welfare_rule', 'none') = 'none'
        then 'treasury' else 'welfare' end,
      left((t ->> 'name') || ' (paid by members)', 200),
      pay_self_request.type_id, (t ->> 'amount')::bigint, p, pto, mkey, skey)
    on conflict (org_id, self_key) where self_key is not null do nothing
    returning * into r;
    if r.id is null then
      select * into r from public.pay_requests x
      where x.org_id = org and x.self_key = skey;
    end if;
  elsif r.closed_at is not null then
    raise exception 'Payments for this month are closed. Speak to the Treasurer.'
      using errcode = 'P0001';
  elsif r.pay_to is distinct from pto then
    update public.pay_requests set pay_to = pto where id = r.id
    returning * into r;
  end if;
  return public.pay_request_json(r) || jsonb_build_object('mine', (
    select jsonb_build_object('id', c.id, 'status', c.status,
      'amount', c.amount, 'method', c.method, 'reference', c.reference,
      'paid_on', c.paid_on, 'receipt_no', c.receipt_no,
      'decision_note', c.decision_note)
    from public.pay_claims c
    where c.request_id = r.id and c.member_key = mkey
    order by c.created_at desc limit 1));
end;
$$;
revoke all on function public.pay_self_request(text, text, text) from public;
grant execute on function public.pay_self_request(text, text, text)
  to anon, authenticated;

-- A zone treasurer also sees the standing requests of their members' own
-- payments (they are not tied to a zone; their claims are still filtered to
-- the officer's zones when listed and when confirmed).
create or replace function public.pay_in_scope(r public.pay_requests, scope jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select scope is null or r.self_key is not null or (r.zone_ids is not null
    and not exists (select 1 from jsonb_array_elements_text(r.zone_ids) z
                    where not scope ? z))
$$;

-- Fix: the renamed base functions (see 0027) still named themselves in the body,
-- which no longer resolves after the rename, so every report and decision failed.
create or replace function public.pay_claim_submit_base(
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
               and lower(trim(x.reference)) = lower(trim(pay_claim_submit_base.reference))
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
revoke all on function public.pay_claim_submit_base(text, uuid, bigint, text, text, date, text) from public, anon, authenticated;

create or replace function public.pay_claim_decide_base(
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
    if coalesce(trim(pay_claim_decide_base.note), '') = '' then
      raise exception 'Say why, so the member knows what to do.'
        using errcode = 'P0001';
    end if;
    update public.pay_claims set status = 'rejected',
      decided_by = me ->> 'member', decided_at = now(),
      decision_note = trim(pay_claim_decide_base.note)
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
    decision_note = nullif(trim(pay_claim_decide_base.note), ''), receipt_no = rno,
    payment_key = pkey
  where id = c.id;
  return jsonb_build_object('ok', true, 'receipt_no', rno);
end;
$$;
revoke all on function public.pay_claim_decide_base(text, uuid, boolean, text) from public, anon, authenticated;
