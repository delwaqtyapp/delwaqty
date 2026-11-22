-- 355_admin_manage_scope_tightening.sql
-- Tightens 354 after QA review: _is_active_admin_uid alone let any active
-- admin (including region-scoped ones) write global tables and any merchant.
-- New model:
--   merchants, delivery_zones (merchant-scoped) -> admin_has_permission('MERCHANT_EDIT')
--   offers -> admin_has_permission('OFFER_CREATE')
--   global tables (catalog_categories, coupons, promo_codes, delivery_pricing)
--     -> global admins only (owner or admin with no region assignments)
--        AND admin_has_permission('SETTINGS_EDIT')
-- Region scoping note: merchants/delivery_zones carry no region_id column, so
-- RLS cannot express geographic scope; the permission grant is the gate.

BEGIN;

CREATE OR REPLACE FUNCTION public._is_global_admin_uid(p_uid uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public._is_owner_uid(p_uid)
     OR (public._is_active_admin_uid(p_uid)
         AND NOT EXISTS (
           SELECT 1 FROM public.admin_region_assignments a
           WHERE a.admin_id = p_uid
         ));
$$;

GRANT EXECUTE ON FUNCTION public._is_global_admin_uid(uuid) TO authenticated;

DROP POLICY IF EXISTS "merchants admin update" ON public.merchants;
CREATE POLICY "merchants admin update" ON public.merchants
  FOR UPDATE TO authenticated
  USING (public.admin_has_permission('MERCHANT_EDIT'))
  WITH CHECK (public.admin_has_permission('MERCHANT_EDIT'));

DROP POLICY IF EXISTS "delivery_zones admin manage" ON public.delivery_zones;
CREATE POLICY "delivery_zones admin manage" ON public.delivery_zones
  FOR ALL TO authenticated
  USING (public.admin_has_permission('MERCHANT_EDIT'))
  WITH CHECK (public.admin_has_permission('MERCHANT_EDIT'));

DROP POLICY IF EXISTS "offers admin manage" ON public.offers;
CREATE POLICY "offers admin manage" ON public.offers
  FOR ALL TO authenticated
  USING (public.admin_has_permission('OFFER_CREATE'))
  WITH CHECK (public.admin_has_permission('OFFER_CREATE'));

DROP POLICY IF EXISTS "catalog_categories admin manage" ON public.catalog_categories;
CREATE POLICY "catalog_categories admin manage" ON public.catalog_categories
  FOR ALL TO authenticated
  USING (public._is_global_admin_uid(auth.uid()) AND public.admin_has_permission('SETTINGS_EDIT'))
  WITH CHECK (public._is_global_admin_uid(auth.uid()) AND public.admin_has_permission('SETTINGS_EDIT'));

DROP POLICY IF EXISTS "coupons admin manage" ON public.coupons;
CREATE POLICY "coupons admin manage" ON public.coupons
  FOR ALL TO authenticated
  USING (public._is_global_admin_uid(auth.uid()) AND public.admin_has_permission('SETTINGS_EDIT'))
  WITH CHECK (public._is_global_admin_uid(auth.uid()) AND public.admin_has_permission('SETTINGS_EDIT'));

DROP POLICY IF EXISTS "promo_codes admin manage" ON public.promo_codes;
CREATE POLICY "promo_codes admin manage" ON public.promo_codes
  FOR ALL TO authenticated
  USING (public._is_global_admin_uid(auth.uid()) AND public.admin_has_permission('SETTINGS_EDIT'))
  WITH CHECK (public._is_global_admin_uid(auth.uid()) AND public.admin_has_permission('SETTINGS_EDIT'));

DROP POLICY IF EXISTS "delivery_pricing admin manage" ON public.delivery_pricing;
CREATE POLICY "delivery_pricing admin manage" ON public.delivery_pricing
  FOR ALL TO authenticated
  USING (public._is_global_admin_uid(auth.uid()) AND public.admin_has_permission('SETTINGS_EDIT'))
  WITH CHECK (public._is_global_admin_uid(auth.uid()) AND public.admin_has_permission('SETTINGS_EDIT'));

COMMIT;
