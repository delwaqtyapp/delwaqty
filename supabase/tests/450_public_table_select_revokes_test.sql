-- 450 suite: run by harness/450_harness.sh on the disposable
-- 439..451+450 DB AFTER tests/449_seed.sql. Personas from zz449.
-- Positive + NEGATIVE coverage of the 450 revoke posture: the keep-list
-- columns stay readable, every other direct base-table read is denied,
-- and the definer surfaces are unaffected. Runs in one transaction,
-- rolled back at the end. Expected-error probes RAISE with the distinct
-- ERRCODE 'ZZ450' (a plain RAISE EXCEPTION would be swallowed by the
-- 42501 handler being tested).

BEGIN;

-- ─── anon (guest): zero direct base-table access, views unaffected ────
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true) \g /dev/null
DO $$
BEGIN
  PERFORM count(*) FROM public.merchants;
  RAISE EXCEPTION 'anon read merchants' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM count(*) FROM public.products;
  RAISE EXCEPTION 'anon read products' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM count(*) FROM public.service_providers;
  RAISE EXCEPTION 'anon read service_providers' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
-- anon gets NO keep-list: even id-only direct reads are denied
DO $$
BEGIN
  PERFORM id FROM public.merchants LIMIT 1;
  RAISE EXCEPTION 'anon read merchants.id' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM id FROM public.products LIMIT 1;
  RAISE EXCEPTION 'anon read products.id' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
-- the customer surfaces stay up
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.merchants_public) > 0,
    'anon lost merchants_public';
  ASSERT (SELECT count(*) FROM public.products_public) > 0,
    'anon lost products_public';
  ASSERT (SELECT count(*) FROM public.service_providers_with_effective_pricing) > 0,
    'anon lost the provider view';
END $$;
RESET ROLE;

-- ─── authenticated (customer persona): keep-list works, rest denied ───
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  -- keep-list columns are readable (the app's write-path filters and the
  -- merchant-staff-admin edge visibility check depend on this)
  PERFORM id FROM public.merchants LIMIT 1;
  PERFORM id FROM public.products LIMIT 1;
END $$;
DO $$
BEGIN
  PERFORM name FROM public.merchants LIMIT 1;
  RAISE EXCEPTION 'authenticated read merchants.name' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM email FROM public.merchants LIMIT 1;
  RAISE EXCEPTION 'authenticated read merchants.email' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM owner_user_id FROM public.merchants LIMIT 1;
  RAISE EXCEPTION 'authenticated read merchants.owner_user_id' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM sku FROM public.products LIMIT 1;
  RAISE EXCEPTION 'authenticated read products.sku' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM barcode FROM public.products LIMIT 1;
  RAISE EXCEPTION 'authenticated read products.barcode' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM stock_quantity FROM public.products LIMIT 1;
  RAISE EXCEPTION 'authenticated read products.stock_quantity' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM * FROM public.products LIMIT 1;
  RAISE EXCEPTION 'authenticated read products.*' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM count(*) FROM public.service_providers;
  RAISE EXCEPTION 'authenticated read service_providers' USING ERRCODE = 'ZZ450';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
-- customer-facing reads still resolve through the surfaces
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.products_public) > 0,
    'customer lost products_public';
END $$;
RESET ROLE;

-- ─── owner: the #80 owner surfaces and the direct write path ─────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select owner from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  ASSERT (SELECT get_my_merchant_profile()->>'name') = 'zz449-cafe',
    'owner profile surface broke';
  ASSERT (SELECT count(*) FROM get_my_products((select shop from zz449))) > 0,
    'owner products surface broke';
  -- the direct update the app performs (stock sync): WHERE id only
  UPDATE public.products SET stock_quantity = 5, is_available = true
   WHERE id = (select product1 from zz449);
  ASSERT FOUND, 'owner product update matched no row';
END $$;
RESET ROLE;

-- ─── admin_user: scoped definer reads + the status write path ────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select admin_user from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  ASSERT (SELECT admin_get_merchants_count()) >= 2,
    'admin count surface broke';
  UPDATE public.merchants SET status = 'active', updated_at = now()
   WHERE id = (select shop from zz449);
  ASSERT FOUND, 'admin status update matched no row';
END $$;
RESET ROLE;

DO $$ BEGIN RAISE NOTICE '450 suite OK'; END $$;

ROLLBACK;
