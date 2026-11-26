-- Suite for migration 449 (customer surface hardening, phase 2a).
-- Applied by supabase/harness/449_harness.sh AFTER 439..449 + 449_seed.sql
-- on a throwaway clone of h435_template. Synthetic fixtures only.
-- DISPOSABLE-DB-ONLY.
--
-- Covers the NEW surface only (the equal-behavior battery covers the
-- re-pointed policies):
--   1. views: shape, owner, security_barrier, active-only, no sensitive
--      columns, anon+authenticated SELECT, nothing but SELECT.
--   2. get_my_merchant_profile: owner gets full row (incl. email/
--      owner_user_id), stranger gets NULL, anon is refused.
--   3. get_my_products: owner and active staff read full rows (barcode/
--      stock included), stranger refused, anon refused.
--   4. admin RPCs: non-admin gets empty, anon refused, seeded admin
--      positive (contact row incl. email/phone, products list), 100-id cap.
--   5. owner-update guard: owner changes name OK; status / delivery_fee /
--      owner_user_id / email / type rejected.
--   6. DML trims + sweep: no authenticated INSERT/DELETE/TRUNCATE on
--      merchants, no anon grants on merchant_profiles, owner upsert on
--      merchant_profiles still works, sweep counts zero.
--   7. campaigns trigger new body md5 + creator flip still works.
--   8. base-table SELECT untouched in 449 (revokes are 450): anon
--      wildcard reads of merchants/products still work.

BEGIN;

-- ─── 1. views ─────────────────────────────────────────────────────────
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM information_schema.columns
          WHERE table_schema='public' AND table_name='merchants_public') = 21;
  ASSERT (SELECT count(*) FROM information_schema.columns
          WHERE table_schema='public' AND table_name='products_public') = 16;
  ASSERT (SELECT c.reloptions::text FROM pg_class c
          WHERE c.oid='public.merchants_public'::regclass) LIKE '%security_barrier=true%';
  ASSERT (SELECT c.reloptions::text FROM pg_class c
          WHERE c.oid='public.products_public'::regclass) LIKE '%security_barrier=true%';
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
          WHERE table_schema='public' AND table_name IN ('merchants_public','products_public')
            AND grantee IN ('anon','authenticated') AND privilege_type <> 'SELECT'),
    'view grants beyond SELECT';
END $$;

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true) \g /dev/null
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.merchants_public
          WHERE id = (select shop from zz449)) = 1, 'active merchant missing from view';
  ASSERT (SELECT count(*) FROM public.merchants_public
          WHERE id = (select shop_suspended from zz449)) = 0, 'suspended merchant in view';
  ASSERT (SELECT count(*) FROM public.products_public
          WHERE merchant_id = (select shop_suspended from zz449)) = 0, 'suspended shop products in view';
  ASSERT (SELECT count(*) FROM public.products_public
          WHERE id = (select product1 from zz449)) = 1, 'active product missing from view';
END $$;
RESET ROLE;

-- ─── 2. get_my_merchant_profile ───────────────────────────────────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select owner from zz449))::text, true) \g /dev/null
DO $$
DECLARE v jsonb;
BEGIN
  v := public.get_my_merchant_profile();
  ASSERT v IS NOT NULL, 'owner profile null';
  ASSERT v->>'id' = (select shop from zz449)::text, 'wrong merchant row';
  ASSERT (v ? 'email') AND (v ? 'owner_user_id'), 'owner row incomplete';
END $$;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  ASSERT public.get_my_merchant_profile() IS NULL, 'stranger got a merchant profile';
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true) \g /dev/null
DO $$
BEGIN
  PERFORM public.get_my_merchant_profile();
  RAISE EXCEPTION 'zz449 sentinel: anon got merchant profile';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'not authenticated' OR SQLSTATE = '42501',
    'wrong error: ' || SQLERRM || '/' || SQLSTATE;
END $$;
RESET ROLE;

-- ─── 3. get_my_products ───────────────────────────────────────────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select owner from zz449))::text, true) \g /dev/null
DO $$
DECLARE v record;
BEGIN
  SELECT * INTO v FROM public.get_my_products((select shop from zz449)) LIMIT 1;
  ASSERT v.id = (select product1 from zz449), 'owner product missing';
  ASSERT v.barcode = '6224490001' AND v.stock_quantity = 7 AND v.sku = 'ZZ449SKU',
    'owner row missing ops columns';
END $$;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select cashier from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.get_my_products((select shop from zz449))) = 1,
    'active staff cannot read shop products';
END $$;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  PERFORM public.get_my_products((select shop from zz449));
  RAISE EXCEPTION 'zz449 sentinel: stranger read products';
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'not authorized', 'wrong error: ' || SQLERRM;
END $$;
RESET ROLE;

-- ─── 4. admin RPCs ────────────────────────────────────────────────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.admin_get_merchant_contacts(ARRAY[(select shop from zz449)])) = 0,
    'non-admin got merchant contacts';
  ASSERT (SELECT count(*) FROM public.admin_get_merchant_products((select shop from zz449))) = 0,
    'non-admin got merchant products';
END $$;
-- positive: the seeded platform-owner admin passes the gate, sees the
-- contact row incl. email/phone, and the products list
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select admin_user from zz449))::text, true) \g /dev/null
DO $$
DECLARE v record;
BEGIN
  SELECT * INTO v FROM public.admin_get_merchant_contacts(ARRAY[(select shop from zz449)]);
  ASSERT v.id = (select shop from zz449), 'admin contact row missing';
  ASSERT v.email IS NOT NULL AND v.phone IS NOT NULL, 'admin contact row incomplete';
  ASSERT (SELECT count(*) FROM public.admin_get_merchant_products((select shop from zz449))) = 1,
    'admin product read failed';
END $$;
-- cap: 101 ids rejected
DO $$
BEGIN
  PERFORM public.admin_get_merchant_contacts(ARRAY(SELECT gen_random_uuid() FROM generate_series(1, 101)));
  RAISE EXCEPTION 'zz449 sentinel: cap not enforced';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'merchant id list too long', 'wrong error: ' || SQLERRM;
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true) \g /dev/null
DO $$
BEGIN
  PERFORM public.admin_get_merchant_contacts(ARRAY[(select shop from zz449)]);
  RAISE EXCEPTION 'zz449 sentinel: anon used admin RPC';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'not authenticated' OR SQLSTATE = '42501', 'wrong error: ' || SQLERRM || '/' || SQLSTATE;
END $$;
RESET ROLE;

-- ─── 5. owner-update guard ────────────────────────────────────────────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select owner from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  UPDATE public.merchants SET name = 'zz449-cafe-renamed' WHERE id = (select shop from zz449);
  UPDATE public.merchants SET is_open = false, phone = '01000000449' WHERE id = (select shop from zz449);
END $$;
DO $$
BEGIN
  UPDATE public.merchants SET status = 'active' WHERE id = (select shop_suspended from zz449);
  RAISE EXCEPTION 'zz449 sentinel: owner set status';
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'status is managed by the admin RPCs', 'wrong error: ' || SQLERRM;
END $$;
DO $$
BEGIN
  UPDATE public.merchants SET delivery_fee = 0 WHERE id = (select shop from zz449);
  RAISE EXCEPTION 'zz449 sentinel: owner set fee';
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'delivery_fee is managed by the admin RPCs', 'wrong error: ' || SQLERRM;
END $$;
DO $$
BEGIN
  UPDATE public.merchants SET owner_user_id = (select customer from zz449) WHERE id = (select shop from zz449);
  RAISE EXCEPTION 'zz449 sentinel: owner transferred ownership';
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'owner_user_id is immutable', 'wrong error: ' || SQLERRM;
END $$;
DO $$
BEGIN
  UPDATE public.merchants SET email = 'zz449-new@example.test' WHERE id = (select shop from zz449);
  RAISE EXCEPTION 'zz449 sentinel: owner set email';
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'email is managed by the admin RPCs', 'wrong error: ' || SQLERRM;
END $$;
DO $$
BEGIN
  UPDATE public.merchants SET type = 'restaurant' WHERE id = (select shop from zz449);
  RAISE EXCEPTION 'zz449 sentinel: owner set type';
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'zz449 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'type is managed by the admin RPCs', 'wrong error: ' || SQLERRM;
END $$;
RESET ROLE;

-- ─── 6. trims + sweep + merchant_profiles ─────────────────────────────
DO $$
BEGIN
  ASSERT NOT has_table_privilege('authenticated', 'public.merchants', 'INSERT');
  ASSERT NOT has_table_privilege('authenticated', 'public.merchants', 'DELETE');
  ASSERT NOT has_table_privilege('authenticated', 'public.merchants', 'TRUNCATE');
  ASSERT has_table_privilege('authenticated', 'public.merchants', 'UPDATE');
  ASSERT has_table_privilege('authenticated', 'public.merchants', 'SELECT'),
    '449 must not touch base-table SELECT (that is 450)';
  ASSERT NOT has_table_privilege('anon', 'public.merchant_profiles', 'SELECT');
  ASSERT NOT has_table_privilege('anon', 'public.merchant_profiles', 'REFERENCES');
  ASSERT NOT has_table_privilege('authenticated', 'public.merchant_profiles', 'TRUNCATE');
  ASSERT NOT has_table_privilege('authenticated', 'public.merchant_profiles', 'TRIGGER');
  ASSERT NOT has_table_privilege('authenticated', 'public.merchant_profiles', 'REFERENCES');
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
          WHERE table_schema='public' AND grantee='anon'
            AND privilege_type IN ('REFERENCES','TRIGGER'));
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.role_table_grants
          WHERE table_schema='public' AND grantee='authenticated'
            AND privilege_type='TRUNCATE');
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select owner from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  INSERT INTO public.merchant_profiles(merchant_id, user_id)
  VALUES ((select shop from zz449), (select owner from zz449))
  ON CONFLICT (merchant_id) DO UPDATE SET updated_at = now();
END $$;
RESET ROLE;

-- ─── 7. campaigns trigger post-image + creator flip ───────────────────
DO $$
BEGIN
  ASSERT md5(pg_get_functiondef('public.campaigns_guard_status_change()'::regprocedure))
         = 'e8b5b249f50311c28eea712a7de69714', 'campaigns trigger post-image drifted';
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select owner from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  UPDATE public.campaigns SET status = 'pending_review' WHERE id = (select campaign1 from zz449);
END $$;
RESET ROLE;

-- ─── 8. 449 is non-breaking: base-table reads untouched ───────────────
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true) \g /dev/null
DO $$
BEGIN
  PERFORM m.* FROM public.merchants m LIMIT 1;
  PERFORM p.* FROM public.products p LIMIT 1;
END $$;
RESET ROLE;

DO $$ BEGIN RAISE NOTICE '449 suite OK'; END $$;

ROLLBACK;
