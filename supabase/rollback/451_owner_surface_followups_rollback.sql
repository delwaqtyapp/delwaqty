-- 451 rollback: drops ONLY the 451 signatures. The 449 zero-arg
-- get_my_merchant_profile is kept byte-identical (md5-pinned before and
-- after). Never touches 449 objects, views, policies or grants.

BEGIN;

-- preconditions: 451 is applied and the 449 zero-arg profile is intact
DO $$
BEGIN
  ASSERT md5(pg_get_functiondef('public.get_my_merchant_profile()'::regprocedure))
         = '93a34d4eba42dddd85c5af26b1c5c8bb',
    '451 rollback: the 449 zero-arg get_my_merchant_profile drifted';
  ASSERT to_regprocedure('public.get_my_merchant_profile(uuid)') IS NOT NULL,
    '451 rollback: overload missing (451 not applied?)';
  ASSERT to_regprocedure('public.get_my_products_count(uuid)') IS NOT NULL,
    '451 rollback: get_my_products_count missing (451 not applied?)';
  ASSERT to_regprocedure('public.get_my_products_by_ids(uuid,uuid[])') IS NOT NULL,
    '451 rollback: get_my_products_by_ids missing (451 not applied?)';
  ASSERT to_regprocedure('public.admin_get_merchants_count()') IS NOT NULL,
    '451 rollback: admin_get_merchants_count missing (451 not applied?)';
END $$;

DROP FUNCTION public.get_my_merchant_profile(uuid);
DROP FUNCTION public.get_my_products_count(uuid);
DROP FUNCTION public.get_my_products_by_ids(uuid, uuid[]);
DROP FUNCTION public.admin_get_merchants_count();

-- postconditions: only the zero-arg 449 profile remains, byte-identical
DO $$
BEGIN
  ASSERT md5(pg_get_functiondef('public.get_my_merchant_profile()'::regprocedure))
         = '93a34d4eba42dddd85c5af26b1c5c8bb',
    '451 rollback: damaged the 449 zero-arg get_my_merchant_profile';
  ASSERT to_regprocedure('public.get_my_merchant_profile(uuid)') IS NULL,
    '451 rollback: overload survived';
  ASSERT to_regprocedure('public.get_my_products_count(uuid)') IS NULL,
    '451 rollback: get_my_products_count survived';
  ASSERT to_regprocedure('public.get_my_products_by_ids(uuid,uuid[])') IS NULL,
    '451 rollback: get_my_products_by_ids survived';
  ASSERT to_regprocedure('public.admin_get_merchants_count()') IS NULL,
    '451 rollback: admin_get_merchants_count survived';
END $$;

COMMIT;
