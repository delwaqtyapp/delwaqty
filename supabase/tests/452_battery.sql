-- 452 equal-behavior battery: run by harness/452_harness.sh on BOTH the
-- pre DB (439..451) and the post DB (439..451+452) AFTER
-- tests/449_seed.sql + tests/452_seed.sql. The two outputs are diffed;
-- they must be IDENTICAL (452 must not change any read or write path
-- the shipped build uses).
--
-- Two layers of proof per probe:
--   * read probes print one 'label|result' line in a fixed order and
--     the pre/post outputs are diffed;
--   * write probes ASSERT their expected outcome (affected-row count
--     for expected successes; the exact pinned SQLSTATE for expected
--     failures) instead of only printing, so a both-sides-broken path
--     fails the battery loudly instead of passing the diff.
--
-- This is the 449 battery re-expressed over the post-452 surfaces: the
-- four direct base-table SELECT probes of 449 (anon/customer/cashier
-- products, which 452 intentionally revokes) are swapped for the view /
-- RPC reads the app switched to in #80. owner.merchant_vischeck and
-- owner.edge_vischeck stay DIRECT id-only reads on purpose: they are
-- the keep-list probes (the merchant-staff-admin edge function's exact
-- visibility query; its HTTP layer cannot run in this lab, its only
-- table dependency can). The deliveries probes cover the rebuilt
-- security_invoker view as driver/customer/owner/admin/regional-admin.
-- NOT simulatable here (documented, verified by enumeration instead):
-- real PostgREST HTTP (no PostgREST in this lab) and the POS client
-- (reads only via SECURITY DEFINER cashier_* / drug_catalog_search
-- RPCs, which 452 does not touch).
--
-- Personas from zz449 + zz452: owner / cashier / customer / customer2
-- (driver user) / provider_user / admin_user (country admin) /
-- regional_admin. Runs in one transaction, rolled back at the end.

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
-- the deliveries view (customer sees own delivery ride, with labels)
SELECT 'customer.deliveries|' || count(*) FROM public.deliveries;
SELECT 'customer.delivery_label|' || merchant_name || '|' || merchant_address || '|' || status
  FROM public.deliveries WHERE id = (select ride_customer from zz452);

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
-- keep-list probes: DIRECT id-only reads must work in both postures
SELECT 'owner.merchant_vischeck|'|| count(*) FROM public.merchants m WHERE m.id = (select shop from zz449);
-- the merchant-staff-admin edge function's exact visibility query
SELECT 'owner.edge_vischeck|'   || count(*) FROM (SELECT id FROM public.merchants WHERE id = (select shop from zz449)) t;
-- #80 owner surfaces
SELECT 'owner.my_profile|'      || (get_my_merchant_profile()->>'name');
SELECT 'owner.my_products|'     || count(*) FROM get_my_products((select shop from zz449));
SELECT 'owner.my_products_count|'|| get_my_products_count((select shop from zz449));
SELECT 'owner.my_by_ids|'       || count(*) FROM get_my_products_by_ids((select shop from zz449), array[(select product1 from zz449)]);
-- owners hold no rides read policy: unchanged empty deliveries read
SELECT 'owner.deliveries|'      || count(*) FROM public.deliveries;

DO $$
DECLARE n int;
BEGIN
  INSERT INTO public.branches(id, merchant_id, name, is_primary)
  VALUES (gen_random_uuid(), (select shop from zz449), 'zz449-b2', false);
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'owner.branch_insert affected ' || n || ' rows';
  RAISE NOTICE 'owner.branch_insert|ok';
END $$;
DO $$
DECLARE n int;
BEGIN
  INSERT INTO public.product_modifier_groups(id, product_id, name)
  VALUES (gen_random_uuid(), (select product1 from zz449), 'zz449-extra');
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'owner.mgroup_insert affected ' || n || ' rows';
  RAISE NOTICE 'owner.mgroup_insert|ok';
END $$;
DO $$
DECLARE n int;
BEGIN
  INSERT INTO public.product_modifier_options(id, group_id, name, price_adjustment)
  VALUES (gen_random_uuid(), (select mgroup1 from zz449), 'zz449-xlarge', 20);
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'owner.moption_insert affected ' || n || ' rows';
  RAISE NOTICE 'owner.moption_insert|ok';
END $$;
DO $$
DECLARE n int;
BEGIN
  UPDATE public.merchant_staff_settings
     SET settings = '{"cashier_custom_lines": false}'::jsonb
   WHERE merchant_id = (select shop from zz449);
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'owner.staff_settings_update affected ' || n || ' rows';
  RAISE NOTICE 'owner.staff_settings_update|ok';
END $$;
-- the app's owner write path on products (stock sync / edit / delete all
-- filter .eq('id', ...), which the products.id keep-list covers)
DO $$
DECLARE n int;
BEGIN
  UPDATE public.products SET stock_quantity = 6, is_available = true
   WHERE id = (select product1 from zz449);
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'owner.product_update affected ' || n || ' rows';
  RAISE NOTICE 'owner.product_update|ok';
END $$;
DO $$
DECLARE n int;
BEGIN
  DELETE FROM public.products WHERE id = (select product2 from zz449);
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'owner.product_delete affected ' || n || ' rows';
  RAISE NOTICE 'owner.product_delete|ok';
END $$;
-- direct owner UPDATEs on campaigns are RLS-filtered to 0 rows in
-- BOTH postures (campaigns admin update policy: country admin only;
-- the app goes through the campaign_* RPC gates, 361). Pinned at the
-- real outcome so a silently broken write path cannot pass the diff.
DO $$
DECLARE n int;
BEGIN
  UPDATE public.campaigns SET status = 'pending_review' WHERE id = (select campaign1 from zz449);
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'owner.campaign_submit matched ' || n || ' rows (RLS posture changed)';
  RAISE NOTICE 'owner.campaign_submit|rls_filtered';
END $$;
DO $$
DECLARE n int;
BEGIN
  UPDATE public.campaigns SET status = 'approved' WHERE id = (select campaign1 from zz449);
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'owner.campaign_selfapprove matched ' || n || ' rows (RLS posture changed)';
  RAISE NOTICE 'owner.campaign_selfapprove|rls_filtered';
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
-- expected FAILURE: the direct-write guard fires in BOTH postures
-- (reaching it proves the re-pointed policy subquery evaluated)
DO $$
BEGIN
  UPDATE public.service_bookings SET status = 'accepted'
   WHERE id = (select booking1 from zz449);
  RAISE EXCEPTION 'provider.booking_update unexpectedly SUCCEEDED' USING ERRCODE = 'ZZ452';
EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE = 'ZZ452' THEN RAISE; END IF;
  ASSERT SQLSTATE = 'P0001',
    'provider.booking_update failed with unexpected SQLSTATE ' || SQLSTATE;
  RAISE NOTICE 'provider.booking_update|%', SQLSTATE;
END $$;

-- ─── driver user (customer2) ──────────────────────────────────────────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer2 from zz449))::text, true) \g /dev/null
SELECT 'driver.tracking|'    || count(*) FROM public.order_tracking;
SELECT 'driver.locations|'   || count(*) FROM public.driver_locations;
SELECT 'driver.obligations|' || count(*) FROM public.driver_obligations;
-- the deliveries view (driver sees the assigned delivery ride, labels
-- resolved through the definer labels subview)
SELECT 'driver.deliveries|'  || count(*) FROM public.deliveries;
SELECT 'driver.delivery_label|' || merchant_name || '|' || merchant_address || '|' || status
  FROM public.deliveries WHERE id = (select ride_driver from zz452);
-- #285: the suspended cafe's delivery row is visible to the assigned
-- driver, but its label must stay BLANK (mirrors the old caller-side
-- merchants RLS on the join)
SELECT 'driver.delivery_suspended_label|' || merchant_name || '|' || merchant_address
  FROM public.deliveries WHERE id = (select ride_suspended from zz452);
-- #285: requested-driver positive - a searching ride requested to this
-- driver is visible with its (active) merchant label
SELECT 'driver.delivery_requested_label|' || merchant_name || '|' || merchant_address
  FROM public.deliveries WHERE id = (select ride_requested from zz452);

-- ─── admin_user (country admin): the app's admin write path ──────────
-- (updateMerchantStatus filters .eq('id', ...), covered by the
-- merchants.id keep-list) + the deliveries view as a rides admin ──────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select admin_user from zz449))::text, true) \g /dev/null
SELECT 'admin.merchant_count|' || admin_get_merchants_count();
SELECT 'admin.deliveries|'     || count(*) FROM public.deliveries;
SELECT 'admin.delivery_label|' || merchant_name || '|' || merchant_address
  FROM public.deliveries WHERE id = (select ride_driver from zz452);
DO $$
DECLARE n int;
BEGIN
  UPDATE public.merchants SET status = 'active', updated_at = now()
   WHERE id = (select shop from zz449);
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'admin.merchant_status_update affected ' || n || ' rows';
  RAISE NOTICE 'admin.merchant_status_update|ok';
END $$;

-- ─── regional_admin: region-scoped definer reads; no rides policy ────
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select regional_admin from zz452))::text, true) \g /dev/null
SELECT 'regional_admin.merchant_count|' || admin_get_merchants_count();
SELECT 'regional_admin.list_merchants|' || count(*) FROM admin_list_merchants();
SELECT 'regional_admin.deliveries|'     || count(*) FROM public.deliveries;

-- ─── driver2: an UNREQUESTED second driver sees no deliveries ────────
-- (#285 requested-driver negative)
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select driver2_user from zz452))::text, true) \g /dev/null
SELECT 'driver2.deliveries|'           || count(*) FROM public.deliveries;
SELECT 'driver2.delivery_requested|'   || count(*) FROM public.deliveries
  WHERE id = (select ride_requested from zz452);

RESET ROLE;
ROLLBACK;
