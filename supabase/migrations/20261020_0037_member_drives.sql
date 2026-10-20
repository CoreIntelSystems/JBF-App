-- Collection drives on the member website (Agent PRO, 2026-10-20).
--
-- Officers start a collection for a bereaved family on a welfare case. This
-- gives every signed-in member a read-only, transparent summary: whose
-- family, the funeral details, what has been received and promised, the
-- givers (anonymous ones as "A well-wisher") and the hand-over once it is
-- approved. Voided gifts never appear. Only collections that are open, or
-- were closed or handed over in the last 90 days, are listed.

create or replace function public.member_drives(token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s public.member_sessions := public.member_session_for(token);
begin
  return coalesce((
    select jsonb_agg(d order by d ->> 'sort' desc)
    from (
      select jsonb_build_object(
        'case_no', c.data ->> 'case_no',
        'member', m.data ->> 'full_name',
        'for', c.data ->> 'beneficiary',
        'status', c.data ->> 'drive_status',
        'funeral_on', left(c.data ->> 'funeral_on', 10),
        'venue', c.data ->> 'funeral_venue',
        'contact', c.data ->> 'family_contact',
        'phone', c.data ->> 'family_phone',
        'handed_amount', (c.data ->> 'handover_amount')::bigint,
        'handed_on', left(c.data ->> 'handover_on', 10),
        'received', coalesce((
          select sum((g.data ->> 'amount')::bigint)
          from public.sync_records g
          where g.org_id = s.org_id and g.tbl = 'welfare_drive_gifts'
            and g.data ->> 'case_id' = c.key
            and g.data ->> 'deleted_at' is null
            and g.data ->> 'status' = 'received'), 0),
        'pledged', coalesce((
          select sum((g.data ->> 'amount')::bigint)
          from public.sync_records g
          where g.org_id = s.org_id and g.tbl = 'welfare_drive_gifts'
            and g.data ->> 'case_id' = c.key
            and g.data ->> 'deleted_at' is null
            and g.data ->> 'status' = 'pledged'), 0),
        'gifts', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', case when coalesce((g.data ->> 'anonymous')::int, 0) = 1
              then 'A well-wisher' else g.data ->> 'giver_name' end,
            'amount', (g.data ->> 'amount')::bigint,
            'pledged', g.data ->> 'status' = 'pledged')
            order by g.data ->> 'created_at')
          from public.sync_records g
          where g.org_id = s.org_id and g.tbl = 'welfare_drive_gifts'
            and g.data ->> 'case_id' = c.key
            and g.data ->> 'deleted_at' is null
            and g.data ->> 'status' in ('received', 'pledged')), '[]'),
        'sort', c.data ->> 'updated_at') as d
      from public.sync_records c
      join public.sync_records m on m.org_id = s.org_id and m.tbl = 'members'
        and m.key = c.data ->> 'member_id'
      where c.org_id = s.org_id and c.tbl = 'welfare_cases'
        and c.data ->> 'deleted_at' is null
        and c.data ->> 'drive_status' in ('open', 'closed', 'handedOver')
        and (c.data ->> 'drive_status' = 'open'
          or (c.data ->> 'updated_at')::timestamptz > now() - interval '90 days')
    ) x
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.member_drives(text) from public;
grant execute on function public.member_drives(text) to anon, authenticated;
