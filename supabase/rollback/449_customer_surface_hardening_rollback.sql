-- Rollback for 449_customer_surface_hardening.sql (phase 2a, non-breaking).
-- Restores the pre-449 state:
--   * the 22 re-pointed policies (canonical pg_get_expr texts captured from
--     the post-448 chain on 2026-11-26; whitespace may differ from the
--     originals, semantics are identical);
--   * campaigns_guard_status_change (362 body, md5
--     'ffa5f17cde22ef4767785429d1db4d90');
--   * drops the 449 views, RPCs and helpers;
--   * restores merchants_guard_sensitive_fields to its pre-449 body (md5
--     '7107c3cb04bf85de221ca347479d6ca2');
--   * replays ONLY the grants 449 actually snapshotted before revoking
--     (_449_revoked_grants; exact inverse incl. grantor/grant-option).
-- DOES NOT touch data. Apply manually with psql; NOT part of the chain.

BEGIN;

-- 1. policies back to pre-449 expressions
ALTER POLICY "Admins can manage bookings" ON service_bookings USING (_admin_write_scope(( SELECT _point_region_id(sp.latitude, sp.longitude) AS _point_region_id    FROM service_providers sp   WHERE (sp.id = service_bookings.provider_id))));
ALTER POLICY "Merchant owners can manage products" ON products USING ((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.owner_user_id = auth.uid()))));
ALTER POLICY "Merchants can view orders for their merchant" ON orders USING ((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.owner_user_id = ( SELECT auth.uid() AS uid)))));
ALTER POLICY "Merchants can view reviews for their merchant" ON reviews USING ((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.owner_user_id = auth.uid()))));
ALTER POLICY "Products are viewable by everyone" ON products USING (((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.status = 'active'::text))) OR is_merchant_owner(merchant_id)));
ALTER POLICY "Reviews are viewable by everyone" ON reviews USING (((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.status = 'active'::text))) OR is_merchant_owner(merchant_id)));
ALTER POLICY "branches merchant manage" ON branches USING ((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.owner_user_id = auth.uid()))));
ALTER POLICY "provider docs owner rw" ON provider_documents USING ((provider_id IN ( SELECT service_providers.id    FROM service_providers   WHERE (service_providers.user_id = auth.uid()))));
ALTER POLICY branches_view ON branches USING (((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.status = 'active'::text))) OR is_merchant_owner(merchant_id)));
ALTER POLICY driver_locations_select ON driver_locations USING (((driver_id IN ( SELECT drivers.id    FROM drivers   WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1    FROM orders o   WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id            FROM merchants           WHERE (merchants.owner_user_id = auth.uid())))))))));
ALTER POLICY driver_obligations_read_own ON driver_obligations USING ((_admin_write_scope(_ops_scope_region(_merchant_region_id(merchant_id))) OR (EXISTS ( SELECT 1    FROM drivers d   WHERE ((d.id = driver_obligations.driver_id) AND (d.user_id = auth.uid())))) OR (EXISTS ( SELECT 1    FROM merchants m   WHERE ((m.id = driver_obligations.merchant_id) AND (m.owner_user_id = auth.uid()))))));
ALTER POLICY merchant_ledger_read_own ON merchant_ledger USING ((_admin_write_scope(_ops_scope_region(_merchant_region_id(merchant_id))) OR (EXISTS ( SELECT 1    FROM merchants m   WHERE ((m.id = merchant_ledger.merchant_id) AND (m.owner_user_id = auth.uid()))))));
ALTER POLICY merchant_payout_requests_read_own ON merchant_payout_requests USING ((_admin_write_scope(_ops_scope_region(_merchant_region_id(merchant_id))) OR (EXISTS ( SELECT 1    FROM merchants m   WHERE ((m.id = merchant_payout_requests.merchant_id) AND (m.owner_user_id = auth.uid()))))));
ALTER POLICY merchant_staff_settings_owner ON merchant_staff_settings USING ((EXISTS ( SELECT 1    FROM merchants m   WHERE ((m.id = merchant_staff_settings.merchant_id) AND (m.owner_user_id = auth.uid())))));
ALTER POLICY offers_view ON offers USING (((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.status = 'active'::text))) OR is_merchant_owner(merchant_id)));
ALTER POLICY ot_view_participants ON order_tracking USING (((EXISTS ( SELECT 1    FROM orders oa   WHERE ((oa.id = order_tracking.order_id) AND _admin_write_scope(_ops_scope_region(_merchant_region_id(oa.merchant_id)))))) OR (EXISTS ( SELECT 1    FROM orders o   WHERE ((o.id = order_tracking.order_id) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT m.id            FROM merchants m           WHERE (m.owner_user_id = auth.uid()))) OR (o.driver_id IN ( SELECT d.id            FROM drivers d           WHERE (d.user_id = auth.uid())))))))));
ALTER POLICY pos_sales_select_merchant ON pos_sales USING ((EXISTS ( SELECT 1    FROM merchants m   WHERE ((m.id = pos_sales.merchant_id) AND (m.owner_user_id = auth.uid())))));
ALTER POLICY product_modifier_groups_write ON product_modifier_groups USING (is_merchant_owner(( SELECT p.merchant_id    FROM products p   WHERE (p.id = product_modifier_groups.product_id))));
ALTER POLICY product_modifier_options_write ON product_modifier_options USING (is_merchant_owner(( SELECT p.merchant_id    FROM (products p      JOIN product_modifier_groups g ON ((g.product_id = p.id)))   WHERE (g.id = product_modifier_options.group_id))));
ALTER POLICY service_bookings_select_provider ON service_bookings USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1    FROM service_providers sp   WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid())))) OR _admin_member_scope(user_id)));
ALTER POLICY service_bookings_update_provider ON service_bookings USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1    FROM service_providers sp   WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid()))))));
ALTER POLICY "Admins can manage bookings" ON service_bookings WITH CHECK (_admin_write_scope(( SELECT _point_region_id(sp.latitude, sp.longitude) AS _point_region_id    FROM service_providers sp   WHERE (sp.id = service_bookings.provider_id))));
ALTER POLICY "branches merchant manage" ON branches WITH CHECK ((merchant_id IN ( SELECT merchants.id    FROM merchants   WHERE (merchants.owner_user_id = auth.uid()))));
ALTER POLICY "provider docs owner rw" ON provider_documents WITH CHECK ((provider_id IN ( SELECT service_providers.id    FROM service_providers   WHERE (service_providers.user_id = auth.uid()))));
ALTER POLICY merchant_staff_settings_owner ON merchant_staff_settings WITH CHECK ((EXISTS ( SELECT 1    FROM merchants m   WHERE ((m.id = merchant_staff_settings.merchant_id) AND (m.owner_user_id = auth.uid())))));
ALTER POLICY ot_insert_participants ON order_tracking WITH CHECK (((EXISTS ( SELECT 1    FROM orders oa   WHERE ((oa.id = order_tracking.order_id) AND _admin_write_scope(_ops_scope_region(_merchant_region_id(oa.merchant_id)))))) OR (EXISTS ( SELECT 1    FROM orders o   WHERE ((o.id = order_tracking.order_id) AND ((o.merchant_id IN ( SELECT m.id            FROM merchants m           WHERE (m.owner_user_id = auth.uid()))) OR (o.driver_id IN ( SELECT d.id            FROM drivers d           WHERE (d.user_id = auth.uid())))))))));
ALTER POLICY product_modifier_groups_write ON product_modifier_groups WITH CHECK (is_merchant_owner(( SELECT p.merchant_id    FROM products p   WHERE (p.id = product_modifier_groups.product_id))));
ALTER POLICY product_modifier_options_write ON product_modifier_options WITH CHECK (is_merchant_owner(( SELECT p.merchant_id    FROM (products p      JOIN product_modifier_groups g ON ((g.product_id = p.id)))   WHERE (g.id = product_modifier_options.group_id))));
ALTER POLICY service_bookings_update_provider ON service_bookings WITH CHECK (((user_id = auth.uid()) OR (EXISTS ( SELECT 1    FROM service_providers sp   WHERE ((sp.id = service_bookings.provider_id) AND (sp.user_id = auth.uid()))))));

-- 2. campaigns trigger back to the 362 body
CREATE OR REPLACE FUNCTION public.campaigns_guard_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    -- Lifecycle transitions are owner/country-level only, matching the
    -- campaign_* RPC gates (361). Creators keep the submit/resubmit path.
    IF auth.uid() IS NOT NULL AND NOT public._is_country_admin_uid(auth.uid()) THEN
      IF NOT (
        OLD.created_by = auth.uid()
        AND OLD.status IN ('draft','rejected')
        AND NEW.status IN ('draft','pending_review')
        AND (
          EXISTS (SELECT 1 FROM public.merchants m WHERE m.owner_user_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.merchant_profiles mp WHERE mp.user_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.service_providers sp WHERE sp.user_id = auth.uid())
        )
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

-- 3. drop the 449 objects
CREATE OR REPLACE FUNCTION public.merchants_guard_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
  end if;
  return NEW;
end;
$function$;
DROP VIEW IF EXISTS public.merchants_public;
DROP VIEW IF EXISTS public.products_public;
DROP FUNCTION IF EXISTS public.get_my_merchant_profile();
DROP FUNCTION IF EXISTS public.get_my_products(uuid);
DROP FUNCTION IF EXISTS public.admin_get_merchant_contacts(uuid[]);
DROP FUNCTION IF EXISTS public.admin_get_merchant_products(uuid);
DROP FUNCTION IF EXISTS public._merchant_is_active(uuid);
DROP FUNCTION IF EXISTS public._product_merchant_id(uuid);
DROP FUNCTION IF EXISTS public._provider_is_owner(uuid);
DROP FUNCTION IF EXISTS public._provider_region_id(uuid);
DROP FUNCTION IF EXISTS public._actor_is_seller();
DROP FUNCTION IF EXISTS public._owns_merchant_row(uuid);

-- 4. exact restore: replay ONLY the rows 449 snapshotted before revoking
-- (table/grantee/privilege/grantor/grantable). STRICT: any restore failure
-- or any row missing afterwards aborts the whole transaction and KEEPS the
-- snapshot table for diagnosis/retry. The snapshot is dropped only after
-- the full postcondition (every snapshot row present with its original
-- grantor and grant-option) passes.
DO $$
DECLARE
  r record;
  v_me text := current_user;
  v_missing int;
BEGIN
  IF to_regclass('public._449_revoked_grants') IS NULL THEN
    RAISE WARNING '449 rollback: snapshot table _449_revoked_grants absent; nothing to restore';
    RETURN;
  END IF;
  FOR r IN SELECT * FROM public._449_revoked_grants LOOP
    -- already exactly present (never actually revoked, or restored earlier):
    -- grantor AND grant-option must both match, otherwise re-grant below
    -- pg_class.relacl + aclexplode, NOT information_schema (which hides
    -- rows not involving a currently enabled role)
    IF EXISTS (SELECT 1 FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                CROSS JOIN LATERAL aclexplode(c.relacl) x
                JOIN pg_roles ge ON ge.oid = x.grantee
                JOIN pg_roles go ON go.oid = x.grantor
                WHERE n.nspname='public' AND c.relname=r.tbl
                  AND ge.rolname=r.grantee AND x.privilege_type=r.privilege
                  AND go.rolname=r.grantor
                  AND x.is_grantable = r.grantable) THEN
      CONTINUE;
    END IF;
    BEGIN
      IF r.grantor <> v_me THEN
        EXECUTE format('SET LOCAL ROLE %I', r.grantor);
      END IF;
      -- a plain GRANT restores the privilege; WITH GRANT OPTION also
      -- restores a lost grant option on an existing privilege
      IF r.grantable THEN
        EXECUTE format('GRANT %s ON public.%I TO %I WITH GRANT OPTION', r.privilege, r.tbl, r.grantee);
      ELSE
        EXECUTE format('GRANT %s ON public.%I TO %I', r.privilege, r.tbl, r.grantee);
      END IF;
      IF r.grantor <> v_me THEN
        RESET ROLE;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RESET ROLE;
      RAISE EXCEPTION '449 rollback: failed to restore % on public.% to % (grantor %): % / % - transaction aborted, snapshot kept',
        r.privilege, r.tbl, r.grantee, r.grantor, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  -- full exact postcondition: every snapshot row must now exist with its
  -- original grantor and grant-option
  SELECT count(*) INTO v_missing
    FROM public._449_revoked_grants g
   WHERE NOT EXISTS (SELECT 1 FROM pg_class c
                      JOIN pg_namespace n ON n.oid = c.relnamespace
                      CROSS JOIN LATERAL aclexplode(c.relacl) x
                      JOIN pg_roles ge ON ge.oid = x.grantee
                      JOIN pg_roles go ON go.oid = x.grantor
                      WHERE n.nspname='public' AND c.relname=g.tbl
                        AND ge.rolname=g.grantee AND x.privilege_type=g.privilege
                        AND go.rolname=g.grantor
                        AND x.is_grantable = g.grantable);
  IF v_missing > 0 THEN
    RAISE EXCEPTION '449 rollback: % snapshot rows not restored exactly - transaction aborted, snapshot kept', v_missing;
  END IF;
END $$;
-- reached only when the postcondition passed
DROP TABLE IF EXISTS public._449_revoked_grants;

COMMIT;
