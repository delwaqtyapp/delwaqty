-- 451 suite: run by harness/451_harness.sh on the disposable 439..451 DB
-- AFTER tests/449_seed.sql. Personas from zz449: owner, cashier (active
-- staff), customer (stranger), admin_user (users.role = 'owner', an
-- active admin). Positive + NEGATIVE coverage of every 451 signature:
-- owner / staff / other-user / anon. Runs in one transaction, rolled
-- back at the end.

BEGIN;
-- superuser setup inside the rolled-back transaction: a merchant owned by
-- the customer persona (a stranger's store), and the superuser-computed
-- expected scoped count for admin_user (mirrors admin_list_merchants
-- scope, computed here so the RPC result is compared against an
-- independent evaluation, not its own predicate re-run by itself).
INSERT INTO public.merchants(id, owner_user_id, name, type, status)
VALUES (gen_random_uuid(), (select customer from zz449), 'zz451-other',
        'restaurant', 'active');
CREATE TEMP TABLE zz451_expected AS
SELECT (SELECT count(*) FROM public.products
         WHERE merchant_id = (SELECT shop FROM zz449)) AS shop_products_count,
       (SELECT id FROM public.merchants WHERE name = 'zz451-other') AS other_id,
       (SELECT count(*) FROM public.merchants m
        WHERE public._is_country_admin_uid((select admin_user from zz449))
           OR public.is_admin_for_region(
                public._ops_scope_region(
                  public._merchant_region_id(m.id)))) AS admin_cnt;
GRANT SELECT ON zz451_expected TO authenticated, anon;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select owner from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  -- owner positives
  ASSERT (SELECT get_my_merchant_profile()->>'id')
         = (SELECT shop::text FROM zz449), 'zero-arg profile changed';
  ASSERT (SELECT get_my_merchant_profile((SELECT shop FROM zz449))->>'id')
         = (SELECT shop::text FROM zz449), 'owner param profile mismatch';
  ASSERT (SELECT get_my_products_count((SELECT shop FROM zz449)))
         = (SELECT shop_products_count FROM zz451_expected), 'owner count wrong';
  ASSERT (SELECT count(*) FROM get_my_products_by_ids(
           (SELECT shop FROM zz449), array[(SELECT product1 FROM zz449)]))
         = 1, 'owner by_ids wrong';
  -- owner negative: a stranger-owned merchant id returns NULL, never the row
  ASSERT (SELECT get_my_merchant_profile(
           (SELECT other_id FROM zz451_expected)))
         IS NULL, 'param profile leaked a stranger merchant';
END $$;

-- staff (active cashier): products surfaces allowed, profile is not theirs
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select cashier from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  ASSERT (SELECT get_my_products_count((SELECT shop FROM zz449)))
         = (SELECT shop_products_count FROM zz451_expected), 'staff count wrong';
  ASSERT (SELECT count(*) FROM get_my_products_by_ids(
           (SELECT shop FROM zz449), array[(SELECT product1 FROM zz449)]))
         = 1, 'staff by_ids wrong';
  ASSERT (SELECT get_my_merchant_profile((SELECT shop FROM zz449)))
         IS NULL, 'staff received a merchant profile';
END $$;

-- other user (customer persona): everything refused or NULL
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select customer from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  PERFORM get_my_products_count((SELECT shop FROM zz449));
  RAISE EXCEPTION 'customer got get_my_products_count' USING ERRCODE = 'ZZ451';
EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM get_my_products_by_ids((SELECT shop FROM zz449),
                                 array[(SELECT product1 FROM zz449)]);
  RAISE EXCEPTION 'customer got get_my_products_by_ids' USING ERRCODE = 'ZZ451';
EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;
END $$;
DO $$
BEGIN
  ASSERT (SELECT get_my_merchant_profile((SELECT shop FROM zz449)))
         IS NULL, 'customer received a merchant profile';
  -- their own store DOES resolve (customer owns zz451-other): ownership
  -- is by row, not by persona label
  ASSERT (SELECT get_my_merchant_profile(
           (SELECT other_id FROM zz451_expected))->>'name')
         = 'zz451-other', 'owner of a store cannot read it back';
END $$;
DO $$
BEGIN
  PERFORM admin_get_merchants_count();
  RAISE EXCEPTION 'customer got admin_get_merchants_count' USING ERRCODE = 'ZZ451';
EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;
END $$;

-- admin_user: exact scoped count equals the superuser-computed expectation
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (select admin_user from zz449))::text, true) \g /dev/null
DO $$
BEGIN
  ASSERT (SELECT admin_get_merchants_count())
         = (SELECT admin_cnt FROM zz451_expected),
    'admin_get_merchants_count differs from the scoped expectation';
END $$;

-- anon: EXECUTE revoked, everything 42501
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true) \g /dev/null
DO $$
BEGIN
  PERFORM get_my_merchant_profile((SELECT shop FROM zz449));
  RAISE EXCEPTION 'anon got get_my_merchant_profile(uuid)' USING ERRCODE = 'ZZ451';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM get_my_products_count((SELECT shop FROM zz449));
  RAISE EXCEPTION 'anon got get_my_products_count' USING ERRCODE = 'ZZ451';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM get_my_products_by_ids((SELECT shop FROM zz449),
                                 array[(SELECT product1 FROM zz449)]);
  RAISE EXCEPTION 'anon got get_my_products_by_ids' USING ERRCODE = 'ZZ451';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;
DO $$
BEGIN
  PERFORM admin_get_merchants_count();
  RAISE EXCEPTION 'anon got admin_get_merchants_count' USING ERRCODE = 'ZZ451';
EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
END $$;

ROLLBACK;
