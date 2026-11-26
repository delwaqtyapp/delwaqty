-- 450 equal-behavior battery: run by harness/450_harness.sh on BOTH the
-- pre DB (439..451) and the post DB (439..451+450) AFTER
-- tests/449_seed.sql. The two outputs are diffed; they must be IDENTICAL
-- (450 must not change any read or write path the shipped build uses).
-- Every probe prints one 'label|result' line in a fixed order. Error
-- probes print SQLSTATE only.
--
-- This is the 449 battery re-expressed over the post-450 surfaces: the
-- four direct base-table SELECT probes of 449 (anon/customer/cashier
-- products, which 450 intentionally revokes) are swapped for the view /
-- RPC reads the app switched to in #80. owner.merchant_vischeck stays a
-- DIRECT read on purpose: it is the keep-list probe (merchants.id must
-- remain readable by authenticated in BOTH postures). All other probes
-- are untouched (450 revokes nothing on those tables).
--
-- Personas from zz449: owner / cashier / customer / customer2 (driver
-- user) / provider_user / admin_user. Runs in one transaction, rolled
-- back at the end.

BEGIN;

-- ─── anon (guest) ─────────────────────────────────────────────────────
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true) \g /dev/null
SELECT 'anon.products|'      || count(*) FROM public.products_public;
SELECT 'anon.merchants_pub|' || count(*) FROM public.merchants_public;
SELECT 'anon.providers|'     || count(*) FROM public.service_providers_with_effective_pricing;
SELECT 'anon.offers|'        || count(*) FROM public.offers;
SELECT 'anon.branches|'      || count(*) FROM public.branches;
SELECT 'anon.reviews|'       || count(*) FROM public.reviews;
RESET ROLE;

-- ─── customer ─────────────────────────────────────────────────────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer from zz449))::text, true) \g /dev/null
SELECT 'customer.products|'     || count(*) FROM public.products_public;
SELECT 'customer.merchants_pub|'|| count(*) FROM public.merchants_public;
SELECT 'customer.providers|'    || count(*) FROM public.service_providers_with_effective_pricing;
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
-- keep-list probe: a DIRECT id-only read must work in both postures
SELECT 'owner.merchant_vischeck|'|| count(*) FROM public.merchants m WHERE m.id = (select shop from zz449);
-- #80 owner surfaces
SELECT 'owner.my_profile|'      || (get_my_merchant_profile()->>'name');
SELECT 'owner.my_products|'     || count(*) FROM get_my_products((select shop from zz449));
SELECT 'owner.my_products_count|'|| get_my_products_count((select shop from zz449));
SELECT 'owner.my_by_ids|'       || count(*) FROM get_my_products_by_ids((select shop from zz449), array[(select product1 from zz449)]);

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
-- the app's owner write path on products (stock sync / edit / delete all
-- filter .eq('id', ...), which the products.id keep-list covers)
DO $$
BEGIN
  UPDATE public.products SET stock_quantity = 6, is_available = true
   WHERE id = (select product1 from zz449);
  RAISE NOTICE 'owner.product_update|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner.product_update|%', SQLSTATE;
END $$;
DO $$
BEGIN
  DELETE FROM public.products WHERE id = (select product2 from zz449);
  RAISE NOTICE 'owner.product_delete|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner.product_delete|%', SQLSTATE;
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
SELECT 'cashier.products|'   || count(*) FROM get_my_products((select shop from zz449));
SELECT 'cashier.orders|'     || count(*) FROM public.orders;
SELECT 'cashier.pos_sales|'  || count(*) FROM public.pos_sales;

-- ─── provider ─────────────────────────────────────────────────────────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select provider_user from zz449))::text, true) \g /dev/null
SELECT 'provider.my_profile|' || (get_my_provider_profile()->>'name');
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

-- ─── admin_user (the app's admin write path: updateMerchantStatus ─────
-- filters .eq('id', ...), covered by the merchants.id keep-list) ──────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select admin_user from zz449))::text, true) \g /dev/null
SELECT 'admin.merchant_count|' || admin_get_merchants_count();
DO $$
BEGIN
  UPDATE public.merchants SET status = 'active', updated_at = now()
   WHERE id = (select shop from zz449);
  RAISE NOTICE 'admin.merchant_status_update|ok';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'admin.merchant_status_update|%', SQLSTATE;
END $$;

RESET ROLE;
ROLLBACK;
