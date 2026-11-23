-- STAGING ONLY — NOT A MIGRATION. Do not run on prod.
--
-- Earlier review revisions of migration 392 (applied to staging on
-- 2026-11-22/23 via the Management API, before the order-total audit rule)
-- wrote CASH_COLLECTED audit rows for order-linked rides with the ride
-- fare instead of the collected order total. This script corrects exactly
-- those rows: the 392 revision window only, never backfill rows, and only
-- where the recorded amount disagrees with the linked order's total.
-- Prod was verified to hold zero CASH_COLLECTED rows on 2026-11-23, so
-- there is nothing to repair there and this must never be run against it.
begin;

update public.audit_log a
   set after = jsonb_set(a.after, '{amount}', to_jsonb(o.total_amount))
  from public.rides r
  join public.orders o on o.id = r.order_id
 where a.action = 'CASH_COLLECTED'
   and a.resource = 'ride'
   and a.resource_id = r.id::text
   and a.reason is distinct from 'backfill_392'
   and a.created_at >= '2026-11-22 20:00+00'
   and a.created_at <  '2026-11-24 00:00+00'
   and (a.after->>'amount')::numeric is distinct from o.total_amount;

commit;
