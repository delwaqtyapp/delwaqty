-- 343: cashier PRO stage (second owner GO relayed via main 2026-11-22 03:45).
-- 1) MoH price list (التسعيرة الرسمية): bulk import into
--    drug_catalog.official_price_egp, then apply to a store's products
--    (matched by barcode) logging pos_price_history with source 'moh_update'.
-- 2) Insurance statements (تأمين): per-merchant insurance companies, insured
--    sales via the 'insurance_sale' sync op, and a per-company period statement.
-- 3) Shortage list (قائمة النواقص): products.reorder_level + shortage RPC.
-- 4) Cashier-to-platform linking: cashier_device_link wraps license validation
--    and returns the merchant profile/config for the desktop app.
-- All new RPCs follow 340's auth pattern: is_admin() OR is_merchant_owner().


ALTER TABLE public.products ADD COLUMN IF NOT EXISTS reorder_level integer;

CREATE TABLE public.pos_insurance_companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text,
  notes text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.pos_insurance_companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY pos_insurance_companies_owner ON public.pos_insurance_companies FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR public.is_admin());

CREATE TABLE public.pos_insurance_sales (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  company_id uuid NOT NULL REFERENCES public.pos_insurance_companies(id) ON DELETE CASCADE,
  sale_id uuid REFERENCES public.pos_sales(id),
  client_op_id uuid,
  member_name text,
  member_card_no text,
  total numeric(12,2) NOT NULL CHECK (total >= 0),
  company_share numeric(12,2) NOT NULL CHECK (company_share >= 0),
  patient_share numeric(12,2) NOT NULL CHECK (patient_share >= 0),
  created_by uuid REFERENCES public.users(id),
  created_offline_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, client_op_id)
);
ALTER TABLE public.pos_insurance_sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY pos_insurance_sales_owner ON public.pos_insurance_sales FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR public.is_admin());

CREATE OR REPLACE FUNCTION public.moh_price_import(p_rows jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_row jsonb;
  v_updated integer := 0;
  v_unmatched integer := 0;
  v_id uuid;
BEGIN
  -- The MoH list is platform-wide reference data; only admins import it.
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF jsonb_typeof(p_rows) <> 'array' THEN RAISE EXCEPTION 'rows must be an array'; END IF;
  FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_id := NULL;
    UPDATE public.drug_catalog
       SET official_price_egp = (v_row->>'official_price')::numeric
     WHERE barcode IS NOT NULL AND barcode = v_row->>'barcode'
       AND official_price_egp IS DISTINCT FROM (v_row->>'official_price')::numeric
    RETURNING id INTO v_id;
    IF v_id IS NULL AND NULLIF(v_row->>'barcode','') IS NULL THEN
      -- No barcode on the row: fall back to exact English name match.
      UPDATE public.drug_catalog
         SET official_price_egp = (v_row->>'official_price')::numeric
       WHERE lower(name_en) = lower(v_row->>'name_en')
         AND official_price_egp IS DISTINCT FROM (v_row->>'official_price')::numeric
      RETURNING id INTO v_id;
    END IF;
    IF v_id IS NULL THEN
      -- Row already at this price, or no catalog entry: check which.
      PERFORM 1 FROM public.drug_catalog
       WHERE (barcode IS NOT NULL AND barcode = v_row->>'barcode')
          OR (NULLIF(v_row->>'barcode','') IS NULL AND lower(name_en) = lower(v_row->>'name_en'));
      IF NOT FOUND THEN v_unmatched := v_unmatched + 1; END IF;
    ELSE
      v_updated := v_updated + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'updated', v_updated, 'unmatched', v_unmatched);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.moh_price_import(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.cashier_apply_moh_prices(p_merchant_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  INSERT INTO public.pos_price_history (merchant_id, product_id, old_price, new_price, source, changed_by)
  SELECT p.merchant_id, p.id, p.price, d.official_price_egp, 'moh_update', v_uid
    FROM public.products p
    JOIN public.drug_catalog d ON d.barcode IS NOT NULL AND d.barcode = p.barcode
   WHERE p.merchant_id = p_merchant_id
     AND d.official_price_egp IS NOT NULL
     AND p.price IS DISTINCT FROM d.official_price_egp;
  UPDATE public.products p
     SET price = d.official_price_egp, updated_at = now()
    FROM public.drug_catalog d
   WHERE p.merchant_id = p_merchant_id
     AND d.barcode IS NOT NULL AND d.barcode = p.barcode
     AND d.official_price_egp IS NOT NULL
     AND p.price IS DISTINCT FROM d.official_price_egp;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'updated', v_count);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_apply_moh_prices(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.pos_insurance_statement(
  p_merchant_id uuid, p_company_id uuid, p_from timestamptz, p_to timestamptz)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'company_id', p_company_id,
    'from', p_from, 'to', p_to,
    'count', (SELECT count(*) FROM public.pos_insurance_sales s
               WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
                 AND s.created_at >= p_from AND s.created_at < p_to),
    'total', (SELECT COALESCE(sum(s.total), 0) FROM public.pos_insurance_sales s
               WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
                 AND s.created_at >= p_from AND s.created_at < p_to),
    'company_share', (SELECT COALESCE(sum(s.company_share), 0) FROM public.pos_insurance_sales s
               WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
                 AND s.created_at >= p_from AND s.created_at < p_to),
    'patient_share', (SELECT COALESCE(sum(s.patient_share), 0) FROM public.pos_insurance_sales s
               WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
                 AND s.created_at >= p_from AND s.created_at < p_to),
    'rows', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'id', s.id, 'sale_id', s.sale_id, 'member_name', s.member_name,
               'member_card_no', s.member_card_no, 'total', s.total,
               'company_share', s.company_share, 'patient_share', s.patient_share,
               'created_at', s.created_at) ORDER BY s.created_at), '[]'::jsonb)
             FROM public.pos_insurance_sales s
             WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
               AND s.created_at >= p_from AND s.created_at < p_to));
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pos_insurance_statement(uuid, uuid, timestamptz, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION public.cashier_shortage_list(p_merchant_id uuid, p_default_level integer DEFAULT 3)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'items', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'id', p.id, 'name', p.name, 'name_ar', p.name_ar, 'barcode', p.barcode,
               'stock', p.stock_quantity,
               'reorder_level', COALESCE(p.reorder_level, p_default_level))
               ORDER BY p.stock_quantity ASC, p.name), '[]'::jsonb)
             FROM public.products p
             WHERE p.merchant_id = p_merchant_id AND p.is_available
               AND p.stock_quantity <= COALESCE(p.reorder_level, p_default_level)));
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_shortage_list(uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.cashier_set_reorder_level(p_merchant_id uuid, p_product_id uuid, p_level integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  UPDATE public.products SET reorder_level = p_level, updated_at = now()
   WHERE id = p_product_id AND merchant_id = p_merchant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;
  RETURN jsonb_build_object('ok', true);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_set_reorder_level(uuid, uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.cashier_device_link(p_license_key text, p_device_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_check jsonb;
  v_license record;
  v_merchant record;
BEGIN
  -- Activation + linking in one call: binds the device to the license (first
  -- contact), then hands the desktop app the merchant profile it needs to
  -- configure itself (store name/address/phone, catalog size).
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  v_check := public.cashier_license_validate(p_license_key, p_device_id);
  IF NOT (v_check->>'ok')::boolean THEN RETURN v_check; END IF;
  SELECT * INTO v_license FROM public.cashier_licenses WHERE license_key = p_license_key;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = v_license.merchant_id;
  INSERT INTO public.cashier_license_events (license_id, kind, detail)
  VALUES (v_license.id, 'linked', jsonb_build_object('device_id', p_device_id, 'uid', v_uid));
  RETURN jsonb_build_object(
    'ok', true,
    'plan', v_license.plan, 'status', v_license.status,
    'expires_at', v_license.expires_at,
    'grace_until', CASE WHEN v_license.expires_at IS NULL THEN NULL
                        ELSE v_license.expires_at + (v_license.grace_days || ' days')::interval END,
    'merchant', jsonb_build_object(
      'id', v_merchant.id, 'name', v_merchant.name, 'type', v_merchant.type,
      'phone', v_merchant.phone, 'address', v_merchant.address),
    'product_count', (SELECT count(*) FROM public.products p
                       WHERE p.merchant_id = v_merchant.id AND p.is_available));
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_device_link(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.cashier_sync_push(p_merchant_id uuid, p_ops jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_op jsonb;
  v_type text;
  v_op_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_sale_id uuid;
  v_shift_id uuid;
  v_merchant public.merchants%ROWTYPE;
  v_item jsonb;
  v_pay jsonb;
  v_deferred numeric;
  v_prod uuid;
  v_qty numeric;
  v_old_price numeric;
  v_new_price numeric;
  v_pct numeric;
  v_lines jsonb;
  v_subtotal numeric;
  v_rate numeric;
  v_primary_method text;
  v_company uuid;
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF jsonb_typeof(p_ops) <> 'array' THEN RAISE EXCEPTION 'ops must be an array'; END IF;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;

  FOR v_op IN SELECT * FROM jsonb_array_elements(p_ops) LOOP
    v_type := v_op->>'type';
    v_op_id := (v_op->>'op_id')::uuid;
    BEGIN
      CASE v_type
      WHEN 'customer' THEN
        INSERT INTO public.pos_customers (merchant_id, client_op_id, name, phone, notes)
        VALUES (p_merchant_id, v_op_id, v_op->'payload'->>'name', v_op->'payload'->>'phone', v_op->'payload'->>'notes')
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'shift_open' THEN
        v_shift_id := NULL;
        INSERT INTO public.pos_shifts (merchant_id, client_op_id, opened_by, opening_float, created_offline_at)
        VALUES (p_merchant_id, v_op_id, v_uid, COALESCE((v_op->'payload'->>'opening_float')::numeric, 0),
                (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING
        RETURNING id INTO v_shift_id;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'shift_id', v_shift_id);
      WHEN 'sale' THEN
        -- Offline sale recorded as fact into the shared pos_sales table:
        -- client totals (it computed them offline), line detail in items,
        -- idempotency via the op id. Stock decrements best-effort and every
        -- movement lands in pos_stock_moves so جرد reconciles later.
        v_sale_id := NULL;
        v_lines := '[]'::jsonb;
        v_subtotal := 0;
        v_deferred := 0;
        v_primary_method := NULL;
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'items') LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          v_qty := (v_item->>'qty')::numeric;
          v_lines := v_lines || jsonb_build_object(
            'product_id', v_prod,
            'drug_catalog_id', NULLIF(v_item->>'drug_catalog_id','')::uuid,
            'name', v_item->>'name',
            'qty', v_qty,
            'unit_price', (v_item->>'unit_price')::numeric,
            'discount', COALESCE((v_item->>'discount_amount')::numeric, 0),
            'line_total', (v_item->>'total')::numeric,
            'is_weight_based', COALESCE((v_item->>'is_weight_based')::boolean, false));
          v_subtotal := v_subtotal + (v_item->>'total')::numeric;
        END LOOP;
        INSERT INTO public.pos_sales
          (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
           payment_method, customer_name, notes, idempotency_key,
           shift_id, pos_customer_id, created_offline_at, created_at)
        VALUES
          (p_merchant_id, v_uid, v_lines,
           (v_op->'payload'->>'subtotal')::numeric,
           COALESCE((v_op->'payload'->>'discount_amount')::numeric, 0),
           (v_op->'payload'->>'total')::numeric,
           COALESCE(v_op->'payload'->'payments'->0->>'method', 'cash'),
           v_op->'payload'->>'customer_name',
           v_op->'payload'->>'notes', v_op_id::text,
           NULLIF(v_op->'payload'->>'shift_id','')::uuid,
           NULLIF(v_op->'payload'->>'customer_id','')::uuid,
           (v_op->>'created_offline_at')::timestamptz,
           COALESCE((v_op->>'created_offline_at')::timestamptz, now()))
        ON CONFLICT (idempotency_key) DO NOTHING
        RETURNING id INTO v_sale_id;
        IF v_sale_id IS NULL THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'duplicate', true);
          CONTINUE;
        END IF;
        -- Stock: best-effort decrement for tracked products.
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'items') LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          v_qty := (v_item->>'qty')::numeric;
          IF v_prod IS NOT NULL THEN
            UPDATE public.products SET stock_quantity = GREATEST(0, stock_quantity - v_qty::int), updated_at = now()
             WHERE id = v_prod AND stock_quantity IS NOT NULL;
            INSERT INTO public.pos_stock_moves (merchant_id, product_id, kind, qty, created_by, created_offline_at)
            VALUES (p_merchant_id, v_prod, 'sale', -v_qty, v_uid, (v_op->>'created_offline_at')::timestamptz);
          END IF;
        END LOOP;
        FOR v_pay IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'payments') LOOP
          INSERT INTO public.pos_sale_payments (sale_id, method, amount)
          VALUES (v_sale_id, v_pay->>'method', (v_pay->>'amount')::numeric);
          IF v_pay->>'method' = 'deferred' THEN v_deferred := v_deferred + (v_pay->>'amount')::numeric; END IF;
        END LOOP;
        IF v_deferred > 0 AND NULLIF(v_op->'payload'->>'customer_id','') IS NOT NULL THEN
          INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, sale_id, kind, amount, created_by, created_offline_at)
          VALUES (p_merchant_id, (v_op->'payload'->>'customer_id')::uuid,
                  v_sale_id, 'charge', v_deferred, v_uid, (v_op->>'created_offline_at')::timestamptz);
        END IF;
        -- Same commission posting as pos_create_sale.
        v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant.type, v_merchant.owner_user_id), 0);
        IF v_rate > 0 THEN
          INSERT INTO public.platform_commissions
            (member_id, reference_type, reference_id, gross_amount, commission_rate,
             commission_amount, net_amount, currency, status)
          VALUES (v_merchant.owner_user_id, 'pos_sale', v_sale_id,
                  (v_op->'payload'->>'total')::numeric, v_rate,
                  public.calculate_commission((v_op->'payload'->>'total')::numeric, v_rate),
                  (v_op->'payload'->>'total')::numeric -
                    public.calculate_commission((v_op->'payload'->>'total')::numeric, v_rate),
                  'EGP', 'computed')
          ON CONFLICT (reference_type, reference_id) DO NOTHING;
        END IF;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'sale_id', v_sale_id);
      WHEN 'sale_void' THEN
        SELECT id INTO v_sale_id FROM public.pos_sales
         WHERE merchant_id = p_merchant_id AND idempotency_key = (v_op->'payload'->>'sale_op_id')
           AND status = 'completed';
        IF v_sale_id IS NOT NULL THEN
          PERFORM public.pos_void_sale(v_sale_id, v_op->'payload'->>'reason');
          UPDATE public.pos_debt_ledger SET kind = 'payment', note = coalesce(note,'') || ' [void-reversal]'
           WHERE sale_id = v_sale_id AND kind = 'charge';
          INSERT INTO public.pos_stock_moves (merchant_id, kind, qty, note, created_by)
          VALUES (p_merchant_id, 'void_restore', 0, 'void of sale ' || v_sale_id::text, v_uid);
        END IF;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'sale_id', v_sale_id);
      WHEN 'debt_payment' THEN
        INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, client_op_id, kind, amount, note, created_by, created_offline_at)
        VALUES (p_merchant_id, (v_op->'payload'->>'customer_id')::uuid, v_op_id, 'payment',
                (v_op->'payload'->>'amount')::numeric, v_op->'payload'->>'note', v_uid,
                (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'stock_count' THEN
        v_prod := (v_op->'payload'->>'product_id')::uuid;
        v_qty := (v_op->'payload'->>'counted')::numeric;
        INSERT INTO public.pos_stock_moves (merchant_id, product_id, client_op_id, kind, qty, note, created_by, created_offline_at)
        VALUES (p_merchant_id, v_prod, v_op_id, 'count_adjustment',
                v_qty - COALESCE((SELECT stock_quantity FROM public.products WHERE id = v_prod), 0),
                v_op->'payload'->>'note', v_uid, (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        UPDATE public.products SET stock_quantity = v_qty::int, updated_at = now()
         WHERE id = v_prod AND merchant_id = p_merchant_id;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'price_change' THEN
        v_prod := (v_op->'payload'->>'product_id')::uuid;
        v_new_price := (v_op->'payload'->>'new_price')::numeric;
        SELECT price INTO v_old_price FROM public.products WHERE id = v_prod AND merchant_id = p_merchant_id;
        UPDATE public.products SET price = v_new_price, updated_at = now()
         WHERE id = v_prod AND merchant_id = p_merchant_id;
        INSERT INTO public.pos_price_history (merchant_id, product_id, old_price, new_price, source, changed_by)
        VALUES (p_merchant_id, v_prod, v_old_price, v_new_price, COALESCE(v_op->'payload'->>'source','manual'), v_uid);
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'bulk_price_pct' THEN
        v_pct := (v_op->'payload'->>'pct')::numeric;
        INSERT INTO public.pos_price_history (merchant_id, product_id, old_price, new_price, source, changed_by)
        SELECT p_merchant_id, id, price, round(price * (1 + v_pct / 100), 2), 'bulk_pct', v_uid
          FROM public.products WHERE merchant_id = p_merchant_id AND is_available;
        UPDATE public.products
           SET price = round(price * (1 + v_pct / 100), 2), updated_at = now()
         WHERE merchant_id = p_merchant_id AND is_available;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'insurance_sale' THEN
        -- Insured sale (تأمين): the insured part is billed to the company,
        -- the patient pays their share. Idempotent on the client op id.
        v_company := (v_op->'payload'->>'company_id')::uuid;
        v_sale_id := NULL;
        IF NULLIF(v_op->'payload'->>'sale_op_id','') IS NOT NULL THEN
          SELECT id INTO v_sale_id FROM public.pos_sales
           WHERE merchant_id = p_merchant_id
             AND idempotency_key = (v_op->'payload'->>'sale_op_id');
        END IF;
        INSERT INTO public.pos_insurance_sales
          (merchant_id, company_id, sale_id, client_op_id, member_name, member_card_no,
           total, company_share, patient_share, created_by, created_offline_at)
        VALUES
          (p_merchant_id, v_company, v_sale_id, v_op_id,
           v_op->'payload'->>'member_name', v_op->'payload'->>'member_card_no',
           (v_op->'payload'->>'total')::numeric,
           (v_op->'payload'->>'company_share')::numeric,
           (v_op->'payload'->>'patient_share')::numeric,
           v_uid, (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      ELSE
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false, 'reason', 'UNKNOWN_OP');
      END CASE;
    EXCEPTION WHEN OTHERS THEN
      v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false, 'reason', SQLERRM);
    END;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'results', v_results);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_sync_push(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.cashier_sync_pull(p_merchant_id uuid, p_since timestamptz DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'server_time', now(),
    'products', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.name, 'name_ar', p.name_ar, 'price', p.price,
        'stock', p.stock_quantity, 'reorder_level', p.reorder_level, 'barcode', p.barcode, 'updated_at', p.updated_at)), '[]'::jsonb)
       FROM public.products p
      WHERE p.merchant_id = p_merchant_id
        AND (p_since IS NULL OR p.updated_at > p_since)),
    'customers', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name, 'phone', c.phone,
        'balance', COALESCE((SELECT sum(CASE WHEN l.kind='charge' THEN l.amount ELSE -l.amount END)
                              FROM public.pos_debt_ledger l WHERE l.customer_id = c.id), 0))), '[]'::jsonb)
       FROM public.pos_customers c WHERE c.merchant_id = p_merchant_id AND c.is_active),
    'open_shift', (SELECT jsonb_build_object('id', s.id, 'opened_at', s.opened_at, 'opening_float', s.opening_float)
       FROM public.pos_shifts s WHERE s.merchant_id = p_merchant_id AND s.closed_at IS NULL
       ORDER BY s.opened_at DESC LIMIT 1)
  );
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_sync_pull(uuid, timestamptz) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
