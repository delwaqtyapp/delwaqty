-- 449 equal-behavior battery: run by the harness on BOTH the pre DB
-- (439..448) and the post DB (439..449) AFTER tests/449_seed.sql. The two
-- outputs are diffed; they must be IDENTICAL (security review: re-pointed
-- policies proven equal behavior vs old). Every probe prints one
-- 'label|result' line in a fixed order. Error probes print SQLSTATE only
-- (messages may legitimately differ in casing between builds).
--
-- Personas from zz449: owner / cashier / customer / customer2 (driver
-- user) / provider_user. Runs in one transaction, rolled back at the end.

BEGIN;

-- ─── anon (guest) ─────────────────────────────────────────────────────
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true) \g /dev/null
SELECT 'anon.products|'      || count(*) FROM public.products;
SELECT 'anon.offers|'        || count(*) FROM public.offers;
SELECT 'anon.branches|'      || count(*) FROM public.branches;
SELECT 'anon.reviews|'       || count(*) FROM public.reviews;
RESET ROLE;

-- ─── customer ─────────────────────────────────────────────────────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer from zz449))::text, true) \g /dev/null
SELECT 'customer.products|'  || count(*) FROM public.products;
SELECT 'customer.offers|'    || count(*) FROM public.offers;
SELECT 'customer.branches|'  || count(*) FROM public.branches;
SELECT 'customer.reviews|'   || count(*) FROM public.reviews;
SELECT 'customer.orders|'    || count(*) FROM public.orders;
SELECT 'customer.bookings|'  || count(*) FROM public.service_bookings;
SELECT 'customer.tracking|'  || count(*) FROM public.order_tracking;

-- ─── owner ────────────────────────────────────────────────────────────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select owner from zz449))::text, true) \g /dev/null
SELECT 'owner.orders|'          || count(*) FROM public.orders;
SELECT 'owner.reviews|'         || count(*) FROM public.reviews;
SELECT 'owner.pos_sales|'       || count(*) FROM public.pos_sales;
SELECT 'owner.staff_settings|'  || count(*) FROM public.merchant_staff_settings;
SELECT 'owner.ledger|'          || count(*) FROM public.merchant_ledger;
SELECT 'owner.payouts|'         || count(*) FROM public.merchant_payout_requests;
SELECT 'owner.obligations|'     || count(*) FROM public.driver_obligations;
SELECT 'owner.driver_locations|'|| count(*) FROM public.driver_locations;
SELECT 'owner.branches|'        || count(*) FROM public.branches;
SELECT 'owner.merchant_vischeck|'|| count(*) FROM public.merchants m WHERE m.id = (select shop from zz449);

DO $$
BEGIN
  INSERT INTO public.branches(id, merchant_id, name, is_primary)
  VALUES (gen_random_uuid(), (select shop from zz449), 'zz449-b2', false);
  RAISE NOTICE 'owner.branch_insert|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner.branch_insert|%', SQLSTATE;
END $$;
DO $$
BEGIN
  INSERT INTO public.product_modifier_groups(id, product_id, name)
  VALUES (gen_random_uuid(), (select product1 from zz449), 'zz449-extra');
  RAISE NOTICE 'owner.mgroup_insert|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner.mgroup_insert|%', SQLSTATE;
END $$;
DO $$
BEGIN
  INSERT INTO public.product_modifier_options(id, group_id, name, price_adjustment)
  VALUES (gen_random_uuid(), (select mgroup1 from zz449), 'zz449-xlarge', 20);
  RAISE NOTICE 'owner.moption_insert|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner.moption_insert|%', SQLSTATE;
END $$;
DO $$
BEGIN
  UPDATE public.merchant_staff_settings
     SET settings = '{"cashier_custom_lines": false}'::jsonb
   WHERE merchant_id = (select shop from zz449);
  RAISE NOTICE 'owner.staff_settings_update|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner.staff_settings_update|%', SQLSTATE;
END $$;
DO $$
BEGIN
  UPDATE public.campaigns SET status = 'pending_review' WHERE id = (select campaign1 from zz449);
  RAISE NOTICE 'owner.campaign_submit|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner.campaign_submit|%', SQLSTATE;
END $$;
DO $$
BEGIN
  UPDATE public.campaigns SET status = 'approved' WHERE id = (select campaign1 from zz449);
  RAISE NOTICE 'owner.campaign_selfapprove|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner.campaign_selfapprove|%', SQLSTATE;
END $$;

-- ─── cashier (active staff) ───────────────────────────────────────────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select cashier from zz449))::text, true) \g /dev/null
SELECT 'cashier.products|'   || count(*) FROM public.products;
SELECT 'cashier.orders|'     || count(*) FROM public.orders;
SELECT 'cashier.pos_sales|'  || count(*) FROM public.pos_sales;

-- ─── provider ─────────────────────────────────────────────────────────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select provider_user from zz449))::text, true) \g /dev/null
SELECT 'provider.docs|'      || count(*) FROM public.provider_documents;
SELECT 'provider.bookings|'  || count(*) FROM public.service_bookings;
DO $$
BEGIN
  UPDATE public.service_bookings SET status = 'accepted'
   WHERE id = (select booking1 from zz449);
  RAISE NOTICE 'provider.booking_update|ok';
EXCEPTION WHEN OTHERS THEN
  -- the direct-write guard fires in BOTH builds (reaching it proves the
  -- re-pointed policy subquery evaluated); compare SQLSTATE only.
  RAISE NOTICE 'provider.booking_update|%', SQLSTATE;
END $$;

-- ─── driver user (customer2) ──────────────────────────────────────────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer2 from zz449))::text, true) \g /dev/null
SELECT 'driver.tracking|'    || count(*) FROM public.order_tracking;
SELECT 'driver.locations|'   || count(*) FROM public.driver_locations;
SELECT 'driver.obligations|' || count(*) FROM public.driver_obligations;

RESET ROLE;
ROLLBACK;
