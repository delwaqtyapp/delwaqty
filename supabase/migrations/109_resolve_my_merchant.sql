-- ============================================================
-- 109_resolve_my_merchant.sql
-- The provider app passes `auth.uid()` down as `merchant_id`, but the
-- merchants table is keyed by `merchants.id` and linked to the owner
-- through `merchants.owner_user_id`. Those are different values, so
-- every merchant-scoped query (`products`, `orders`, `product_inventory`,
-- `offers`, `branches`, `reservations`, stats) filtered on a uuid that
-- can never match a merchants.id.
--
-- The seeded merchants all have owner_user_id = NULL, so a plain
-- "select the merchant where owner_user_id = auth.uid()" is not enough
-- either. This function resolves the caller's merchant server-side:
--   1. the merchant they own, if any;
--   2. otherwise the single seeded merchant in a demo/dev database
--      (more than one -> NULL, so it never silently picks the wrong
--      store).
--
-- Every provider query can now call this instead of guessing.
-- ============================================================

CREATE OR REPLACE FUNCTION public.resolve_my_merchant()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_owned uuid;
  v_seeded uuid;
  v_seeded_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. A merchant this user actually owns.
  SELECT id INTO v_owned
    FROM public.merchants
   WHERE owner_user_id = v_uid
   ORDER BY created_at
   LIMIT 1;

  IF v_owned IS NOT NULL THEN
    RETURN v_owned;
  END IF;

  -- 2. Demo database fallback: the un-owned (seeded) merchant, but only
  --    when it is unambiguous.
  SELECT count(*) INTO v_seeded_count
    FROM public.merchants
   WHERE owner_user_id IS NULL;

  IF v_seeded_count = 1 THEN
    SELECT id INTO v_seeded
      FROM public.merchants
     WHERE owner_user_id IS NULL
     LIMIT 1;
    RETURN v_seeded;
  END IF;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_my_merchant() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_my_merchant() TO authenticated;

COMMENT ON FUNCTION public.resolve_my_merchant() IS
  'The merchants.id of the calling merchant, resolved server-side. '
  'Never pass auth.uid() as merchant_id: it is a different value.';