-- ─────────────────────────────────────────────────────────────
-- 090: Admin product CRUD — create/edit products + inventory
-- customers buy products in the commerce flow; the admin app
-- could only delete them (round 52). products/product_inventory
-- RLS only lets the owning merchant write, so admins need a
-- SECURITY DEFINER writable path gated by public.is_admin().
-- ─────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.admin_upsert_product(UUID, UUID, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, INTEGER);
CREATE OR REPLACE FUNCTION public.admin_upsert_product(
  p_id uuid,
  p_merchant_id uuid,
  p_name text,
  p_description text DEFAULT NULL,
  p_price numeric DEFAULT 0,
  p_compare_at_price numeric DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_image_url text DEFAULT NULL,
  p_is_available boolean DEFAULT true,
  p_stock_quantity integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

  RETURN jsonb_build_object(
    'success', true,
    'product_id', v_product_id::text,
    'merchant_id', p_merchant_id::text
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_product(UUID, UUID, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(UUID, UUID, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(UUID, UUID, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, INTEGER) TO service_role;