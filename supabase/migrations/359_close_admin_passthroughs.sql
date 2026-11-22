-- 359_close_admin_passthroughs.sql
-- Lab retest: new scoped policies are PERMISSIVE, so they only add access;
-- pre-existing permissive policies with hidden admin pass-throughs
-- (is_merchant_owner ends with OR is_admin(); several policies OR is_admin())
-- still allowed cross-region writes. This migration removes the admin
-- pass-through from merchant-SELF policies and replaces bare is_admin()
-- admin-write policies with region-scoped ones.

BEGIN;

-- Owner-only helper: is_merchant_owner WITHOUT the admin pass-through.
CREATE OR REPLACE FUNCTION public._is_merchant_owner_only(p_merchant_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.merchants m
    WHERE m.id = p_merchant_id
      AND (m.owner_user_id = auth.uid() OR m.id = auth.uid())
  );
$$;

GRANT EXECUTE ON FUNCTION public._is_merchant_owner_only(uuid) TO authenticated;

-- offers: merchant-self policies lose the admin pass-through
-- (admins use the scoped "offers admin manage" policy).
DROP POLICY IF EXISTS "offers merchant manage" ON public.offers;
DROP POLICY IF EXISTS "offers_insert_merchant" ON public.offers;
DROP POLICY IF EXISTS "offers_update_merchant" ON public.offers;
DROP POLICY IF EXISTS "offers_delete_merchant" ON public.offers;
CREATE POLICY "offers_insert_merchant" ON public.offers
  FOR INSERT TO authenticated
  WITH CHECK (public._is_merchant_owner_only(merchant_id));
CREATE POLICY "offers_update_merchant" ON public.offers
  FOR UPDATE TO authenticated
  USING (public._is_merchant_owner_only(merchant_id))
  WITH CHECK (public._is_merchant_owner_only(merchant_id));
CREATE POLICY "offers_delete_merchant" ON public.offers
  FOR DELETE TO authenticated
  USING (public._is_merchant_owner_only(merchant_id));

-- products: merchant-self write policies lose the admin pass-through
-- (admin writes go through admin_upsert_product/admin_delete_product, scoped).
DROP POLICY IF EXISTS "products_insert_merchant" ON public.products;
DROP POLICY IF EXISTS "products_update_merchant" ON public.products;
DROP POLICY IF EXISTS "products_delete_merchant" ON public.products;
CREATE POLICY "products_insert_merchant" ON public.products
  FOR INSERT TO authenticated
  WITH CHECK (public._is_merchant_owner_only(merchant_id));
CREATE POLICY "products_update_merchant" ON public.products
  FOR UPDATE TO authenticated
  USING (public._is_merchant_owner_only(merchant_id))
  WITH CHECK (public._is_merchant_owner_only(merchant_id));
CREATE POLICY "products_delete_merchant" ON public.products
  FOR DELETE TO authenticated
  USING (public._is_merchant_owner_only(merchant_id));

-- branches: same treatment
DROP POLICY IF EXISTS "branches_insert_merchant" ON public.branches;
DROP POLICY IF EXISTS "branches_update_merchant" ON public.branches;
DROP POLICY IF EXISTS "branches_delete_merchant" ON public.branches;
CREATE POLICY "branches_insert_merchant" ON public.branches
  FOR INSERT TO authenticated
  WITH CHECK (public._is_merchant_owner_only(merchant_id));
CREATE POLICY "branches_update_merchant" ON public.branches
  FOR UPDATE TO authenticated
  USING (public._is_merchant_owner_only(merchant_id))
  WITH CHECK (public._is_merchant_owner_only(merchant_id));
CREATE POLICY "branches_delete_merchant" ON public.branches
  FOR DELETE TO authenticated
  USING (public._is_merchant_owner_only(merchant_id));

-- service_providers: manage_own is OWN only; admins use the scoped policy
DROP POLICY IF EXISTS "service_providers_manage_own" ON public.service_providers;
CREATE POLICY "service_providers_manage_own" ON public.service_providers
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- pos_* merchant-scoped tables: owner-only OR region-scoped admin
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'pos_customers','pos_debt_ledger','pos_insurance_companies',
    'pos_insurance_sales','pos_price_history','pos_shifts','pos_stock_moves'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_owner', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated
       USING (public._is_merchant_owner_only(merchant_id)
              OR public._admin_write_scope(public._merchant_region_id(merchant_id)))
       WITH CHECK (public._is_merchant_owner_only(merchant_id)
              OR public._admin_write_scope(public._merchant_region_id(merchant_id)))',
      t || '_owner', t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS "pos_sale_payments_owner" ON public.pos_sale_payments;
CREATE POLICY "pos_sale_payments_owner" ON public.pos_sale_payments
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.pos_sales s
    WHERE s.id = pos_sale_payments.sale_id
      AND (public._is_merchant_owner_only(s.merchant_id)
           OR public._admin_write_scope(public._merchant_region_id(s.merchant_id)))))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.pos_sales s
    WHERE s.id = pos_sale_payments.sale_id
      AND (public._is_merchant_owner_only(s.merchant_id)
           OR public._admin_write_scope(public._merchant_region_id(s.merchant_id)))));

DROP POLICY IF EXISTS "pos_sales_admin" ON public.pos_sales;
CREATE POLICY "pos_sales_admin" ON public.pos_sales
  FOR ALL TO authenticated
  USING (public._admin_write_scope(public._merchant_region_id(merchant_id)))
  WITH CHECK (public._admin_write_scope(public._merchant_region_id(merchant_id)));

DROP POLICY IF EXISTS "cashier_licenses_admin_write" ON public.cashier_licenses;
CREATE POLICY "cashier_licenses_admin_write" ON public.cashier_licenses
  FOR ALL TO authenticated
  USING (public._admin_write_scope(public._merchant_region_id(merchant_id)))
  WITH CHECK (public._admin_write_scope(public._merchant_region_id(merchant_id)));

-- service_bookings: admin manage scoped to the provider's region
DROP POLICY IF EXISTS "Admins can manage bookings" ON public.service_bookings;
CREATE POLICY "Admins can manage bookings" ON public.service_bookings
  FOR ALL TO authenticated
  USING (public._admin_write_scope((
    SELECT public._point_region_id(sp.latitude, sp.longitude)
    FROM public.service_providers sp
    WHERE sp.id = service_bookings.provider_id)))
  WITH CHECK (public._admin_write_scope((
    SELECT public._point_region_id(sp.latitude, sp.longitude)
    FROM public.service_providers sp
    WHERE sp.id = service_bookings.provider_id)));

-- service_categories: global catalog -> owner/country only
DROP POLICY IF EXISTS "Admins can manage categories" ON public.service_categories;
CREATE POLICY "Admins can manage categories" ON public.service_categories
  FOR ALL TO authenticated
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));

COMMIT;
