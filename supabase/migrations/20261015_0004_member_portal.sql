-- Member portal: a member checks their own dues and receipts online with
-- their member ID and the phone number the association has for them.
-- Read-only, built from the records the phones sync. Repeated wrong
-- details lock that member ID for 15 minutes.

create or replace function public.portal_statement(
  org text,
  member_no text,
  phone text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.sync_orgs;
  m jsonb;
  mid text;
  guard_key text := 'portal:' || upper(trim(member_no));
  g public.sync_sign_in_guard;
  digits text := right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9);
  joined date;
  stopped date;
  dues jsonb := '[]'::jsonb;
  t record;
  from_m date;
  until_m date;
  n_months int;
  paid bigint;
  covered int;
begin
  select * into o from public.sync_orgs where upper(slug) = upper(trim(org));
  if o.id is null then
    raise exception 'Organisation not found.' using errcode = 'P0001';
  end if;
  select * into g from public.sync_sign_in_guard
  where org_id = o.id and username = guard_key;
  if g.locked_until is not null and g.locked_until > now() then
    raise exception 'Too many tries. Please wait 15 minutes and try again.'
      using errcode = 'P0001';
  end if;

  select r.data, r.key into m, mid from public.sync_records r
  where r.org_id = o.id and r.tbl = 'members'
    and upper(r.data ->> 'member_no') = upper(trim(member_no))
    and r.data ->> 'deleted_at' is null
  limit 1;
  if m is null or length(digits) < 9 or not (
    right(regexp_replace(coalesce(m ->> 'phone', ''), '\D', '', 'g'), 9) = digits
    or right(regexp_replace(coalesce(m ->> 'whatsapp', ''), '\D', '', 'g'), 9) = digits
  ) then
    insert into public.sync_sign_in_guard as x (org_id, username, failures)
    values (o.id, guard_key, 1)
    on conflict (org_id, username) do update
      set failures = case when x.failures + 1 >= 5 then 0 else x.failures + 1 end,
          locked_until = case when x.failures + 1 >= 5
                              then now() + interval '15 minutes' end;
    -- Returned rather than raised, so the failed try is kept.
    return jsonb_build_object('error',
      'Member ID and phone number do not match our records.');
  end if;
  update public.sync_sign_in_guard set failures = 0, locked_until = null
  where org_id = o.id and username = guard_key;

  joined := left(m ->> 'date_joined', 10)::date;
  if m ->> 'status' <> 'active' and m ->> 'status_date' is not null then
    stopped := left(m ->> 'status_date', 10)::date;
  end if;

  -- Monthly dues, same rules as the app (lib/domain/dues.dart).
  for t in
    select r.key as id, r.data ->> 'name' as name,
      (r.data ->> 'amount')::bigint as amount,
      left(r.data ->> 'start_date', 10)::date as start_date,
      left(r.data ->> 'end_date', 10)::date as end_date
    from public.sync_records r
    where r.org_id = o.id and r.tbl = 'contribution_types'
      and r.data ->> 'frequency' = 'monthly'
      and (r.data ->> 'amount') is not null
      and (r.data ->> 'is_active')::int = 1
      and (r.data ->> 'applies_to_all')::int = 1
      and r.data ->> 'deleted_at' is null
  loop
    from_m := date_trunc('month', greatest(joined, coalesce(t.start_date, joined)));
    until_m := date_trunc('month', least(current_date,
      coalesce(t.end_date, current_date), coalesce(stopped, current_date)));
    n_months := case when until_m < from_m then 0 else
      (extract(year from until_m) - extract(year from from_m)) * 12
      + extract(month from until_m) - extract(month from from_m) + 1 end;
    select coalesce(sum((p.data ->> 'amount')::bigint), 0) into paid
    from public.sync_records p
    where p.org_id = o.id and p.tbl = 'payments'
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
    'org', o.name,
    'member', jsonb_build_object(
      'name', m ->> 'full_name',
      'member_no', m ->> 'member_no',
      'status', m ->> 'status',
      'joined', joined,
      'zones', (
        select coalesce(jsonb_agg(z.data ->> 'name' order by (z.data ->> 'code')::int), '[]')
        from public.sync_records mz
        join public.sync_records z on z.org_id = o.id and z.tbl = 'zones'
          and z.key = mz.data ->> 'zone_id'
        where mz.org_id = o.id and mz.tbl = 'member_zones'
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
        left join public.sync_records ct on ct.org_id = o.id
          and ct.tbl = 'contribution_types'
          and ct.key = p.data ->> 'contribution_type_id'
        where p.org_id = o.id and p.tbl = 'payments'
          and p.data ->> 'member_id' = mid and p.data ->> 'status' = 'valid'
        order by p.data ->> 'paid_on' desc
        limit 100
      ) s
    ),
    'updated', (select max(r.updated_at) from public.sync_records r
                where r.org_id = o.id)
  );
end;
$$;

revoke all on function public.portal_statement(text, text, text) from public;
grant execute on function public.portal_statement(text, text, text)
  to anon, authenticated;
