-- 356_admin_region_scope_enforcement.sql
-- Suite F (F-01/F-02/F-04/F-05): enforce regional scope on every admin write
-- path, add audit writes, and make admin_delete_merchant FK-safe.
-- Model: owner = full access. Country-level admin = active admin assigned to a
-- root region (parent_region_id IS NULL) with scope 'descendants' = full
-- access. Other assigned admins = only regions they cover (self/descendants).
-- Unassigned admins (no admin_region_assignments rows) = no write access.
-- Merchant/provider region is resolved geospatially via geo_region_for_point
-- (merchants/service_providers carry lat/lon, not region_id). NULL region =
-- owner + country-level only.

BEGIN;

-- ---------- helpers ----------
CREATE OR REPLACE FUNCTION public._point_region_id(p_lat double precision, p_lon double precision)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT (public.geo_region_for_point(p_lat, p_lon)).region_id;
$$;

CREATE OR REPLACE FUNCTION public._merchant_region_id(p_merchant_id uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public._point_region_id(m.latitude, m.longitude)
  FROM public.merchants m
  WHERE m.id = p_merchant_id;
$$;

CREATE OR REPLACE FUNCTION public._is_country_admin_uid(p_uid uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public._is_owner_uid(p_uid)
     OR (public._is_active_admin_uid(p_uid)
         AND EXISTS (
           SELECT 1
           FROM public.admin_region_assignments a
           JOIN public.regions r ON r.id = a.region_id
           WHERE a.admin_id = p_uid
             AND a.scope = 'descendants'
             AND r.parent_region_id IS NULL
         ));
$$;

-- Redefine 355's helper with the corrected semantics: global write access
-- means owner or country-level, NOT merely "no assignments".
CREATE OR REPLACE FUNCTION public._is_global_admin_uid(p_uid uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public._is_country_admin_uid(p_uid);
$$;

CREATE OR REPLACE FUNCTION public._admin_write_scope(p_region_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF public._is_owner_uid(auth.uid()) THEN
    RETURN true;
  END IF;
  IF NOT public._is_active_admin_uid(auth.uid()) THEN
    RETURN false;
  END IF;
  IF public._is_country_admin_uid(auth.uid()) THEN
    RETURN true;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_region_assignments a
    WHERE a.admin_id = auth.uid()
  ) THEN
    RETURN false; -- unassigned admins get nothing
  END IF;
  IF p_region_id IS NULL THEN
    RETURN false; -- entity region unknown: owner/country only
  END IF;
  RETURN public._admin_covers_region(auth.uid(), p_region_id);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public._point_region_id(double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public._merchant_region_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._is_country_admin_uid(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._admin_write_scope(uuid) TO authenticated;

-- ---------- RPC hardening ----------
CREATE OR REPLACE FUNCTION public.admin_upsert_product(p_id uuid, p_merchant_id uuid, p_name text, p_description text DEFAULT NULL::text, p_price numeric DEFAULT 0, p_compare_at_price numeric DEFAULT NULL::numeric, p_category text DEFAULT NULL::text, p_image_url text DEFAULT NULL::text, p_is_available boolean DEFAULT true, p_stock_quantity integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_product_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;

  IF p_merchant_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.merchants WHERE id = p_merchant_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'merchant_not_found');
  END IF;

  IF NOT public._admin_write_scope(public._merchant_region_id(p_merchant_id)) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'outside_region_scope');
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'name_required');
  END IF;

  IF p_id IS NOT NULL THEN
    UPDATE public.products
       SET name = p_name,
           description = p_description,
           price = COALESCE(p_price, 0),
           compare_at_price = p_compare_at_price,
           category = p_category,
           image_url = p_image_url,
           is_available = COALESCE(p_is_available, true),
           stock_quantity = COALESCE(p_stock_quantity, 0),
           updated_at = NOW()
     WHERE id = p_id AND merchant_id = p_merchant_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'reason', 'product_not_found');
    END IF;
    v_product_id := p_id;
  ELSE
    INSERT INTO public.products (
      merchant_id, name, description, price, compare_at_price,
      category, image_url, is_available, stock_quantity
    ) VALUES (
      p_merchant_id, p_name, p_description, COALESCE(p_price, 0),
      p_compare_at_price, p_category, p_image_url,
      COALESCE(p_is_available, true), COALESCE(p_stock_quantity, 0)
    )
    RETURNING id INTO v_product_id;
  END IF;

  INSERT INTO public.product_inventory (
    product_id, merchant_id, stock_quantity, is_in_stock, updated_at
  ) VALUES (
    v_product_id, p_merchant_id, COALESCE(p_stock_quantity, 0),
    COALESCE(p_stock_quantity, 0) > 0, NOW()
  )
  ON CONFLICT (product_id) DO UPDATE
    SET stock_quantity = EXCLUDED.stock_quantity,
        is_in_stock = EXCLUDED.stock_quantity > 0,
        updated_at = NOW();

  PERFORM public.write_audit(
    'ADMIN_PRODUCT_UPSERT', 'products', v_product_id::text,
    jsonb_build_object('actor', auth.uid()::text, 'merchant_id', p_merchant_id::text));

  RETURN jsonb_build_object(
    'success', true,
    'product_id', v_product_id::text,
    'merchant_id', p_merchant_id::text
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_delete_product(p_product_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_merchant_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;
  SELECT merchant_id INTO v_merchant_id
  FROM public.products WHERE id = p_product_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  IF NOT public._admin_write_scope(public._merchant_region_id(v_merchant_id)) THEN
    RAISE EXCEPTION 'forbidden: outside region scope';
  END IF;
  DELETE FROM public.reviews WHERE product_id = p_product_id;
  BEGIN
    DELETE FROM public.products WHERE id = p_product_id;
  EXCEPTION WHEN foreign_key_violation THEN
    UPDATE public.products
       SET is_available = false, updated_at = now()
     WHERE id = p_product_id;
  END;
  PERFORM public.write_audit(
    'ADMIN_PRODUCT_DELETE', 'products', p_product_id::text,
    jsonb_build_object('actor', auth.uid()::text, 'merchant_id', v_merchant_id::text));
  RETURN true;
END; $function$;

CREATE OR REPLACE FUNCTION public.admin_delete_merchant(p_merchant_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.merchants WHERE id = p_merchant_id) THEN
    RETURN false;
  END IF;
  IF NOT public._admin_write_scope(public._merchant_region_id(p_merchant_id)) THEN
    RAISE EXCEPTION 'forbidden: outside region scope';
  END IF;
  BEGIN
    DELETE FROM public.reviews WHERE merchant_id = p_merchant_id;
    UPDATE public.products
       SET is_available = false, updated_at = now()
     WHERE merchant_id = p_merchant_id
       AND id IN (SELECT product_id FROM public.order_items);
    DELETE FROM public.products
     WHERE merchant_id = p_merchant_id
       AND id NOT IN (SELECT product_id FROM public.order_items);
    DELETE FROM public.merchants WHERE id = p_merchant_id;
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'merchant_has_dependents: suspend the merchant instead of deleting';
  END;
  PERFORM public.write_audit(
    'ADMIN_MERCHANT_DELETE', 'merchants', p_merchant_id::text,
    jsonb_build_object('actor', auth.uid()::text));
  RETURN true;
END; $function$;

-- ---------- policy scoping (regional tables) ----------
DROP POLICY IF EXISTS "merchants admin update" ON public.merchants;
CREATE POLICY "merchants admin update" ON public.merchants
  FOR UPDATE TO authenticated
  USING (public.admin_has_permission('MERCHANT_EDIT')
         AND public._admin_write_scope(public._merchant_region_id(id)))
  WITH CHECK (public.admin_has_permission('MERCHANT_EDIT')
         AND public._admin_write_scope(public._merchant_region_id(id)));

DROP POLICY IF EXISTS "delivery_zones admin manage" ON public.delivery_zones;
CREATE POLICY "delivery_zones admin manage" ON public.delivery_zones
  FOR ALL TO authenticated
  USING (public.admin_has_permission('MERCHANT_EDIT')
         AND public._admin_write_scope(public._merchant_region_id(merchant_id)))
  WITH CHECK (public.admin_has_permission('MERCHANT_EDIT')
         AND public._admin_write_scope(public._merchant_region_id(merchant_id)));

DROP POLICY IF EXISTS "offers admin manage" ON public.offers;
CREATE POLICY "offers admin manage" ON public.offers
  FOR ALL TO authenticated
  USING (public.admin_has_permission('OFFER_CREATE')
         AND public._admin_write_scope(public._merchant_region_id(merchant_id)))
  WITH CHECK (public.admin_has_permission('OFFER_CREATE')
         AND public._admin_write_scope(public._merchant_region_id(merchant_id)));

DROP POLICY IF EXISTS "Admins can manage providers" ON public.service_providers;
CREATE POLICY "Admins can manage providers" ON public.service_providers
  FOR ALL TO authenticated
  USING (public._admin_write_scope(
           public._point_region_id(latitude, longitude)))
  WITH CHECK (public._admin_write_scope(
           public._point_region_id(latitude, longitude)));

-- ---------- policy scoping (global tables: owner + country-level only) ----------
DROP POLICY IF EXISTS "catalog_categories admin manage" ON public.catalog_categories;
CREATE POLICY "catalog_categories admin manage" ON public.catalog_categories
  FOR ALL TO authenticated
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "coupons admin manage" ON public.coupons;
CREATE POLICY "coupons admin manage" ON public.coupons
  FOR ALL TO authenticated
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "promo_codes admin manage" ON public.promo_codes;
CREATE POLICY "promo_codes admin manage" ON public.promo_codes
  FOR ALL TO authenticated
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "delivery_pricing admin manage" ON public.delivery_pricing;
CREATE POLICY "delivery_pricing admin manage" ON public.delivery_pricing
  FOR ALL TO authenticated
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "categories admin manage" ON public.categories;
CREATE POLICY "categories admin manage" ON public.categories
  FOR ALL
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "regions admin write" ON public.regions;
CREATE POLICY "regions admin write" ON public.regions
  FOR ALL
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "drug_catalog_admin" ON public.drug_catalog;
CREATE POLICY "drug_catalog_admin" ON public.drug_catalog
  FOR ALL
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "campaign_banners admin insert" ON public.campaign_banners;
DROP POLICY IF EXISTS "campaign_banners admin update" ON public.campaign_banners;
DROP POLICY IF EXISTS "campaign_banners admin delete" ON public.campaign_banners;
CREATE POLICY "campaign_banners admin insert" ON public.campaign_banners
  FOR INSERT TO authenticated
  WITH CHECK (public._is_country_admin_uid(auth.uid()));
CREATE POLICY "campaign_banners admin update" ON public.campaign_banners
  FOR UPDATE TO authenticated
  USING (public._is_country_admin_uid(auth.uid()))
  WITH CHECK (public._is_country_admin_uid(auth.uid()));
CREATE POLICY "campaign_banners admin delete" ON public.campaign_banners
  FOR DELETE TO authenticated
  USING (public._is_country_admin_uid(auth.uid()));

-- ---------- F-04: audit trigger for direct admin writes on managed tables ----------
CREATE OR REPLACE FUNCTION public._audit_admin_table_write()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF public._is_active_admin_uid(auth.uid()) THEN
    PERFORM public.write_audit(
      'ADMIN_TABLE_' || TG_OP, TG_TABLE_NAME,
      COALESCE(
        (CASE TG_OP WHEN 'DELETE' THEN OLD.id ELSE NEW.id END)::text,
        NULL
      ),
      jsonb_build_object('actor', auth.uid()::text)
    );
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$fn$;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'merchants','catalog_categories','coupons','promo_codes',
    'delivery_zones','delivery_pricing','offers','service_providers',
    'categories','regions','campaign_banners','drug_catalog'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS admin_audit_write ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER admin_audit_write AFTER INSERT OR UPDATE OR DELETE ON public.%I
       FOR EACH ROW EXECUTE FUNCTION public._audit_admin_table_write()', t);
  END LOOP;
END $$;

COMMIT;
