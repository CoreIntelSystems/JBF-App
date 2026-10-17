-- Welfare is by choice. A member is "none" (not in welfare), "member" or
-- "disqualified". The state lives in the member's record
-- (members.welfare_membership / welfare_since / welfare_ended_on /
-- welfare_note, schema v13 on phones), so it syncs like any other detail.
--
-- * A member joins and leaves from the member page (welfare_join,
--   welfare_leave), or by paying welfare dues or a welfare contribution
--   (confirming the payment enrols them).
-- * Monthly welfare dues (contribution type with welfare_rule = 'dues') are
--   owed only by welfare members, from the month they joined.
-- * Welfare contributions (welfare_rule = 'contribution') have no fixed
--   amount, but may have a minimum (minimum_amount).
-- * Missing three payments in a row, for dues (three finished months) or for
--   welfare contribution requests (three finished rounds), disqualifies the
--   member. An officer reinstates them from the app.

-- The welfare fields change one member's record the way sync does.
create or replace function public.welfare_set(org uuid, mkey text, patch jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  stamp text := to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS')
    || ' +00:00';
begin
  update public.sync_records r
  set data = r.data || patch || jsonb_build_object('updated_at', stamp),
      updated_at = now(), pushed_by = null
  where r.org_id = org and r.tbl = 'members' and r.key = mkey;
end;
$$;
revoke all on function public.welfare_set(uuid, text, jsonb)
  from public, anon, authenticated;

create or replace function public.welfare_stamp()
returns text
language sql
stable
set search_path = ''
as $$
  select to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS')
    || ' +00:00'
$$;
revoke all on function public.welfare_stamp() from public, anon, authenticated;

-- ---- The monthly figures --------------------------------------------------

-- The statement, now with welfare in mind: welfare dues are owed from the day
-- the member joined welfare until they leave or are disqualified, and not at
-- all by members who never joined.
create or replace function public.member_statement(org uuid, mid text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m jsonb;
  joined date;
  stopped date;
  dues jsonb := '[]'::jsonb;
  t record;
  from_m date;
  until_m date;
  n_months int;
  paid bigint;
  covered int;
  w_since date;
  w_end date;
  j date;
  s date;
begin
  select r.data into m from public.sync_records r
  where r.org_id = org and r.tbl = 'members' and r.key = mid;
  joined := left(m ->> 'date_joined', 10)::date;
  if m ->> 'status' <> 'active' and m ->> 'status_date' is not null then
    stopped := left(m ->> 'status_date', 10)::date;
  end if;
  w_since := left(m ->> 'welfare_since', 10)::date;
  w_end := left(m ->> 'welfare_ended_on', 10)::date;

  -- Monthly dues, same rules as the app (lib/domain/dues.dart).
  for t in
    select r.key as id, r.data ->> 'name' as name,
      (r.data ->> 'amount')::bigint as amount,
      left(r.data ->> 'start_date', 10)::date as start_date,
      left(r.data ->> 'end_date', 10)::date as end_date,
      coalesce(r.data ->> 'welfare_rule', 'none') as rule
    from public.sync_records r
    where r.org_id = org and r.tbl = 'contribution_types'
      and r.data ->> 'frequency' = 'monthly'
      and (r.data ->> 'amount') is not null
      and (r.data ->> 'is_active')::int = 1
      and (r.data ->> 'applies_to_all')::int = 1
      and r.data ->> 'deleted_at' is null
  loop
    j := joined;
    s := stopped;
    if t.rule = 'dues' then
      if w_since is null then
        -- Welfare is by choice: nothing is owed by those who did not join.
        continue;
      end if;
      j := w_since;
      s := case when s is null then w_end else least(s, coalesce(w_end, s)) end;
    end if;
    from_m := date_trunc('month', greatest(j, coalesce(t.start_date, j)));
    until_m := date_trunc('month', least(current_date,
      coalesce(t.end_date, current_date), coalesce(s, current_date)));
    n_months := case when until_m < from_m then 0 else
      (extract(year from until_m) - extract(year from from_m)) * 12
      + extract(month from until_m) - extract(month from from_m) + 1 end;
    select coalesce(sum((p.data ->> 'amount')::bigint), 0) into paid
    from public.sync_records p
    where p.org_id = org and p.tbl = 'payments'
      and p.data ->> 'member_id' = mid
      and p.data ->> 'contribution_type_id' = t.id
      and p.data ->> 'status' = 'valid';
    covered := least(n_months, (paid / greatest(t.amount, 1))::int);
    dues := dues || jsonb_build_object(
      'name', t.name,
      'monthly', t.amount,
      'months', n_months,
      'expected', t.amount * n_months,
      'paid', paid,
      'outstanding', greatest(t.amount * n_months - paid, 0),
      'months_behind', n_months - covered,
      'next_unpaid', case when covered < n_months
        then to_char(from_m + make_interval(months => covered), 'YYYY-MM') end
    );
  end loop;

  return jsonb_build_object(
    'org', (select name from public.sync_orgs where id = org),
    'member', jsonb_build_object(
      'name', m ->> 'full_name',
      'member_no', m ->> 'member_no',
      'status', m ->> 'status',
      'joined', joined,
      'zones', (
        select coalesce(jsonb_agg(z.data ->> 'name' order by (z.data ->> 'code')::int), '[]')
        from public.sync_records mz
        join public.sync_records z on z.org_id = org and z.tbl = 'zones'
          and z.key = mz.data ->> 'zone_id'
        where mz.org_id = org and mz.tbl = 'member_zones'
          and mz.data ->> 'member_id' = mid and mz.data ->> 'deleted_at' is null
      )
    ),
    'dues', dues,
    'payments', (
      select coalesce(jsonb_agg(x order by x ->> 'paid_on' desc), '[]')
      from (
        select jsonb_build_object(
          'receipt_no', p.data ->> 'receipt_no',
          'paid_on', left(p.data ->> 'paid_on', 10),
          'type', ct.data ->> 'name',
          'period', p.data ->> 'period',
          'amount', (p.data ->> 'amount')::bigint,
          'method', p.data ->> 'method'
        ) as x
        from public.sync_records p
        left join public.sync_records ct on ct.org_id = org
          and ct.tbl = 'contribution_types'
          and ct.key = p.data ->> 'contribution_type_id'
        where p.org_id = org and p.tbl = 'payments'
          and p.data ->> 'member_id' = mid and p.data ->> 'status' = 'valid'
        order by p.data ->> 'paid_on' desc
        limit 100
      ) s
    ),
    'updated', (select max(r.updated_at) from public.sync_records r
                where r.org_id = org)
  );
end;
$$;
revoke all on function public.member_statement(uuid, text)
  from public, anon, authenticated;

-- ---- Joining, leaving, and the three-in-a-row rule ----------------------

-- The most months of welfare dues a member is behind on, counting finished
-- months only (this month is still open).
create or replace function public.welfare_dues_behind(org uuid, mkey text)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m jsonb;
  since date;
  worst int := 0;
  t record;
  from_m date;
  until_m date;
  n int;
  paid bigint;
begin
  select r.data into m from public.sync_records r
  where r.org_id = org and r.tbl = 'members' and r.key = mkey;
  since := left(m ->> 'welfare_since', 10)::date;
  if since is null then
    return 0;
  end if;
  for t in
    select r.key as id, (r.data ->> 'amount')::bigint as amount,
      left(r.data ->> 'start_date', 10)::date as start_date,
      left(r.data ->> 'end_date', 10)::date as end_date
    from public.sync_records r
    where r.org_id = org and r.tbl = 'contribution_types'
      and r.data ->> 'welfare_rule' = 'dues'
      and (r.data ->> 'amount') is not null
      and (r.data ->> 'is_active')::int = 1
      and r.data ->> 'deleted_at' is null
  loop
    from_m := date_trunc('month', greatest(since, coalesce(t.start_date, since)));
    until_m := date_trunc('month', least(current_date,
      coalesce(t.end_date, current_date))) - interval '1 month';
    n := case when until_m < from_m then 0 else
      (extract(year from until_m) - extract(year from from_m)) * 12
      + extract(month from until_m) - extract(month from from_m) + 1 end;
    select coalesce(sum((p.data ->> 'amount')::bigint), 0) into paid
    from public.sync_records p
    where p.org_id = org and p.tbl = 'payments'
      and p.data ->> 'member_id' = mkey
      and p.data ->> 'contribution_type_id' = t.id
      and p.data ->> 'status' = 'valid';
    worst := greatest(worst, n - least(n, (paid / greatest(t.amount, 1))::int));
  end loop;
  return worst;
end;
$$;
revoke all on function public.welfare_dues_behind(uuid, text)
  from public, anon, authenticated;

-- How many finished welfare contribution requests in a row the member has
-- not paid for, counting back from the latest, since they joined welfare.
create or replace function public.welfare_rounds_missed(org uuid, mkey text)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  m jsonb;
  since timestamptz;
  missed int := 0;
  r public.pay_requests;
begin
  select x.data into m from public.sync_records x
  where x.org_id = org and x.tbl = 'members' and x.key = mkey;
  if m ->> 'welfare_since' is null then
    return 0;
  end if;
  since := left(m ->> 'welfare_since', 10)::date;
  for r in
    select q.* from public.pay_requests q
    where q.org_id = org and q.created_at >= since
      and (q.closed_at is not null or q.due_on < current_date)
      and exists (select 1 from public.sync_records t
                  where t.org_id = org and t.tbl = 'contribution_types'
                    and t.key = q.type_id
                    and t.data ->> 'welfare_rule' = 'contribution')
      and public.pay_targets(q, mkey)
    order by q.created_at desc
  loop
    exit when exists (select 1 from public.pay_claims c
                      where c.request_id = r.id and c.member_key = mkey
                        and c.status <> 'rejected');
    missed := missed + 1;
  end loop;
  return missed;
end;
$$;
revoke all on function public.welfare_rounds_missed(uuid, text)
  from public, anon, authenticated;

-- Disqualifies welfare members who missed three payments in a row, for
-- dues or for contributions. Returns how many were disqualified.
create or replace function public.welfare_evaluate(org uuid)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  k text;
  n int := 0;
  why text;
begin
  for k in
    select r.key from public.sync_records r
    where r.org_id = org and r.tbl = 'members'
      and r.data ->> 'deleted_at' is null
      and r.data ->> 'status' = 'active'
      and r.data ->> 'welfare_membership' = 'member'
  loop
    why := null;
    if public.welfare_dues_behind(org, k) >= 3 then
      why := 'Missed 3 months of welfare dues in a row.';
    elsif public.welfare_rounds_missed(org, k) >= 3 then
      why := 'Missed 3 welfare contributions in a row.';
    end if;
    if why is not null then
      perform public.welfare_set(org, k, jsonb_build_object(
        'welfare_membership', 'disqualified',
        'welfare_ended_on', public.welfare_stamp(),
        'welfare_note', why));
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.welfare_evaluate(uuid)
  from public, anon, authenticated;

create or replace function public.welfare_evaluate_all()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  o uuid;
  n int := 0;
begin
  for o in select id from public.sync_orgs loop
    n := n + public.welfare_evaluate(o);
  end loop;
  return n;
end;
$$;
revoke all on function public.welfare_evaluate_all()
  from public, anon, authenticated;

-- A member joins welfare.
create or replace function public.welfare_join(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.member_sessions := public.member_session_for(token);
  m jsonb;
begin
  select r.data into m from public.sync_records r
  where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key;
  if m is null or m ->> 'status' <> 'active' then
    raise exception 'Only active members can join welfare.'
      using errcode = 'P0001';
  end if;
  if m ->> 'welfare_membership' = 'disqualified' then
    raise exception 'You were disqualified from welfare. Please speak to the Welfare Committee to be reinstated.'
      using errcode = 'P0001';
  end if;
  if coalesce(m ->> 'welfare_membership', 'none') = 'member' then
    return jsonb_build_object('ok', true);
  end if;
  perform public.welfare_set(s.org_id, s.member_key, jsonb_build_object(
    'welfare_membership', 'member', 'welfare_since', public.welfare_stamp(),
    'welfare_ended_on', null, 'welfare_note', null));
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.welfare_join(text) from public;
grant execute on function public.welfare_join(text) to anon, authenticated;

-- A member leaves welfare. Dues stop from today.
create or replace function public.welfare_leave(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.member_sessions := public.member_session_for(token);
  m jsonb;
begin
  select r.data into m from public.sync_records r
  where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key;
  if m is null then
    raise exception 'Member not found.' using errcode = 'P0001';
  end if;
  if m ->> 'welfare_membership' = 'member' then
    perform public.welfare_set(s.org_id, s.member_key, jsonb_build_object(
      'welfare_membership', 'none', 'welfare_ended_on', public.welfare_stamp()));
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.welfare_leave(text) from public;
grant execute on function public.welfare_leave(text) to anon, authenticated;

-- Members' home: their welfare standing.
do $$
begin
  if not exists (select 1 from pg_proc p
                 join pg_namespace s on s.oid = p.pronamespace
                 where s.nspname = 'public'
                   and p.proname = 'member_home_pre_welfare') then
    alter function public.member_home(text) rename to member_home_pre_welfare;
  end if;
end;
$$;
revoke all on function public.member_home_pre_welfare(text)
  from public, anon, authenticated;

create or replace function public.member_home(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  home jsonb := public.member_home_pre_welfare(token);
  s public.member_sessions := public.member_session_for(token);
  m jsonb;
begin
  select r.data into m from public.sync_records r
  where r.org_id = s.org_id and r.tbl = 'members' and r.key = s.member_key;
  return home || jsonb_build_object('welfare_standing', jsonb_build_object(
    'status', coalesce(m ->> 'welfare_membership', 'none'),
    'since', left(m ->> 'welfare_since', 10),
    'note', m ->> 'welfare_note',
    'dues_behind', public.welfare_dues_behind(s.org_id, s.member_key),
    'rounds_missed', public.welfare_rounds_missed(s.org_id, s.member_key),
    'limit', 3));
end;
$$;
grant execute on function public.member_home(text) to anon, authenticated;

-- ---- Payment requests -----------------------------------------------------

-- Requests show the type's minimum.
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
    'minimum', (select (t.data ->> 'minimum_amount')::bigint
                from public.sync_records t
                where t.org_id = r.org_id and t.tbl = 'contribution_types'
                  and t.key = r.type_id),
    'welfare_rule', (select t.data ->> 'welfare_rule'
                     from public.sync_records t
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

-- Reporting a payment: the amount may not be under the type's minimum.
do $$
begin
  if not exists (select 1 from pg_proc p
                 join pg_namespace s on s.oid = p.pronamespace
                 where s.nspname = 'public'
                   and p.proname = 'pay_claim_submit_base') then
    alter function public.pay_claim_submit(text, uuid, bigint, text, text,
      date, text) rename to pay_claim_submit_base;
  end if;
end;
$$;
revoke all on function public.pay_claim_submit_base(text, uuid, bigint, text,
  text, date, text) from public, anon, authenticated;

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
  least_amount bigint;
begin
  select (t.data ->> 'minimum_amount')::bigint into least_amount
  from public.pay_requests r
  join public.sync_records t on t.org_id = r.org_id
    and t.tbl = 'contribution_types' and t.key = r.type_id
  where r.id = request and r.org_id = (me ->> 'org')::uuid;
  if least_amount is not null and amount is not null
     and amount < least_amount then
    raise exception 'The least you can pay for this is GHS %. Enter that or more.',
      to_char(least_amount / 100.0, 'FM999999990.00') using errcode = 'P0001';
  end if;
  return public.pay_claim_submit_base(token, request, amount, method,
    reference, paid_on, note);
end;
$$;
revoke all on function public.pay_claim_submit(text, uuid, bigint, text,
  text, date, text) from public;
grant execute on function public.pay_claim_submit(text, uuid, bigint, text,
  text, date, text) to anon, authenticated;

-- Confirming a payment of welfare dues or a welfare contribution makes the
-- member a welfare member if they were not one yet. Someone who was
-- disqualified stays so until an officer reinstates them.
do $$
begin
  if not exists (select 1 from pg_proc p
                 join pg_namespace s on s.oid = p.pronamespace
                 where s.nspname = 'public'
                   and p.proname = 'pay_claim_decide_base') then
    alter function public.pay_claim_decide(text, uuid, boolean, text)
      rename to pay_claim_decide_base;
  end if;
end;
$$;
revoke all on function public.pay_claim_decide_base(text, uuid, boolean, text)
  from public, anon, authenticated;

create or replace function public.pay_claim_decide(
  token text, claim uuid, confirm boolean, note text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  res jsonb := public.pay_claim_decide_base(token, claim, confirm, note);
  c public.pay_claims;
  r public.pay_requests;
  rule text;
  m jsonb;
begin
  if not confirm then
    return res;
  end if;
  select * into c from public.pay_claims x where x.id = claim;
  select * into r from public.pay_requests x where x.id = c.request_id;
  select t.data ->> 'welfare_rule' into rule from public.sync_records t
  where t.org_id = c.org_id and t.tbl = 'contribution_types'
    and t.key = r.type_id;
  if coalesce(rule, 'none') in ('dues', 'contribution') then
    select x.data into m from public.sync_records x
    where x.org_id = c.org_id and x.tbl = 'members' and x.key = c.member_key;
    if coalesce(m ->> 'welfare_membership', 'none') = 'none' then
      perform public.welfare_set(c.org_id, c.member_key, jsonb_build_object(
        'welfare_membership', 'member',
        'welfare_since', to_char(
          least(c.paid_on, coalesce((r.period || '-01')::date, c.paid_on)),
          'YYYY-MM-DD') || 'T12:00:00.000 +00:00',
        'welfare_ended_on', null, 'welfare_note', null));
    end if;
  end if;
  return res;
end;
$$;
revoke all on function public.pay_claim_decide(text, uuid, boolean, text)
  from public;
grant execute on function public.pay_claim_decide(text, uuid, boolean, text)
  to anon, authenticated;

-- Closing a request finishes a round, so the three-in-a-row rule is checked.
do $$
begin
  if not exists (select 1 from pg_proc p
                 join pg_namespace s on s.oid = p.pronamespace
                 where s.nspname = 'public'
                   and p.proname = 'pay_request_close_base') then
    alter function public.pay_request_close(text, uuid)
      rename to pay_request_close_base;
  end if;
end;
$$;
revoke all on function public.pay_request_close_base(text, uuid)
  from public, anon, authenticated;

create or replace function public.pay_request_close(token text, id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  res jsonb := public.pay_request_close_base(token, id);
  me jsonb := public.pay_who(token);
begin
  perform public.welfare_evaluate((me ->> 'org')::uuid);
  return res;
end;
$$;
revoke all on function public.pay_request_close(text, uuid) from public;
grant execute on function public.pay_request_close(text, uuid)
  to anon, authenticated;

-- ---- Contribution types ---------------------------------------------------

-- Monthly welfare dues belong to welfare members; a "Welfare contribution"
-- (any amount, optional minimum) is added if it is not there yet. Phones add
-- the same record with the same key.
do $$
declare
  org uuid;
  stamp text := to_char(now() at time zone 'utc',
    'YYYY-MM-DD"T"HH24:MI:SS.MS') || ' +00:00';
begin
  for org in select id from public.sync_orgs loop
    update public.sync_records r
    set data = r.data || jsonb_build_object('welfare_rule', 'dues',
          'updated_at', stamp),
        updated_at = now(), pushed_by = null
    where r.org_id = org and r.tbl = 'contribution_types'
      and r.data ->> 'name' = 'Monthly welfare dues'
      and r.data ->> 'frequency' = 'monthly'
      and coalesce(r.data ->> 'welfare_rule', 'none') = 'none';
    if not exists (select 1 from public.sync_records r
                   where r.org_id = org and r.tbl = 'contribution_types'
                     and (r.key = 'welfare-contribution'
                          or r.data ->> 'name' = 'Welfare contribution')) then
      insert into public.sync_records (org_id, tbl, key, data, updated_at)
      values (org, 'contribution_types', 'welfare-contribution',
        jsonb_build_object(
          'id', 'welfare-contribution', 'name', 'Welfare contribution',
          'category', 'welfare', 'frequency', 'open', 'amount', null,
          'start_date', null, 'end_date', null, 'is_active', 1,
          'applies_to_all', 1,
          'notes', 'Any amount from the minimum. Paying makes a member a welfare member.',
          'proposed_amount', null, 'proposed_by_name', null,
          'proposed_at', null, 'approved_by_name', null,
          'minimum_amount', null, 'welfare_rule', 'contribution',
          'created_at', stamp, 'updated_at', stamp, 'created_by', null,
          'device_id', null, 'deleted_at', null),
        now());
    end if;
  end loop;
end;
$$;

-- Every night, check who has missed three payments in a row.
select cron.schedule('jbf-welfare-check', '30 2 * * *',
  'select public.welfare_evaluate_all()');
