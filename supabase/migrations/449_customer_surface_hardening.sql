-- 449: DB hardening phase 2a — customer surface, NON-BREAKING half.
--
-- This is the additive half of the staged 448/449/450 plan:
--   448 (applied): staff_settings move, anon DML sweep, provider view.
--   449 (this file): public views + owner/staff/admin RPCs + definer
--     helpers, every cross-table policy subquery on merchants/products/
--     service_providers re-pointed onto those helpers, merchants
--     owner-update guard, DML trims, merchant_profiles hygiene, the
--     global REFERENCES/TRIGGER/TRUNCATE sweep, and the guarded PostGIS
--     residual attempt. NOTHING in this file removes a read any shipped
--     build relies on: merchants/products/service_providers base-table
--     SELECT stays exactly as-is. It applies to prod on merge.
--   450 (separate file, HELD): the table SELECT revokes + column
--     keep-lists. Applies only after a build carrying the app switch
--     (view/RPC reads) has shipped. Until 450 lands, the Finding 2
--     exposures (merchants email/owner_user_id/phone/coords to
--     anon+signed-in, products sku/barcode/stock to signed-in) stay OPEN
--     and must be reported as open.
--
-- WHY THE RE-POINTS FIRST: RLS policy subqueries on OTHER tables run as
-- the caller, so those callers need privileges on the referenced columns
-- (verified empirically on PG17: a same-table policy expression needs no
-- caller grant, but a subquery FROM another table does). After every
-- such subquery is re-pointed onto a SECURITY DEFINER helper, no caller
-- needs ANY merchants/products/service_providers column privilege for
-- policy evaluation, and 450 can revoke table SELECT with no keep-list
-- except merchants.id (one edge-function visibility check).
--
-- A0 PRECONDITIONS (prod-verified 2026-11-26):
--   * campaigns_guard_status_change body md5 =
--     'ffa5f17cde22ef4767785429d1db4d90' (362 body; chain == prod).
--   * the 22 policies re-pointed below exist with the shapes quoted in
--     the rollback file (prod pg_policies spot-checked 2026-11-26).
--   * merchant INSERT happens only through definer paths
--     (handle_new_user, _provision_business_target, resolve_my_merchant);
--     the only direct merchants writer in any client is the admin
--     status update. No runtime function UPDATEs merchants.rating/
--     total_reviews/total_orders (migrations grep: only 000/232/431
--     one-off data fixes), so the owner-update guard cannot strangle a
--     live flow.

BEGIN;

-- ─── A0: preconditions ─────────────────────────────────────────────────
DO $$
BEGIN
  ASSERT md5(pg_get_functiondef('public.campaigns_guard_status_change()'::regprocedure))
         = 'ffa5f17cde22ef4767785429d1db4d90',
    'A0: campaigns_guard_status_change drifted from the 362 body';
  ASSERT md5(pg_get_functiondef('public.merchants_guard_sensitive_fields()'::regprocedure))
         = '7107c3cb04bf85de221ca347479d6ca2',
    'A0: merchants_guard_sensitive_fields drifted from the live body';
  ASSERT (SELECT count(*) FROM pg_policies WHERE schemaname='public'
          AND (tablename, policyname) IN (
            ('branches','branches merchant manage'),
            ('branches','branches_view'),
            ('driver_locations','driver_locations_select'),
            ('driver_obligations','driver_obligations_read_own'),
            ('merchant_ledger','merchant_ledger_read_own'),
            ('merchant_payout_requests','merchant_payout_requests_read_own'),
            ('merchant_staff_settings','merchant_staff_settings_owner'),
            ('offers','offers_view'),
            ('order_tracking','ot_insert_participants'),
            ('order_tracking','ot_view_participants'),
            ('orders','Merchants can view orders for their merchant'),
            ('pos_sales','pos_sales_select_merchant'),
            ('product_modifier_groups','product_modifier_groups_write'),
            ('product_modifier_options','product_modifier_options_write'),
            ('products','Merchant owners can manage products'),
            ('products','Products are viewable by everyone'),
            ('provider_documents','provider docs owner rw'),
            ('reviews','Merchants can view reviews for their merchant'),
            ('reviews','Reviews are viewable by everyone'),
            ('service_bookings','Admins can manage bookings'),
            ('service_bookings','service_bookings_select_provider'),
            ('service_bookings','service_bookings_update_provider'))) = 22,
    'A0: one or more re-point target policies missing';
  -- A0: each re-point target's full definition (command, roles,
  -- permissive, USING, WITH CHECK) pinned by md5, verified identical on
  -- the deterministic chain AND prod (Management API, 2026-11-26). Any
  -- drift aborts the migration before anything changes.
  ASSERT (SELECT count(*) FROM (
            SELECT tablename, policyname,
                   md5(cmd || '|' || array_to_string(roles,',') || '|' || permissive
                       || '|' || coalesce(qual,'') || '|' || coalesce(with_check,'')) AS h
              FROM pg_policies WHERE schemaname='public'
          ) p JOIN (VALUES
            ('branches','branches merchant manage','1604bd161463a08e706efb014814eb87'),
            ('branches','branches_view','cb70d51319221b6ebd165ebc654db8dd'),
            ('driver_locations','driver_locations_select','1e49be24f12e14cb6ba313d276d45c89'),
            ('driver_obligations','driver_obligations_read_own','7df5e0fd5b91a44df8496e2f01a1d033'),
            ('merchant_ledger','merchant_ledger_read_own','97432a36e49f3bf8ec43ddb02a9a64b5'),
            ('merchant_payout_requests','merchant_payout_requests_read_own','69054a72b969a91f92bdff1321c76238'),
            ('merchant_staff_settings','merchant_staff_settings_owner','b1ea47a80f70e61522d5a2ba7eab12ce'),
            ('offers','offers_view','cb70d51319221b6ebd165ebc654db8dd'),
            ('order_tracking','ot_insert_participants','0367d0db36a257c86555536fc24bdeed'),
            ('order_tracking','ot_view_participants','248e87f8263f434ec3043ed623eb9c95'),
            ('orders','Merchants can view orders for their merchant','476d82a2481f6ab5d2de97fe7e36ba53'),
            ('pos_sales','pos_sales_select_merchant','1e13f370a7c8b41c1d01b37d3f9efd43'),
            ('product_modifier_groups','product_modifier_groups_write','ee24b63e992f34fd8f04d65bcb683930'),
            ('product_modifier_options','product_modifier_options_write','2c7fab0e76b7483c597db5320afe5a13'),
            ('products','Merchant owners can manage products','50eef4066bc16c20a5f7f169066c1438'),
            ('products','Products are viewable by everyone','cb70d51319221b6ebd165ebc654db8dd'),
            ('provider_documents','provider docs owner rw','d497c77c6f87d6189d68c808606e9c83'),
            ('reviews','Merchants can view reviews for their merchant','dcd5a551332eca38ec59b870e8155919'),
            ('reviews','Reviews are viewable by everyone','cb70d51319221b6ebd165ebc654db8dd'),
            ('service_bookings','Admins can manage bookings','4e49bc0ca78885a59baa09db49e06d08'),
            ('service_bookings','service_bookings_select_provider','a93d6abffa7cd1be390524cdb180875f'),
            ('service_bookings','service_bookings_update_provider','ba8e15222b0104b5c15d86ec4be867dc')
          ) AS e(tbl, pol, h) ON e.tbl = p.tablename AND e.pol = p.policyname AND e.h = p.h) = 22,
    'A0: one or more re-point target policies drifted from the pinned pre-image';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                     WHERE n.nspname='public' AND c.relname IN ('merchants_public','products_public')),
    'A0: public view name already taken';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                     WHERE n.nspname='public' AND p.proname IN
                     ('_merchant_is_active','_product_merchant_id','_provider_is_owner',
                      '_provider_region_id','_actor_is_seller','get_my_merchant_profile',
                      'get_my_products','admin_get_merchant_contacts',
                      'admin_get_merchant_products','_owns_merchant_row')),
    'A0: a 449 function name already exists';
  ASSERT to_regclass('public._449_revoked_grants') IS NULL,
    'A0: _449_revoked_grants already exists';
  -- Column-ACL guard (#277a): a table-level REVOKE silently strips explicit
  -- column privileges (pg_attribute.attacl) too, and the snapshot/replay
  -- covers table-level rows only. ABORT before any mutation if any explicit
  -- column grant exists for anon/authenticated in a (privilege x table)
  -- class this migration revokes at table level. The 3 PostGIS catalogs are
  -- included for every class section 7 revokes there. Prod verified
  -- 2026-11-26 via the Management API: the only anon/authenticated column
  -- grants anywhere are SELECT on merchant_staff (15) and suggestions (10)
  -- - classes 449 never revokes (SELECT revokes are 450) - and ZERO on the
  -- 3 catalogs, so prod passes with zero rows.
  ASSERT NOT EXISTS (
    SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0
                          AND NOT a.attisdropped AND a.attacl IS NOT NULL
      CROSS JOIN LATERAL aclexplode(a.attacl) x
      JOIN pg_roles g ON g.oid = x.grantee
     WHERE n.nspname = 'public'
       AND g.rolname IN ('anon','authenticated')
       AND (
            -- section 7 revokes all 7 table-level classes on the catalogs
            (c.relname IN ('geography_columns','geometry_columns','spatial_ref_sys')
             AND x.privilege_type IN ('SELECT','INSERT','UPDATE','DELETE',
                                      'TRUNCATE','REFERENCES','TRIGGER'))
            -- every table-level revoke outside the catalogs
         OR (c.relname NOT IN ('geography_columns','geometry_columns','spatial_ref_sys')
             AND (
                  (g.rolname = 'anon' AND x.privilege_type IN ('REFERENCES','TRIGGER'))
               OR (g.rolname = 'authenticated' AND x.privilege_type = 'TRUNCATE')
               OR (c.relname = 'merchants' AND g.rolname = 'authenticated'
                   AND x.privilege_type IN ('INSERT','DELETE'))
               OR (c.relname = 'merchant_profiles' AND g.rolname = 'anon')
               OR (c.relname = 'merchant_profiles' AND g.rolname = 'authenticated'
                   AND x.privilege_type IN ('TRIGGER','REFERENCES'))
             ))
       )
  ), 'A0: explicit column-level grants exist that 449 table-level revokes would strip silently - snapshot/replay is table-level only';
END $$;

-- ─── 1. definer helpers (policy re-point targets) ──────────────────────
-- Each replaces a non-definer subquery that forced every caller to hold
-- column privileges on the referenced table. All: no caller-supplied user
-- id, pinned search_path, PUBLIC/anon EXECUTE revoked, EXECUTE only where
-- the calling policy's roles need it.

-- active-merchant test used by the four public "viewable" policies.
CREATE FUNCTION public._merchant_is_active(p_merchant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.merchants m
     WHERE m.id = p_merchant_id AND m.status = 'active'
  );
$function$;
REVOKE ALL ON FUNCTION public._merchant_is_active(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._merchant_is_active(uuid) TO anon, authenticated, service_role;

-- products.merchant_id lookup for the modifier write policies (they only
-- subquery products to reach merchant_id for is_merchant_owner).
CREATE FUNCTION public._product_merchant_id(p_product_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.merchant_id FROM public.products p WHERE p.id = p_product_id;
$function$;
REVOKE ALL ON FUNCTION public._product_merchant_id(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._product_merchant_id(uuid) TO authenticated, service_role;

-- provider ownership test (service_providers.id + user_id as caller today).
CREATE FUNCTION public._provider_is_owner(p_provider_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.service_providers sp
     WHERE sp.id = p_provider_id AND sp.user_id = auth.uid()
  );
$function$;
REVOKE ALL ON FUNCTION public._provider_is_owner(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._provider_is_owner(uuid) TO anon, authenticated, service_role;

-- provider's region from its EXACT coords; the coords never leave the
-- function (callers keep no latitude/longitude privilege).
CREATE FUNCTION public._provider_region_id(p_provider_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public._point_region_id(sp.latitude, sp.longitude)
    FROM public.service_providers sp
   WHERE sp.id = p_provider_id;
$function$;
REVOKE ALL ON FUNCTION public._provider_region_id(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._provider_region_id(uuid) TO authenticated, service_role;

-- the campaigns trigger's three seller-shape EXISTS as one definer check
-- (the trigger stays an invoker; its callers keep no column privileges).
CREATE FUNCTION public._actor_is_seller()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.merchants m WHERE m.owner_user_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.merchant_profiles mp WHERE mp.user_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.service_providers sp WHERE sp.user_id = auth.uid());
$function$;
REVOKE ALL ON FUNCTION public._actor_is_seller() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._actor_is_seller() TO authenticated, service_role;

-- strict owner_user_id ownership test for the (b) re-points. The OLD
-- predicates were exactly `merchant_id IN (SELECT id FROM merchants WHERE
-- owner_user_id = auth.uid())`; re-points must be row-equal, so NO legacy
-- id = auth.uid() disjunct here (that shape stays confined to the
-- pre-existing _is_merchant_owner_only / is_merchant_owner helpers and
-- their existing call sites; the legacy-shape question is a 450/app-PR
-- product decision, not something a non-breaking hardening may widen).
CREATE FUNCTION public._owns_merchant_row(p_merchant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.merchants m
     WHERE m.id = p_merchant_id AND m.owner_user_id = auth.uid()
  );
$function$;
REVOKE ALL ON FUNCTION public._owns_merchant_row(uuid) FROM PUBLIC;
-- policy-called in TO-public policies (orders/reviews/products/branches/
-- pos_sales etc. are anon-readable), so anon evaluates it on SELECT.
GRANT EXECUTE ON FUNCTION public._owns_merchant_row(uuid) TO anon, authenticated, service_role;

-- NOTE: _is_merchant_owner_only keeps its existing call sites and ACLs
-- untouched by 449 (the (b) re-points use the strict _owns_merchant_row
-- instead, so no new anon EXECUTE is introduced anywhere).

-- ─── 2. public views (the post-450 read path) ─────────────────────────
-- security_barrier so quals cannot leak rows past the filter; owner
-- postgres; SELECT only for anon/authenticated. Row filter matches what
-- customers browse today: active merchants only (no drafts/suspended).
CREATE VIEW public.merchants_public
WITH (security_barrier = true) AS
SELECT id, name, type, status, description, logo_url, cover_url, phone,
       address, latitude, longitude, rating, total_reviews, total_orders,
       delivery_fee, min_order, delivery_time_min, is_featured, is_open,
       created_at, updated_at
  FROM public.merchants
 WHERE status = 'active';
COMMENT ON VIEW public.merchants_public IS
  '449: public merchant browse shape. Active merchants only; phone and '
  'coords are public by product decision (main agent, owner delegation, '
  '2026-11-26); no owner_user_id/email/settlement_model.';
REVOKE ALL ON public.merchants_public FROM PUBLIC;
REVOKE ALL ON public.merchants_public FROM anon, authenticated;
GRANT SELECT ON public.merchants_public TO anon, authenticated;

CREATE VIEW public.products_public
WITH (security_barrier = true) AS
SELECT p.id, p.merchant_id, p.category, p.name, p.name_ar, p.description,
       p.description_ar, p.price, p.compare_at_price, p.image_url,
       p.is_available, p.is_featured, p.sort_order, p.tags, p.created_at,
       p.updated_at
  FROM public.products p
 WHERE p.merchant_id IN (SELECT m.id FROM public.merchants m WHERE m.status = 'active');
COMMENT ON VIEW public.products_public IS
  '449: public product browse shape (guest menu, customer search). '
  'Products of active merchants only; no sku/barcode/reorder_level/'
  'stock_quantity/preset provenance. Owners read their own full rows via '
  'get_my_products; no owner branch here by design.';
REVOKE ALL ON public.products_public FROM PUBLIC;
REVOKE ALL ON public.products_public FROM anon, authenticated;
GRANT SELECT ON public.products_public TO anon, authenticated;

-- ─── 3. owner / staff / admin RPCs ──────────────────────────────────
-- (service_providers_nearby was PULLED from 449 in review: any
-- server-side distance ordering is a chosen-origin oracle surface; the
-- client keeps haversine over the 1km-grid view until 450/app adoption
-- decides otherwise.)
-- Owner reads own full merchant row (storefront, capability resolution).
-- Mirrors get_my_provider_profile (448), including the legacy id = uid
-- shape that the capability provider's or-filter relies on today.
CREATE FUNCTION public.get_my_merchant_profile()
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
  SELECT * INTO v_row FROM public.merchants
   WHERE owner_user_id = auth.uid() OR id = auth.uid()
   ORDER BY created_at LIMIT 1;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  RETURN to_jsonb(v_row);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_my_merchant_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_merchant_profile() TO authenticated;

-- Owner/staff read own full product rows (POS barcode, inventory stock,
-- product form). Staff gate matches the cashier surfaces (is_active_staff).
CREATE FUNCTION public.get_my_products(p_merchant_id uuid)
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
  IF p_merchant_id IS NULL
     OR NOT (public._is_merchant_owner_only(p_merchant_id)
             OR public.is_active_staff(p_merchant_id)) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT pr.* FROM public.products pr
   WHERE pr.merchant_id = p_merchant_id
   ORDER BY pr.created_at DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_my_products(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_products(uuid) TO authenticated;

-- Admin contact lookup for the top-merchants report (replaces per-row
-- table selects). Gate and region scope mirror admin_list_merchants.
CREATE FUNCTION public.admin_get_merchant_contacts(p_merchant_ids uuid[])
RETURNS TABLE(id uuid, name text, email text, phone text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL
     OR NOT (public._is_country_admin_uid(auth.uid())
             OR public._is_active_admin_uid(auth.uid())) THEN
    RETURN;
  END IF;
  IF p_merchant_ids IS NULL OR cardinality(p_merchant_ids) > 100 THEN
    RAISE EXCEPTION 'merchant id list too long';
  END IF;
  RETURN QUERY
  SELECT m.id, m.name, m.email, m.phone
    FROM public.merchants m
   WHERE m.id = ANY(p_merchant_ids)
     AND (public._is_country_admin_uid(auth.uid())
          OR public.is_admin_for_region(
               public._ops_scope_region(public._merchant_region_id(m.id))));
END;
$function$;
REVOKE ALL ON FUNCTION public.admin_get_merchant_contacts(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_merchant_contacts(uuid[]) TO authenticated;

-- Admin product read for content moderation (replaces the wildcard table
-- select). Same gate as admin_get_merchant_contacts.
CREATE FUNCTION public.admin_get_merchant_products(p_merchant_id uuid)
RETURNS SETOF public.products
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL
     OR NOT (public._is_country_admin_uid(auth.uid())
             OR public._is_active_admin_uid(auth.uid())) THEN
    RETURN;
  END IF;
  IF p_merchant_id IS NULL
     OR NOT (public._is_country_admin_uid(auth.uid())
             OR public.is_admin_for_region(
                  public._ops_scope_region(public._merchant_region_id(p_merchant_id)))) THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT pr.* FROM public.products pr
   WHERE pr.merchant_id = p_merchant_id
   ORDER BY pr.created_at DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.admin_get_merchant_products(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_merchant_products(uuid) TO authenticated;

-- ─── 4. policy re-points (equal behavior, definer helpers) ────────────
-- (a) the four public "viewable" policies: active-merchant subquery ->
-- _merchant_is_active. Same predicate, same rows.
ALTER POLICY branches_view ON public.branches
  USING ((public._merchant_is_active(merchant_id)) OR public.is_merchant_owner(merchant_id));
ALTER POLICY offers_view ON public.offers
  USING ((public._merchant_is_active(merchant_id)) OR public.is_merchant_owner(merchant_id));
ALTER POLICY "Products are viewable by everyone" ON public.products
  USING ((public._merchant_is_active(merchant_id)) OR public.is_merchant_owner(merchant_id));
ALTER POLICY "Reviews are viewable by everyone" ON public.reviews
  USING ((public._merchant_is_active(merchant_id)) OR public.is_merchant_owner(merchant_id));

-- (b) owner subqueries (merchants.id WHERE owner_user_id = auth.uid()) ->
-- _owns_merchant_row. STRICT equality with the old predicates: no legacy
-- id = auth.uid() disjunct is added anywhere in these 22 policies.
ALTER POLICY "branches merchant manage" ON public.branches
  USING (public._owns_merchant_row(merchant_id))
  WITH CHECK (public._owns_merchant_row(merchant_id));
ALTER POLICY "Merchants can view orders for their merchant" ON public.orders
  USING (public._owns_merchant_row(merchant_id));
ALTER POLICY "Merchants can view reviews for their merchant" ON public.reviews
  USING (public._owns_merchant_row(merchant_id));
ALTER POLICY "Merchant owners can manage products" ON public.products
  USING (public._owns_merchant_row(merchant_id));
ALTER POLICY merchant_staff_settings_owner ON public.merchant_staff_settings
  USING (public._owns_merchant_row(merchant_id))
  WITH CHECK (public._owns_merchant_row(merchant_id));
ALTER POLICY pos_sales_select_merchant ON public.pos_sales
  USING (public._owns_merchant_row(merchant_id));
ALTER POLICY driver_obligations_read_own ON public.driver_obligations
  USING ((public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(merchant_id))))
         OR (EXISTS (SELECT 1 FROM drivers d
                      WHERE d.id = driver_obligations.driver_id
                        AND d.user_id = auth.uid()))
         OR public._owns_merchant_row(merchant_id));
ALTER POLICY merchant_ledger_read_own ON public.merchant_ledger
  USING ((public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(merchant_id))))
         OR public._owns_merchant_row(merchant_id));
ALTER POLICY merchant_payout_requests_read_own ON public.merchant_payout_requests
  USING ((public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(merchant_id))))
         OR public._owns_merchant_row(merchant_id));
ALTER POLICY driver_locations_select ON public.driver_locations
  USING ((driver_id IN (SELECT drivers.id FROM drivers WHERE drivers.user_id = auth.uid()))
         OR public._is_owner_uid(auth.uid())
         OR public.admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid)
         OR (EXISTS (SELECT 1 FROM orders o
              WHERE o.driver_id = driver_locations.driver_id
                AND o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])
                AND o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])
                AND (o.user_id = auth.uid()
                     OR public._owns_merchant_row(o.merchant_id)))));
ALTER POLICY ot_insert_participants ON public.order_tracking
  WITH CHECK ((EXISTS (SELECT 1 FROM orders oa
                WHERE oa.id = order_tracking.order_id
                  AND public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(oa.merchant_id)))))
              OR (EXISTS (SELECT 1 FROM orders o
                   WHERE o.id = order_tracking.order_id
                     AND (public._owns_merchant_row(o.merchant_id)
                          OR o.driver_id IN (SELECT d.id FROM drivers d
                                              WHERE d.user_id = auth.uid())))));
ALTER POLICY ot_view_participants ON public.order_tracking
  USING ((EXISTS (SELECT 1 FROM orders oa
           WHERE oa.id = order_tracking.order_id
             AND public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(oa.merchant_id)))))
         OR (EXISTS (SELECT 1 FROM orders o
              WHERE o.id = order_tracking.order_id
                AND (o.user_id = auth.uid()
                     OR public._owns_merchant_row(o.merchant_id)
                     OR o.driver_id IN (SELECT d.id FROM drivers d
                                         WHERE d.user_id = auth.uid())))));

-- (c) modifier write policies: products subquery -> _product_merchant_id.
ALTER POLICY product_modifier_groups_write ON public.product_modifier_groups
  USING (public.is_merchant_owner(public._product_merchant_id(product_id)))
  WITH CHECK (public.is_merchant_owner(public._product_merchant_id(product_id)));
ALTER POLICY product_modifier_options_write ON public.product_modifier_options
  USING (public.is_merchant_owner(public._product_merchant_id(
           (SELECT g.product_id FROM public.product_modifier_groups g
             WHERE g.id = product_modifier_options.group_id))))
  WITH CHECK (public.is_merchant_owner(public._product_merchant_id(
           (SELECT g.product_id FROM public.product_modifier_groups g
             WHERE g.id = product_modifier_options.group_id))));

-- (d) service_providers subqueries -> _provider_is_owner/_provider_region_id.
ALTER POLICY "provider docs owner rw" ON public.provider_documents
  USING (public._provider_is_owner(provider_id))
  WITH CHECK (public._provider_is_owner(provider_id));
ALTER POLICY service_bookings_select_provider ON public.service_bookings
  USING ((user_id = auth.uid())
         OR public._provider_is_owner(provider_id)
         OR public._admin_member_scope(user_id));
ALTER POLICY service_bookings_update_provider ON public.service_bookings
  USING ((user_id = auth.uid()) OR public._provider_is_owner(provider_id))
  WITH CHECK ((user_id = auth.uid()) OR public._provider_is_owner(provider_id));
ALTER POLICY "Admins can manage bookings" ON public.service_bookings
  USING (public._admin_write_scope(public._provider_region_id(provider_id)))
  WITH CHECK (public._admin_write_scope(public._provider_region_id(provider_id)));

-- (e) campaigns trigger: the three seller EXISTS -> _actor_is_seller().
-- Only that one expression changes; the transition matrix is verbatim
-- from 362 (A0-pinned above).
CREATE OR REPLACE FUNCTION public.campaigns_guard_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    -- Lifecycle transitions are owner/country-level only, matching the
    -- campaign_* RPC gates (361). Creators keep the submit/resubmit path.
    -- 449: the three seller EXISTS moved into definer _actor_is_seller()
    -- so the invoker trigger's callers need no merchants/merchant_profiles/
    -- service_providers column privileges.
    IF auth.uid() IS NOT NULL AND NOT public._is_country_admin_uid(auth.uid()) THEN
      IF NOT (
        OLD.created_by = auth.uid()
        AND OLD.status IN ('draft','rejected')
        AND NEW.status IN ('draft','pending_review')
        AND public._actor_is_seller()
      ) THEN
        RAISE EXCEPTION 'Not authorized';
      END IF;
    END IF;
    IF NOT (OLD.status, NEW.status) IN (
      ('draft','pending_review'),('draft','cancelled'),('draft','archived'),
      ('pending_review','approved'),('pending_review','rejected'),
      ('pending_review','cancelled'),
      ('approved','scheduled'),('approved','published'),('approved','cancelled'),
      ('rejected','draft'),('rejected','archived'),
      ('scheduled','published'),('scheduled','cancelled'),
      ('published','paused'),('published','expired'),('published','archived'),
      ('paused','published'),('paused','archived'),
      ('expired','archived'),
      ('cancelled','draft'),('cancelled','archived')
    ) THEN
      RAISE EXCEPTION 'Invalid campaign status transition % -> %',
        OLD.status, NEW.status;
    END IF;
    IF NEW.status = 'published' AND NEW.published_at IS NULL THEN
      NEW.published_at := now();
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- ─── 5. merchants owner-update guard (review point 4) ──────────────────
-- trg_merchant_guard_sensitive / merchants_guard_sensitive_fields ALREADY
-- blocks non-admin anon/authenticated writes of status, owner_user_id,
-- rating, total_reviews, total_orders, delivery_fee, min_order,
-- is_featured and settlement_model. 449 extends the SAME guard with the
-- unprotected sensitive fields delivery_time_min, email and type
-- (capability surfaces key off merchant type). Bypass semantics and
-- existing error messages unchanged: non-admin anon/authenticated only;
-- admin, postgres, service_role and definer-RPC paths pass as today.
CREATE OR REPLACE FUNCTION public.merchants_guard_sensitive_fields()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public' AS $function$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    if NEW.owner_user_id is distinct from OLD.owner_user_id then
      raise exception 'owner_user_id is immutable';
    end if;
    if NEW.status is distinct from OLD.status then
      raise exception 'status is managed by the admin RPCs';
    end if;
    if NEW.rating is distinct from OLD.rating then
      raise exception 'rating is managed by the rating engine';
    end if;
    if NEW.total_reviews is distinct from OLD.total_reviews then
      raise exception 'total_reviews is managed by the rating engine';
    end if;
    if NEW.total_orders is distinct from OLD.total_orders then
      raise exception 'total_orders is managed by the order engine';
    end if;
    if NEW.delivery_fee is distinct from OLD.delivery_fee then
      raise exception 'delivery_fee is managed by the admin RPCs';
    end if;
    if NEW.min_order is distinct from OLD.min_order then
      raise exception 'min_order is managed by the admin RPCs';
    end if;
    if NEW.is_featured is distinct from OLD.is_featured then
      raise exception 'is_featured is managed by the admin RPCs';
    end if;
    if NEW.settlement_model is distinct from OLD.settlement_model then
      raise exception 'settlement_model is managed by the merchant_set_settlement_model RPC';
    end if;
    if NEW.delivery_time_min is distinct from OLD.delivery_time_min then
      raise exception 'delivery_time_min is managed by the admin RPCs';
    end if;
    if NEW.email is distinct from OLD.email then
      raise exception 'email is managed by the admin RPCs';
    end if;
    if NEW.type is distinct from OLD.type then
      raise exception 'type is managed by the admin RPCs';
    end if;
  end if;
  return NEW;
end;
$function$;
-- ACL left untouched on purpose: the pre-existing grant set (postgres,
-- authenticated, service_role) is part of the pinned pre-image, EXECUTE on
-- a trigger function gates nothing (the trigger fires regardless), and
-- keeping it makes the rollback an exact ACL restore.

-- ─── 6. grant snapshot (for an exact rollback), then DML trims, ───────
-- merchant_profiles hygiene, global sweep
-- Every grant this migration revokes is captured FIRST, with grantor and
-- grant-option, into an owner-only snapshot table. The rollback replays
-- ONLY these rows (restoring nothing when the table is absent), so the
-- rollback is the exact inverse of whatever this apply actually did on
-- THIS database - no hardcoded posture assumptions.
CREATE TABLE public._449_revoked_grants(
  tbl text NOT NULL,
  grantee text NOT NULL,
  privilege text NOT NULL,
  grantor text NOT NULL,
  grantable boolean NOT NULL
);
-- owner-only: strip the default-privilege residue and lock RLS down
REVOKE ALL ON public._449_revoked_grants FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE public._449_revoked_grants ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public._449_revoked_grants IS
  '449: pre-apply capture of every grant this migration revokes. Read only '
  'by the 449 rollback (replays these rows, then drops the table).';
-- source is pg_class.relacl + aclexplode, NOT information_schema
-- (role_table_grants only shows rows involving a currently enabled role,
-- which silently hides grants from a non-superuser migration role)
INSERT INTO public._449_revoked_grants
SELECT c.relname, g.rolname, x.privilege_type, go.rolname, x.is_grantable
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN LATERAL aclexplode(c.relacl) x
  JOIN pg_roles g ON g.oid = x.grantee
  JOIN pg_roles go ON go.oid = x.grantor
 WHERE n.nspname = 'public'
   AND c.relname <> '_449_revoked_grants'
   -- the 3 PostGIS catalogs are section 7's (guarded per-catalog blocks)
   AND c.relname NOT IN ('geography_columns','geometry_columns','spatial_ref_sys')
   AND (
        (g.rolname = 'anon' AND x.privilege_type IN ('REFERENCES','TRIGGER'))
     OR (g.rolname = 'authenticated' AND x.privilege_type = 'TRUNCATE')
     OR (c.relname = 'merchants' AND g.rolname = 'authenticated'
         AND x.privilege_type IN ('INSERT','DELETE'))
     OR (c.relname = 'merchant_profiles' AND g.rolname = 'anon')
     OR (c.relname = 'merchant_profiles' AND g.rolname = 'authenticated'
         AND x.privilege_type IN ('TRIGGER','REFERENCES'))
   );

-- merchants: no client inserts/deletes directly (provisioning is definer
-- RPCs; the only direct writer is the admin status UPDATE). Keep UPDATE.
REVOKE INSERT, DELETE, TRUNCATE ON public.merchants FROM authenticated;
-- products: owner CRUD stays (app writes directly, owner-only via RLS).
REVOKE TRUNCATE ON public.products FROM authenticated;
-- merchant_profiles: RLS already gives anon zero rows; remove the grants
-- too (hygiene), and drop authenticated DDL-class grants.
REVOKE ALL ON public.merchant_profiles FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.merchant_profiles FROM authenticated;
-- Global sweep (security review): anon holds no REFERENCES/TRIGGER and
-- authenticated no TRUNCATE anywhere in public. No client creates FKs or
-- triggers or truncates (PostgREST exposes none of these), so no legit
-- flow is affected; the suites prove the read/write paths that remain.
-- Per-table loop, NOT ON ALL TABLES: the 3 PostGIS catalogs are EXCLUDED
-- (they are section 7's; an unguarded REVOKE on a catalog the migration
-- role does not own must not be able to fail the apply). A failure on any
-- ordinary table still aborts the migration, as before.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT c.relname AS name
             FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','m')
              AND c.relname NOT IN ('geography_columns','geometry_columns','spatial_ref_sys','_449_revoked_grants')
  LOOP
    EXECUTE format('REVOKE REFERENCES, TRIGGER ON public.%I FROM anon', r.name);
    EXECUTE format('REVOKE TRUNCATE ON public.%I FROM authenticated', r.name);
  END LOOP;
END $$;

-- ─── 7. PostGIS residual (448 carry-over, guarded) + reconciliation ───
-- geography_columns/geometry_columns/spatial_ref_sys carry catalog-wide
-- grants for anon + authenticated (grantor varies by environment: prod's
-- residue is supabase_admin-granted and the catalogs are owned by
-- supabase_admin, so the migration role cannot revoke there). Per
-- catalog: first snapshot every anon/authenticated table-level row AS
-- THE MIGRATION ROLE, unguarded and BEFORE any role switch, so a
-- snapshot-insert failure is LOUD and insert permission can never
-- silently skip cleanup; then both revoke attempts (migration role, then
-- supabase_admin under SET LOCAL ROLE) plus the residual assert live
-- inside ONE guarded sub-block, because every catalog operation can fail
-- for a non-owner and none of them may abort the apply. Any failure
-- warns and leaves the residual explicitly OPEN.
-- All ACL reads use pg_class.relacl + aclexplode (visible to every role);
-- information_schema.role_table_grants hides rows not involving a
-- currently enabled role and silently misleads non-superuser appliers.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['geography_columns','geometry_columns','spatial_ref_sys'] LOOP
    IF to_regclass('public.' || t) IS NULL THEN
      CONTINUE;
    END IF;
    INSERT INTO public._449_revoked_grants
    SELECT c.relname, g.rolname, x.privilege_type, go.rolname, x.is_grantable
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(c.relacl) x
      JOIN pg_roles g ON g.oid = x.grantee
      JOIN pg_roles go ON go.oid = x.grantor
     WHERE n.nspname = 'public' AND c.relname = t
       AND g.rolname IN ('anon','authenticated')
       AND x.privilege_type IN ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER');
    BEGIN
      -- what the migration role itself can revoke (its own grants; on a
      -- superuser local build, everything)
      EXECUTE format('REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.%I FROM anon, authenticated', t);
      -- the supabase_admin-granted residue (the prod case)
      SET LOCAL ROLE supabase_admin;
      EXECUTE format('REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.%I FROM anon, authenticated', t);
      RESET ROLE;
      ASSERT NOT EXISTS (SELECT 1
              FROM pg_class c
              JOIN pg_namespace n ON n.oid = c.relnamespace
              CROSS JOIN LATERAL aclexplode(c.relacl) x
              JOIN pg_roles g ON g.oid = x.grantee
              WHERE n.nspname = 'public' AND c.relname = t
                AND g.rolname IN ('anon','authenticated')),
        'PostGIS residual still present on ' || t;
    EXCEPTION WHEN insufficient_privilege OR undefined_table OR undefined_object OR assert_failure THEN
      RESET ROLE;
      RAISE WARNING '449: PostGIS residual revoke incomplete on % (% / %); residual stays OPEN (manual supabase_admin SQL in the PR notes)', t, SQLSTATE, SQLERRM;
    END;
  END LOOP;
END $$;

-- Reconciliation: the snapshot must contain EXACTLY the rows that were
-- actually revoked, in every environment. Any row still present (a grant
-- the migration could not revoke) is deleted from the snapshot, so the
-- rollback never "restores" something that was never removed.
DELETE FROM public._449_revoked_grants g
 WHERE EXISTS (SELECT 1
                FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                CROSS JOIN LATERAL aclexplode(c.relacl) x
                JOIN pg_roles ge ON ge.oid = x.grantee
                JOIN pg_roles go ON go.oid = x.grantor
                WHERE n.nspname = 'public' AND c.relname = g.tbl
                  AND ge.rolname = g.grantee AND x.privilege_type = g.privilege
                  AND go.rolname = g.grantor);

-- ─── 8. postchecks (raise on any miss) ────────────────────────────────
DO $$
DECLARE
  v_bad text;
BEGIN
  -- views: owned by the same principal that owns the base table (the
  -- security invariant: the definer view belongs to the data-owning role;
  -- postgres on prod), security_barrier, exact column count
  ASSERT (SELECT r.rolname FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner
          WHERE c.oid='public.merchants_public'::regclass)
       = (SELECT r.rolname FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner
          WHERE c.oid='public.merchants'::regclass), 'merchants_public owner';
  ASSERT (SELECT r.rolname FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner
          WHERE c.oid='public.products_public'::regclass)
       = (SELECT r.rolname FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner
          WHERE c.oid='public.products'::regclass), 'products_public owner';
  ASSERT (SELECT c.reloptions::text FROM pg_class c WHERE c.oid='public.merchants_public'::regclass)
         LIKE '%security_barrier=true%', 'merchants_public security_barrier';
  ASSERT (SELECT c.reloptions::text FROM pg_class c WHERE c.oid='public.products_public'::regclass)
         LIKE '%security_barrier=true%', 'products_public security_barrier';
  ASSERT (SELECT count(*) FROM information_schema.columns
          WHERE table_schema='public' AND table_name='merchants_public') = 21, 'merchants_public columns';
  ASSERT (SELECT count(*) FROM information_schema.columns
          WHERE table_schema='public' AND table_name='products_public') = 16, 'products_public columns';
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name='merchants_public'
            AND column_name IN ('owner_user_id','email','settlement_model')), 'merchants_public leaks';
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name='products_public'
            AND column_name IN ('sku','barcode','reorder_level','stock_quantity',
                                'preset_source','preset_key')), 'products_public leaks';
  -- re-points landed: no policy text anywhere still subqueries the three
  -- tables as caller
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname='public'
       AND (coalesce(qual,'') ~* '(from|join)[[:space:]]+(public\.)?(merchants|service_providers|products)([[:space:]]|$|\.)'
            OR coalesce(with_check,'') ~* '(from|join)[[:space:]]+(public\.)?(merchants|service_providers|products)([[:space:]]|$|\.)')),
    'a policy still subqueries merchants/service_providers/products';
  -- sweeps
  -- the 3 PostGIS catalogs are excluded here: their grants are
  -- supabase_admin-granted on prod and owned by the guarded block above
  ASSERT NOT EXISTS (SELECT 1 FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          CROSS JOIN LATERAL aclexplode(c.relacl) x
          JOIN pg_roles g ON g.oid = x.grantee
          WHERE n.nspname='public' AND g.rolname='anon'
            AND x.privilege_type IN ('REFERENCES','TRIGGER')
            AND c.relname NOT IN ('geography_columns','geometry_columns','spatial_ref_sys')), 'anon REFERENCES/TRIGGER left';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          CROSS JOIN LATERAL aclexplode(c.relacl) x
          JOIN pg_roles g ON g.oid = x.grantee
          WHERE n.nspname='public' AND g.rolname='authenticated'
            AND x.privilege_type='TRUNCATE'
            AND c.relname NOT IN ('geography_columns','geometry_columns','spatial_ref_sys')), 'authenticated TRUNCATE left';
  -- the snapshot exists and captured the revokes
  ASSERT (SELECT count(*) FROM public._449_revoked_grants) > 0,
    'grant snapshot is empty';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          CROSS JOIN LATERAL aclexplode(c.relacl) x
          JOIN pg_roles g ON g.oid = x.grantee
          WHERE n.nspname='public' AND c.relname='merchant_profiles'
            AND g.rolname='anon'), 'merchant_profiles anon grant left';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          CROSS JOIN LATERAL aclexplode(c.relacl) x
          JOIN pg_roles g ON g.oid = x.grantee
          WHERE n.nspname='public' AND c.relname='merchants'
            AND g.rolname='authenticated'
            AND x.privilege_type IN ('INSERT','DELETE','TRUNCATE')), 'merchants DML left';
  -- guard extended: new body protects email/type/delivery_time_min too
  ASSERT pg_get_functiondef('public.merchants_guard_sensitive_fields()'::regprocedure)
         ILIKE '%email is managed by the admin RPCs%', 'guard extension missing';
  ASSERT md5(pg_get_functiondef('public.merchants_guard_sensitive_fields()'::regprocedure))
         <> '7107c3cb04bf85de221ca347479d6ca2', 'guard body unchanged';
END $$;

COMMIT;
