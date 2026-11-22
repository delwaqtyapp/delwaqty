-- 340 (owner GO 2026-11-22 03:16): pharmacy/retail cashier CORE schema.
-- Offline-first desktop POS syncing to Supabase. Sales land in the EXISTING
-- pos_sales table (migration 201: same table the merchant web POS and admin
-- dashboards read) with the same commission posting and void semantics as
-- pos_create_sale/pos_void_sale; this migration adds what the offline
-- cashier needs around them: device-bound licenses with trial + offline
-- grace, shifts (drawer + daily close), أجل customer debt ledger, split
-- payments detail, stock moves (جرد/صرف/returns), price history, and an
-- idempotent outbox push/pull sync pair keyed by client op ids.

ALTER TABLE public.pos_sales
  ADD COLUMN IF NOT EXISTS shift_id uuid,
  ADD COLUMN IF NOT EXISTS pos_customer_id uuid,
  ADD COLUMN IF NOT EXISTS created_offline_at timestamptz;

CREATE TABLE public.cashier_licenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  license_key text NOT NULL UNIQUE,
  plan text NOT NULL CHECK (plan IN ('trial','core_monthly','core_quarterly','core_semiannual','core_annual','core_lifetime')),
  status text NOT NULL DEFAULT 'issued' CHECK (status IN ('issued','active','expired','suspended')),
  device_id text,
  issued_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz,
  expires_at timestamptz,
  grace_days integer NOT NULL DEFAULT 3,
  created_by uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.cashier_licenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY cashier_licenses_owner_read ON public.cashier_licenses FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin());
CREATE POLICY cashier_licenses_admin_write ON public.cashier_licenses FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE TABLE public.cashier_license_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  license_id uuid NOT NULL REFERENCES public.cashier_licenses(id) ON DELETE CASCADE,
  kind text NOT NULL,
  detail jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.cashier_license_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY cashier_license_events_owner_read ON public.cashier_license_events FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.cashier_licenses l WHERE l.id = license_id
                 AND (public.is_merchant_owner(l.merchant_id) OR public.is_admin())));

CREATE TABLE public.pos_customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  client_op_id uuid,
  name text NOT NULL,
  phone text,
  notes text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, client_op_id)
);
ALTER TABLE public.pos_customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY pos_customers_owner ON public.pos_customers FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR public.is_admin());

CREATE TABLE public.pos_shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  client_op_id uuid,
  opened_by uuid REFERENCES public.users(id),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  opening_float numeric(12,2) NOT NULL DEFAULT 0,
  closing_cash numeric(12,2),
  expected_cash numeric(12,2),
  totals jsonb NOT NULL DEFAULT '{}',
  created_offline_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, client_op_id)
);
ALTER TABLE public.pos_shifts ENABLE ROW LEVEL SECURITY;
CREATE POLICY pos_shifts_owner ON public.pos_shifts FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR public.is_admin());

-- Split payments detail (cash + InstaPay + Vodafone Cash + deferred أجل).
CREATE TABLE public.pos_sale_payments (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sale_id uuid NOT NULL REFERENCES public.pos_sales(id) ON DELETE CASCADE,
  method text NOT NULL CHECK (method IN ('cash','instapay','vodafone_cash','card','deferred')),
  amount numeric(12,2) NOT NULL CHECK (amount >= 0)
);
ALTER TABLE public.pos_sale_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY pos_sale_payments_owner ON public.pos_sale_payments FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.id = sale_id
                 AND (public.is_merchant_owner(s.merchant_id) OR public.is_admin())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.id = sale_id
                 AND (public.is_merchant_owner(s.merchant_id) OR public.is_admin())));

-- أجل ledger: charges (deferred sales) and payments per POS customer.
CREATE TABLE public.pos_debt_ledger (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES public.pos_customers(id) ON DELETE CASCADE,
  sale_id uuid REFERENCES public.pos_sales(id),
  client_op_id uuid,
  kind text NOT NULL CHECK (kind IN ('charge','payment')),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  note text,
  created_by uuid REFERENCES public.users(id),
  created_offline_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, client_op_id)
);
ALTER TABLE public.pos_debt_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY pos_debt_ledger_owner ON public.pos_debt_ledger FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR public.is_admin());

CREATE TABLE public.pos_stock_moves (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id),
  drug_catalog_id uuid REFERENCES public.drug_catalog(id),
  client_op_id uuid,
  kind text NOT NULL CHECK (kind IN ('sale','restock','count_adjustment','return','dispense','void_restore')),
  qty numeric(10,3) NOT NULL,
  note text,
  created_by uuid REFERENCES public.users(id),
  created_offline_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, client_op_id)
);
ALTER TABLE public.pos_stock_moves ENABLE ROW LEVEL SECURITY;
CREATE POLICY pos_stock_moves_owner ON public.pos_stock_moves FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR public.is_admin());

CREATE TABLE public.pos_price_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id),
  old_price numeric(12,2),
  new_price numeric(12,2) NOT NULL,
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','bulk_pct','moh_update')),
  changed_by uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.pos_price_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY pos_price_history_owner ON public.pos_price_history FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR public.is_admin());

CREATE TABLE public._cashier_keys (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  license_hmac_key text NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public._cashier_keys DEFAULT VALUES ON CONFLICT DO NOTHING;
REVOKE ALL ON public._cashier_keys FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.cashier_license_issue(
  p_merchant_id uuid, p_plan text, p_days integer DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_days integer;
  v_payload text;
  v_sig text;
  v_key text;
  v_id uuid;
  v_expires timestamptz;
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_plan NOT IN ('trial','core_monthly','core_quarterly','core_semiannual','core_annual','core_lifetime') THEN
    RAISE EXCEPTION 'Invalid plan %', p_plan;
  END IF;
  v_days := COALESCE(p_days, CASE p_plan
    WHEN 'trial' THEN 30 WHEN 'core_monthly' THEN 30 WHEN 'core_quarterly' THEN 90
    WHEN 'core_semiannual' THEN 180 WHEN 'core_annual' THEN 365 ELSE NULL END);
  v_expires := CASE WHEN v_days IS NULL THEN NULL ELSE now() + (v_days || ' days')::interval END;
  v_id := gen_random_uuid();
  v_payload := v_id::text || '|' || p_merchant_id::text || '|' || p_plan || '|' ||
               COALESCE(v_expires::text, 'lifetime');
  SELECT encode(extensions.hmac(v_payload, k.license_hmac_key, 'sha256'), 'hex')
    INTO v_sig FROM public._cashier_keys k WHERE k.id;
  v_key := 'DLWQ1.' || replace(replace(encode(convert_to(v_payload, 'UTF8'), 'base64'), '+', '-'), '/', '_') || '.' || v_sig;
  INSERT INTO public.cashier_licenses (id, merchant_id, license_key, plan, status, expires_at, created_by)
  VALUES (v_id, p_merchant_id, v_key, p_plan,
          CASE WHEN p_plan = 'trial' THEN 'active' ELSE 'issued' END,
          v_expires, v_uid);
  INSERT INTO public.cashier_license_events (license_id, kind, detail)
  VALUES (v_id, 'issued', jsonb_build_object('plan', p_plan, 'expires_at', v_expires));
  RETURN jsonb_build_object('ok', true, 'license_id', v_id, 'license_key', v_key,
                            'plan', p_plan, 'expires_at', v_expires);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_license_issue(uuid, text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.cashier_license_validate(p_license_key text, p_device_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_l record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_l FROM public.cashier_licenses WHERE license_key = p_license_key FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'reason', 'UNKNOWN_KEY'); END IF;
  IF NOT (public.is_admin() OR public.is_merchant_owner(v_l.merchant_id)) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_AUTHORIZED');
  END IF;
  IF v_l.status = 'suspended' THEN RETURN jsonb_build_object('ok', false, 'reason', 'SUSPENDED'); END IF;
  IF v_l.device_id IS NULL AND p_device_id IS NOT NULL THEN
    -- First contact binds the device, whatever the starting status was
    -- (trial keys start active, paid keys start issued).
    UPDATE public.cashier_licenses
       SET status = 'active', activated_at = COALESCE(activated_at, now()),
           device_id = p_device_id, updated_at = now()
     WHERE id = v_l.id;
    INSERT INTO public.cashier_license_events (license_id, kind, detail)
    VALUES (v_l.id, 'activated', jsonb_build_object('device_id', p_device_id));
  ELSIF p_device_id IS NOT NULL AND v_l.device_id <> p_device_id THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'BOUND_TO_OTHER_DEVICE');
  END IF;
  IF v_l.expires_at IS NOT NULL AND v_l.expires_at < now() THEN
    UPDATE public.cashier_licenses SET status = 'expired', updated_at = now() WHERE id = v_l.id;
    RETURN jsonb_build_object('ok', false, 'reason', 'EXPIRED',
      'grace_until', v_l.expires_at + (v_l.grace_days || ' days')::interval);
  END IF;
  RETURN jsonb_build_object('ok', true, 'plan', v_l.plan, 'status', 'active',
    'expires_at', v_l.expires_at, 'merchant_id', v_l.merchant_id);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_license_validate(text, text) TO authenticated;

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

CREATE OR REPLACE FUNCTION public.cashier_daily_close(p_merchant_id uuid, p_shift_id uuid, p_closing_cash numeric)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_shift record;
  v_cash numeric; v_sales numeric; v_count integer;
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_shift FROM public.pos_shifts
   WHERE id = p_shift_id AND merchant_id = p_merchant_id AND closed_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'reason', 'SHIFT_NOT_OPEN'); END IF;
  SELECT COALESCE(sum(s.total_amount), 0), count(*) INTO v_sales, v_count
    FROM public.pos_sales s WHERE s.shift_id = p_shift_id AND s.status = 'completed';
  SELECT COALESCE(sum(p.amount), 0) INTO v_cash
    FROM public.pos_sale_payments p JOIN public.pos_sales s ON s.id = p.sale_id
   WHERE s.shift_id = p_shift_id AND s.status = 'completed' AND p.method = 'cash';
  -- Sales synced from the web POS have no pos_sale_payments rows; count their
  -- cash through the single payment_method column.
  v_cash := v_cash + COALESCE((SELECT sum(s.total_amount) FROM public.pos_sales s
    WHERE s.shift_id = p_shift_id AND s.status = 'completed' AND s.payment_method = 'cash'
      AND NOT EXISTS (SELECT 1 FROM public.pos_sale_payments p WHERE p.sale_id = s.id)), 0);
  UPDATE public.pos_shifts
     SET closed_at = now(), closing_cash = p_closing_cash,
         expected_cash = v_shift.opening_float + v_cash,
         totals = jsonb_build_object('sales_total', v_sales, 'sale_count', v_count,
                                     'cash_in', v_cash, 'opening_float', v_shift.opening_float)
   WHERE id = p_shift_id;
  RETURN jsonb_build_object('ok', true, 'expected_cash', v_shift.opening_float + v_cash,
                            'sales_total', v_sales, 'sale_count', v_count);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_daily_close(uuid, uuid, numeric) TO authenticated;

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
        'stock', p.stock_quantity, 'barcode', p.barcode, 'updated_at', p.updated_at)), '[]'::jsonb)
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
