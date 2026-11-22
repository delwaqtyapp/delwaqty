-- 354_admin_manage_policies.sql
-- Owner directive: admins must be able to edit/delete every managed entity.
-- Audit found admin coverage for products (admin_upsert_product/admin_delete_product),
-- categories, service_categories, service_providers, regions, banners, orders,
-- users, drivers (update), reviews (delete), drug_catalog, commissions (RPCs).
-- Missing: merchant edit, catalog_categories, coupons, promo_codes,
-- delivery_zones, delivery_pricing, offers. This migration adds admin manage
-- policies gated on _is_active_admin_uid(auth.uid()) (orders precedent).
-- Driver/user delete stays intentionally absent (sanctions + pending-deletions flow).

BEGIN;

CREATE POLICY "merchants admin update" ON public.merchants
  FOR UPDATE TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

CREATE POLICY "catalog_categories admin manage" ON public.catalog_categories
  FOR ALL TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

CREATE POLICY "coupons admin manage" ON public.coupons
  FOR ALL TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

CREATE POLICY "promo_codes admin manage" ON public.promo_codes
  FOR ALL TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

CREATE POLICY "delivery_zones admin manage" ON public.delivery_zones
  FOR ALL TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

CREATE POLICY "delivery_pricing admin manage" ON public.delivery_pricing
  FOR ALL TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

CREATE POLICY "offers admin manage" ON public.offers
  FOR ALL TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

COMMIT;
