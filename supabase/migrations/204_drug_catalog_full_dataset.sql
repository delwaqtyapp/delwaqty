-- 204: extend drug_catalog for the full Egyptian dataset
-- (karem505/egyptian-drug-database, CC0-1.0): manufacturer, drug class,
-- route, and the official EGP retail price as a reference. The import RPC
-- defaults the pharmacy's price to the official price when not given.

ALTER TABLE public.drug_catalog
  ADD COLUMN IF NOT EXISTS manufacturer text,
  ADD COLUMN IF NOT EXISTS route text,
  ADD COLUMN IF NOT EXISTS official_price_egp numeric;

CREATE OR REPLACE FUNCTION public.pharmacy_import_drug(
  p_drug_id uuid,
  p_merchant_id uuid,
  p_price numeric DEFAULT NULL,
  p_stock int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_drug public.drug_catalog%ROWTYPE;
  v_product_id uuid;
  v_price numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_stock IS NULL OR p_stock < 0 THEN
    RAISE EXCEPTION 'INVALID_STOCK';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MERCHANT_NOT_FOUND';
  END IF;
  IF v_merchant.owner_user_id <> v_uid AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'NOT_YOUR_STORE';
  END IF;

  SELECT * INTO v_drug FROM public.drug_catalog
    WHERE id = p_drug_id AND is_active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRUG_NOT_FOUND';
  END IF;

  -- Default to the official retail price when the caller does not set one.
  v_price := COALESCE(p_price, v_drug.official_price_egp);
  IF v_price IS NULL OR v_price < 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;

  INSERT INTO public.products (
    merchant_id, name, name_ar, description, description_ar, price,
    category, stock_quantity, is_available, barcode
  ) VALUES (
    p_merchant_id,
    v_drug.name_en || COALESCE(' ' || v_drug.strength, ''),
    v_drug.name_ar,
    concat_ws(' · ', v_drug.active_ingredient, v_drug.strength,
              v_drug.dosage_form, v_drug.manufacturer),
    v_drug.name_ar,
    v_price,
    'pharmacy',
    p_stock,
    true,
    v_drug.barcode
  )
  RETURNING id INTO v_product_id;

  RETURN jsonb_build_object('ok', true, 'product_id', v_product_id);
END;
$function$;

NOTIFY pgrst, 'reload schema';
