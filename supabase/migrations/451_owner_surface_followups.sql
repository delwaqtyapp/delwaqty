-- 451: owner-surface follow-ups for the PR #80 app switch (review
-- findings #279/#280), ADDITIVE ONLY. Applies to prod on merge, ahead of
-- the HELD 450 revocations.
--
--   1. get_my_merchant_profile(p_merchant_id uuid): an OVERLOAD of the
--      449 zero-arg function. A caller that already resolved its ACTIVE
--      merchant (resolve_my_merchant) reads THAT store instead of the
--      first-created one (multi-business owners). The zero-arg function
--      is untouched; PostgREST routes parameterized calls to the
--      overload and parameterless calls to the original.
--   2. get_my_products_count(p_merchant_id uuid): exact count without
--      downloading private rows (a rows.length client count is capped
--      by PostgREST max_rows and ships the whole catalog).
--   3. get_my_products_by_ids(p_merchant_id uuid, p_product_ids uuid[]):
--      bounded fetch for client-side joins (stock inventory page), so
--      the join never assumes one RPC page holds the whole catalog.
--
-- All three keep the 449 gates verbatim: owner-or-active-staff for
-- products, own-row-only for the merchant profile, authenticated-only
-- EXECUTE, PUBLIC/anon revoked.
--
-- A0 PRECONDITIONS (prod-verified 2026-11-26 via Management API,
-- identical to the deterministic lab chain build):
--   * get_my_merchant_profile() body md5 = 93a34d4eba42dddd85c5af26b1c5c8bb
--   * get_my_products(uuid)      body md5 = a22571561696459d78af4b54a486613f

BEGIN;

-- ─── A0: preconditions ─────────────────────────────────────────────────
DO $$
BEGIN
  ASSERT md5(pg_get_functiondef('public.get_my_merchant_profile()'::regprocedure))
         = '93a34d4eba42dddd85c5af26b1c5c8bb',
    'A0: get_my_merchant_profile drifted from the 449 body';
  ASSERT md5(pg_get_functiondef('public.get_my_products(uuid)'::regprocedure))
         = 'a22571561696459d78af4b54a486613f',
    'A0: get_my_products drifted from the 449 body';
END $$;

-- ─── 1. merchant profile for a caller-resolved active store ────────────
CREATE FUNCTION public.get_my_merchant_profile(p_merchant_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row public.merchants%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_merchant_id IS NULL THEN
    RETURN NULL;
  END IF;
  -- Own rows only (incl. the legacy id = uid keying): never another
  -- user's merchant, however the caller obtained the id.
  SELECT * INTO v_row FROM public.merchants
   WHERE id = p_merchant_id
     AND (owner_user_id = auth.uid() OR id = auth.uid());
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  RETURN to_jsonb(v_row);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_my_merchant_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_merchant_profile(uuid) TO authenticated;

-- ─── 2. exact product count, no row download ───────────────────────────
CREATE FUNCTION public.get_my_products_count(p_merchant_id uuid)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  -- Gate identical to get_my_products (449): owner or active staff.
  IF p_merchant_id IS NULL
     OR NOT (public._is_merchant_owner_only(p_merchant_id)
             OR public.is_active_staff(p_merchant_id)) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN (SELECT count(*) FROM public.products pr
          WHERE pr.merchant_id = p_merchant_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_my_products_count(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_products_count(uuid) TO authenticated;

-- ─── 3. bounded product fetch for client-side joins ────────────────────
CREATE FUNCTION public.get_my_products_by_ids(p_merchant_id uuid, p_product_ids uuid[])
RETURNS SETOF public.products
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  -- Gate identical to get_my_products (449): owner or active staff.
  IF p_merchant_id IS NULL
     OR NOT (public._is_merchant_owner_only(p_merchant_id)
             OR public.is_active_staff(p_merchant_id)) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF p_product_ids IS NULL OR cardinality(p_product_ids) > 1000 THEN
    RAISE EXCEPTION 'product id list too long';
  END IF;
  RETURN QUERY
  SELECT pr.* FROM public.products pr
   WHERE pr.merchant_id = p_merchant_id
     AND pr.id = ANY(p_product_ids)
   ORDER BY pr.created_at DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_my_products_by_ids(uuid, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_products_by_ids(uuid, uuid[]) TO authenticated;

-- ─── postconditions ────────────────────────────────────────────────────
DO $$
BEGIN
  -- the three new/extended surfaces exist with the expected signatures
  ASSERT (SELECT count(*) FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public' AND p.proname = 'get_my_merchant_profile')
         = 2, '451: expected zero-arg + uuid get_my_merchant_profile overloads';
  ASSERT to_regprocedure('public.get_my_products_count(uuid)') IS NOT NULL,
    '451: get_my_products_count missing';
  ASSERT to_regprocedure('public.get_my_products_by_ids(uuid,uuid[])') IS NOT NULL,
    '451: get_my_products_by_ids missing';
  -- no PUBLIC EXECUTE on any of them (PUBLIC grantee = oid 0; a NULL
  -- proacl means the default PUBLIC grant, which must not survive)
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    CROSS JOIN LATERAL aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))) x
    WHERE n.nspname = 'public'
      AND p.proname IN ('get_my_merchant_profile',
                        'get_my_products_count',
                        'get_my_products_by_ids')
      AND x.grantee = 0),
    '451: PUBLIC EXECUTE leaked onto an owner-surface function';
END $$;

COMMIT;
