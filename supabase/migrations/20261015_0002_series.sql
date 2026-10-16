-- Every phone after the first numbers its records with its own series
-- (e.g. Z3), so member, receipt and voucher numbers never clash.

create or replace function public.sync_enroll(
  code text,
  device_name text,
  series text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.sync_codes;
  token text := encode(extensions.gen_random_bytes(32), 'hex');
  dev_id uuid;
  org_name text;
  clean_series text := nullif(upper(trim(coalesce(series, ''))), '');
begin
  select * into c from public.sync_codes
  where code_hash = public.sync_hash(upper(trim(code)))
  for update;
  if c.code_hash is null or c.used_at is not null or c.expires_at < now() then
    raise exception 'This code is not valid. Ask for a new one.'
      using errcode = 'P0001';
  end if;
  if coalesce(trim(device_name), '') = '' then
    raise exception 'Give this phone a name.' using errcode = 'P0001';
  end if;
  if clean_series is not null and clean_series !~ '^[A-Z0-9]{1,4}$' then
    raise exception 'Use 1 to 4 letters or numbers for the series, such as Z3.'
      using errcode = 'P0001';
  end if;
  -- Only the first phone may number records without a series.
  if clean_series is null and exists (
    select 1 from public.sync_devices d
    where d.org_id = c.org_id and d.revoked_at is null
  ) then
    raise exception 'Give this phone a number series, such as Z3.'
      using errcode = 'P0001';
  end if;
  if clean_series is not null and exists (
    select 1 from public.sync_devices d
    where d.org_id = c.org_id and d.series = clean_series
      and d.revoked_at is null
  ) then
    raise exception 'Another phone already uses the number series %.',
      clean_series using errcode = 'P0001';
  end if;
  insert into public.sync_devices (org_id, name, series, token_hash, is_admin)
  values (c.org_id, trim(device_name), clean_series, public.sync_hash(token),
    c.is_admin)
  returning id into dev_id;
  update public.sync_codes set used_at = now(), used_by = dev_id
  where code_hash = c.code_hash;
  select name into org_name from public.sync_orgs where id = c.org_id;
  return jsonb_build_object(
    'token', token,
    'device_id', dev_id,
    'org_id', c.org_id,
    'org_name', org_name,
    'is_admin', c.is_admin,
    'records', (select count(*) from public.sync_records r
                where r.org_id = c.org_id)
  );
end;
$$;

