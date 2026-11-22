-- 365: code-review fixes #33-#37 (admin RPC contract restores + POS stock safety)
-- #33 get_all_admins: restore extended 059 contract (id, full_name, region_id,
--     scope, supervisor_id) so AdminAccount.fromRpc can address an admin.
--     Keeps the 361 country-scope gate.
-- #34 admin_broadcast_notification: restore 126 audience matching (role OR
--     user_type, 'all'/blank), deep_link column + target_app metadata, and
--     count only active push tokens. Keeps the 361 country-scope gate.
-- #35 assign_admin_role(text): restore 126 lookup (email OR uuid OR phone)
--     and full role acceptance (member roles + super_admin), mapped onto the
--     current _admin_exec_* helpers. Keeps the 361 country-scope gate.
-- #36 cashier_sync_push: reject sales referencing another store's product;
--     scope every stock read/write to p_merchant_id; row-lock stock reads.
-- #37 duplicate-line void over-restore: stamp stock_applied by line ordinal
--     in the sync writer, and restore per-line applied amounts inside
--     pos_void_sale itself (drops the old post-void correction pass).
BEGIN;

-- ─── #33 ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_all_admins()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rows jsonb;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', u.id,
           'email', u.email,
           'full_name', u.full_name,
           'role', u.role,
           'is_active', COALESCE(m.is_active, true),
           'region_id', r.region_id,
           'region_name', r.region_name,
           'scope', r.scope,
           'supervisor_id', m.supervisor_id,
           'supervisor_email', su.email,
           'created_at', u.created_at)
         ORDER BY u.created_at), '[]'::jsonb)
    INTO v_rows
    FROM public.users u
    LEFT JOIN public.admin_management m ON m.admin_id = u.id
    LEFT JOIN public.users su ON su.id = m.supervisor_id
    LEFT JOIN LATERAL (
      SELECT aa.region_id,
             rr.name_en AS region_name,
             aa.scope
        FROM public.admin_region_assignments aa
        LEFT JOIN public.regions rr ON rr.id = aa.region_id
       WHERE aa.admin_id = u.id
       ORDER BY aa.created_at DESC
       LIMIT 1
    ) r ON true
   WHERE u.role IN ('owner','admin')
      OR m.admin_id IS NOT NULL;

  RETURN v_rows;
END;
$function$;

-- ─── #34 ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(p_title text, p_body text, p_type text DEFAULT 'info'::text, p_deep_link text DEFAULT NULL::text, p_target_role text DEFAULT NULL::text, p_target_user_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  matched_ids uuid[];
  device_count INTEGER;
  v_payload jsonb;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT array_agg(u.id) INTO matched_ids
  FROM public.users u
  WHERE (p_target_user_id IS NULL OR u.id = p_target_user_id)
    AND (
      p_target_role IS NULL
      OR btrim(p_target_role) = ''
      OR p_target_role = 'all'
      OR u.role = p_target_role
      OR u.user_type = p_target_role
    );

  v_payload := jsonb_strip_nulls(jsonb_build_object(
    'deep_link', p_deep_link,
    'target_app', COALESCE(NULLIF(p_target_role, ''), 'all')
  ));

  IF matched_ids IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, deep_link, data, is_read)
    SELECT
      unnest(matched_ids),
      p_title,
      p_body,
      COALESCE(NULLIF(p_type, ''), 'info'),
      p_deep_link,
      v_payload,
      false;
  END IF;

  SELECT COUNT(*) INTO device_count
  FROM public.notification_tokens t
  WHERE t.user_id = ANY(matched_ids)
    AND COALESCE(t.is_active, true) = true;

  RETURN COALESCE(device_count, 0);
END;
$function$;

-- ─── #35 ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.assign_admin_role(p_email text, p_role text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_user_type text;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_role NOT IN (
    'admin', 'super_admin',
    'country_admin', 'governorate_admin', 'center_admin', 'village_admin',
    'customer', 'driver', 'merchant', 'provider', 'delivery'
  ) THEN
    RAISE EXCEPTION 'Invalid role: %', p_role;
  END IF;

  -- #35: 126 lookup contract - email, member uuid (member drawer fallback),
  -- or phone.
  SELECT id INTO v_uid
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email))
      OR id::text = btrim(p_email)
      OR phone = btrim(p_email)
   LIMIT 1;
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  v_user_type := CASE
    WHEN p_role IN ('customer', 'driver', 'merchant', 'provider', 'delivery') THEN p_role
    ELSE 'admin'
  END;

  IF v_user_type = 'admin' THEN
    -- Admin-scope role names map onto the tree model: users.role stays
    -- 'admin', scope comes from the tree row + region assignments.
    IF EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = v_uid) THEN
      PERFORM public._admin_exec_role(auth.uid(), v_uid, 'admin', COALESCE(p_reason, 'Role updated'));
    ELSE
      PERFORM public._admin_exec_create(auth.uid(), v_uid, NULL, NULL, 'descendants');
    END IF;
  ELSE
    -- Demotion to a member role: _admin_exec_role removes the tree row,
    -- guards the owner, and audits.
    PERFORM public._admin_exec_role(auth.uid(), v_uid, p_role, COALESCE(p_reason, 'Role updated'));
  END IF;

  UPDATE public.users SET user_type = v_user_type WHERE id = v_uid;
END;
$function$;

-- ─── #36 + #37 (sync writer) ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cashier_sync_push(p_merchant_id uuid, p_ops jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
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
  v_server_price numeric;
  v_unit numeric;
  v_line_disc numeric;
  v_discount numeric;
  v_total numeric;
  v_applied numeric;
  v_prev_stock integer;
  v_idx integer;
  v_foreign boolean;
  v_cp boolean;
  v_line_repriced boolean;
  v_client_priced integer;
  v_repriced integer;
  v_server_total numeric;
  v_mismatch boolean;
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
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
        -- #36: reject any sale carrying a product id that belongs to another
        -- store; the stock writer below would otherwise decrement the foreign
        -- store's inventory. Unknown (deleted/offline-catalog) ids stay
        -- client-priced as before.
        v_foreign := false;
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'items') LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          IF v_prod IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.products fp
             WHERE fp.id = v_prod AND fp.merchant_id <> p_merchant_id
          ) THEN
            v_foreign := true;
            EXIT;
          END IF;
        END LOOP;
        IF v_foreign THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false,
            'reason', 'FOREIGN_PRODUCT');
          CONTINUE;
        END IF;
        -- Offline sale recorded as fact into the shared pos_sales table, but
        -- money is repriced SERVER-SIDE (review #26): any line whose
        -- product_id resolves is priced from public.products (through the
        -- shared _price_order_line helper for whole-number quantities), and
        -- commission is charged on the server total. Lines only the client
        -- could price (catalog-only offline drugs) are flagged client_priced
        -- and counted in the result for quarantine review.
        v_sale_id := NULL;
        v_lines := '[]'::jsonb;
        v_subtotal := 0;
        v_deferred := 0;
        v_primary_method := NULL;
        v_client_priced := 0;
        v_repriced := 0;
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'items') LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          v_qty := (v_item->>'qty')::numeric;
          v_unit := NULL;
          v_cp := false;
          v_line_repriced := false;
          IF v_prod IS NOT NULL THEN
            SELECT p.price INTO v_server_price
              FROM public.products p
             WHERE p.id = v_prod AND p.merchant_id = p_merchant_id;
            IF FOUND THEN
              v_unit := v_server_price;
              IF v_qty = trunc(v_qty) AND v_qty BETWEEN 1 AND 50 THEN
                BEGIN
                  v_unit := (public._price_order_line(p_merchant_id,
                    jsonb_build_object('product_id', v_prod, 'quantity', v_qty::int),
                    false)->>'unit_price')::numeric;
                EXCEPTION WHEN OTHERS THEN
                  -- Delisted or edge product: fall back to its last known price.
                  v_unit := v_server_price;
                END;
              END IF;
              IF v_unit IS DISTINCT FROM (v_item->>'unit_price')::numeric THEN
                v_line_repriced := true;
                v_repriced := v_repriced + 1;
              END IF;
            END IF;
          END IF;
          IF v_unit IS NULL THEN
            -- Offline-only drug with no store product row: only the client
            -- could price it. Keep the claimed price, flag the line.
            v_unit := (v_item->>'unit_price')::numeric;
            v_cp := true;
            v_client_priced := v_client_priced + 1;
          END IF;
          v_line_disc := LEAST(GREATEST(COALESCE((v_item->>'discount_amount')::numeric, 0), 0),
                               v_unit * v_qty);
          v_lines := v_lines || jsonb_build_object(
            'product_id', v_prod,
            'drug_catalog_id', NULLIF(v_item->>'drug_catalog_id','')::uuid,
            'name', v_item->>'name',
            'qty', v_qty,
            'unit_price', v_unit,
            'discount', v_line_disc,
            'line_total', v_unit * v_qty - v_line_disc,
            'is_weight_based', COALESCE((v_item->>'is_weight_based')::boolean, false),
            'client_priced', v_cp,
            'repriced', v_line_repriced);
          v_subtotal := v_subtotal + (v_unit * v_qty - v_line_disc);
        END LOOP;
        v_discount := LEAST(GREATEST(COALESCE((v_op->'payload'->>'discount_amount')::numeric, 0), 0),
                            v_subtotal);
        v_total := v_subtotal - v_discount;
        INSERT INTO public.pos_sales
          (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
           payment_method, customer_name, notes, idempotency_key,
           shift_id, pos_customer_id, created_offline_at, created_at,
           client_priced_lines)
        VALUES
          (p_merchant_id, v_uid, v_lines,
           v_subtotal, v_discount, v_total,
           COALESCE(v_op->'payload'->'payments'->0->>'method', 'cash'),
           v_op->'payload'->>'customer_name',
           v_op->'payload'->>'notes', v_op_id::text,
           NULLIF(v_op->'payload'->>'shift_id','')::uuid,
           NULLIF(v_op->'payload'->>'customer_id','')::uuid,
           (v_op->>'created_offline_at')::timestamptz,
           now(),
           v_client_priced)
        ON CONFLICT (idempotency_key) DO NOTHING
        RETURNING id INTO v_sale_id;
        IF v_sale_id IS NULL THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'duplicate', true);
          CONTINUE;
        END IF;
        -- Stock: best-effort decrement for tracked products. The APPLIED
        -- (clamped) decrement goes into the move so جرد reconciles, and the
        -- line carries stock_applied so a later void can't over-restore
        -- (review #31).
        FOR v_idx, v_item IN SELECT (t.ord - 1), t.value
              FROM jsonb_array_elements(v_op->'payload'->'items') WITH ORDINALITY AS t(value, ord) LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          v_qty := (v_item->>'qty')::numeric;
          IF v_prod IS NOT NULL THEN
            SELECT p.stock_quantity INTO v_prev_stock FROM public.products p
             WHERE p.id = v_prod AND p.merchant_id = p_merchant_id
             FOR UPDATE OF p;
            IF v_prev_stock IS NOT NULL THEN
              v_applied := LEAST(v_prev_stock, v_qty);
              UPDATE public.products
                 SET stock_quantity = GREATEST(0, stock_quantity - v_qty::int), updated_at = now()
               WHERE id = v_prod AND merchant_id = p_merchant_id;
              INSERT INTO public.pos_stock_moves (merchant_id, product_id, kind, qty, created_by, created_offline_at)
              VALUES (p_merchant_id, v_prod, 'sale', -v_applied, v_uid, (v_op->>'created_offline_at')::timestamptz);
              -- #37: stamp ONLY this line's ordinal; matching by product id
              -- stamped every unmarked duplicate line with the first line's
              -- applied amount, over-restoring on void.
              UPDATE public.pos_sales s
                 SET items = (SELECT jsonb_agg(CASE WHEN (t.ord - 1) = v_idx
                                                    THEN l || jsonb_build_object('stock_applied', v_applied)
                                                    ELSE l END ORDER BY t.ord)
                                FROM jsonb_array_elements(s.items) WITH ORDINALITY AS t(l, ord))
               WHERE s.id = v_sale_id;
            END IF;
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
        -- Same commission posting as pos_create_sale, on the SERVER total.
        v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant.type, v_merchant.owner_user_id), 0);
        IF v_rate > 0 THEN
          INSERT INTO public.platform_commissions
            (member_id, reference_type, reference_id, gross_amount, commission_rate,
             commission_amount, net_amount, currency, status)
          VALUES (v_merchant.owner_user_id, 'pos_sale', v_sale_id,
                  v_total, v_rate,
                  public.calculate_commission(v_total, v_rate),
                  v_total - public.calculate_commission(v_total, v_rate),
                  'EGP', 'computed')
          ON CONFLICT (reference_type, reference_id) DO NOTHING;
        END IF;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true,
          'sale_id', v_sale_id, 'total', v_total,
          'repriced', v_repriced, 'client_priced', v_client_priced);
      WHEN 'sale_void' THEN
        SELECT id INTO v_sale_id FROM public.pos_sales
         WHERE merchant_id = p_merchant_id AND idempotency_key = (v_op->'payload'->>'sale_op_id')
           AND status = 'completed';
        IF v_sale_id IS NOT NULL THEN
          PERFORM public.pos_void_sale(v_sale_id, v_op->'payload'->>'reason');
          -- #28: reverse أجل charges with explicit reversal entries (the old
          -- code flipped charges to payments, driving the balance negative).
          INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, sale_id, kind, amount, note, created_by)
          SELECT d.merchant_id, d.customer_id, d.sale_id, 'reversal', d.amount,
                 'عكس مديونية لإلغاء العملية', v_uid
            FROM public.pos_debt_ledger d
           WHERE d.sale_id = v_sale_id AND d.kind = 'charge'
             AND NOT EXISTS (SELECT 1 FROM public.pos_debt_ledger r
                              WHERE r.sale_id = d.sale_id AND r.kind = 'reversal');
          -- #37: pos_void_sale now restores each line's stamped
          -- stock_applied amount itself, so no post-void correction here.
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
                v_qty - COALESCE((SELECT stock_quantity FROM public.products WHERE id = v_prod AND merchant_id = p_merchant_id), 0),
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
        -- Review #32: the shares are client-claimed and feed
        -- pos_insurance_statement. They must at least sum to the claimed
        -- total; otherwise the op is rejected.
        IF abs(COALESCE((v_op->'payload'->>'company_share')::numeric, 0)
             + COALESCE((v_op->'payload'->>'patient_share')::numeric, 0)
             - (v_op->'payload'->>'total')::numeric) > 0.01 THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false,
            'reason', 'INSURANCE_SHARE_MISMATCH');
          CONTINUE;
        END IF;
        -- Review #32: when the linked sale resolved, compare the claimed
        -- total with the SERVER-repriced pos_sales total. A mismatch is
        -- quarantined (recorded with total_mismatch + the server total),
        -- same pattern as client_priced, never silently trusted.
        v_server_total := NULL;
        v_mismatch := false;
        IF v_sale_id IS NOT NULL THEN
          SELECT s.total_amount INTO v_server_total
            FROM public.pos_sales s WHERE s.id = v_sale_id;
          IF v_server_total IS NOT NULL
             AND abs(v_server_total - (v_op->'payload'->>'total')::numeric) > 0.01 THEN
            v_mismatch := true;
          END IF;
        END IF;
        INSERT INTO public.pos_insurance_sales
          (merchant_id, company_id, sale_id, client_op_id, member_name, member_card_no,
           total, company_share, patient_share, created_by, created_offline_at,
           server_total, total_mismatch)
        VALUES
          (p_merchant_id, v_company, v_sale_id, v_op_id,
           v_op->'payload'->>'member_name', v_op->'payload'->>'member_card_no',
           (v_op->'payload'->>'total')::numeric,
           (v_op->'payload'->>'company_share')::numeric,
           (v_op->'payload'->>'patient_share')::numeric,
           v_uid, (v_op->>'created_offline_at')::timestamptz,
           v_server_total, v_mismatch)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true,
          'server_total', v_server_total, 'total_mismatch', v_mismatch);
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

-- ─── #37 addendum (void path) ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.pos_void_sale(p_sale_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_sale public.pos_sales%ROWTYPE;
  v_merchant public.merchants%ROWTYPE;
  v_line jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  SELECT * INTO v_sale FROM public.pos_sales WHERE id = p_sale_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SALE_NOT_FOUND';
  END IF;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = v_sale.merchant_id;
  IF v_sale.cashier_user_id <> v_uid
     AND v_merchant.owner_user_id <> v_uid
     AND NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_sale.merchant_id))) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF v_sale.status = 'voided' THEN
    RETURN jsonb_build_object('ok', true, 'sale_id', v_sale.id, 'already_voided', true);
  END IF;

  -- Restore stock for tracked items only (NULL stock = untracked). #37:
  -- restore the line's stamped stock_applied (clamped) decrement when
  -- present, never the raw qty, and scope the write to this merchant (#36).
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_sale.items) LOOP
    UPDATE public.products
       SET stock_quantity = stock_quantity + COALESCE((v_line->>'stock_applied')::numeric,
                                                      (v_line->>'qty')::numeric)::int,
           updated_at = now()
     WHERE id = (v_line->>'product_id')::uuid
       AND merchant_id = v_sale.merchant_id
       AND stock_quantity IS NOT NULL;
  END LOOP;

  -- Reverse the still-open platform commission posting, if any.
  UPDATE public.platform_commissions
     SET status = 'reversed'
   WHERE reference_type = 'pos_sale'
     AND reference_id = v_sale.id
     AND status = 'computed';

  UPDATE public.pos_sales
     SET status = 'voided', voided_at = now(), voided_by = v_uid,
         void_reason = NULLIF(btrim(COALESCE(p_reason, '')), '')
   WHERE id = v_sale.id;

  RETURN jsonb_build_object('ok', true, 'sale_id', v_sale.id);
END;
$function$;
COMMIT;
