-- 205: Code-review fixes batch (reviewer findings 1-15, triaged and verified live).
-- HIGH-1: POS NULL stock = untracked/unlimited (RPC guard + no decrement).
-- MEDIUM-2: pos_create_sale idempotent replay returns stored totals.
-- HIGH-9: accept_order requires a pending dispatch offer for the caller's driver (owner exempt).
-- MEDIUM-3-of-batch-3 (#15): merchant + driver rating sync triggers (engine-managed columns had no engine).
-- MEDIUM-11: settlement sweep reactivation skips users with active sanctions.
-- LOW-4: pos_void_sale RPC (stock restore + commission reversal).
-- LOW-5: POS revenue/count fields in get_admin_analytics.
-- LOW-6/7: pharmacy_import_drug duplicate guard + no Arabic description dupe.

CREATE OR REPLACE FUNCTION public.pos_create_sale(p_merchant_id uuid, p_items jsonb, p_discount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_customer_name text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_qty int;
  v_subtotal numeric := 0;
  v_total numeric;
  v_discount numeric := 0;
  v_lines jsonb := '[]'::jsonb;
  v_sale_id uuid;
  v_existing uuid;
  v_rate numeric;
  v_commission numeric;
  v_touched int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_payment_method NOT IN ('cash', 'instapay', 'vodafone_cash') THEN
    RAISE EXCEPTION 'INVALID_PAYMENT_METHOD';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MERCHANT_NOT_FOUND';
  END IF;
  IF v_merchant.owner_user_id <> v_uid AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'NOT_YOUR_STORE';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing FROM public.pos_sales
      WHERE idempotency_key = p_idempotency_key;
    IF FOUND THEN
      RETURN (
        SELECT jsonb_build_object(
          'ok', true, 'sale_id', s.id, 'idempotent', true,
          'subtotal', s.subtotal, 'discount', s.discount,
          'total', s.total_amount, 'items', s.items)
        FROM public.pos_sales s WHERE s.id = v_existing);
    END IF;
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'EMPTY_CART';
  END IF;

  -- Price every line from the live products table; stock-check and decrement
  -- atomically so two tills cannot sell the same last unit.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := COALESCE((v_item->>'qty')::int, 0);
    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'INVALID_QTY';
    END IF;
    SELECT * INTO v_product FROM public.products
      WHERE id = (v_item->>'product_id')::uuid
        AND merchant_id = p_merchant_id
        AND is_available;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'PRODUCT_UNAVAILABLE';
    END IF;

    -- NULL stock_quantity means untracked inventory: always sellable, never decremented.
    IF v_product.stock_quantity IS NOT NULL THEN
      UPDATE public.products
         SET stock_quantity = stock_quantity - v_qty,
             updated_at = now()
       WHERE id = v_product.id
         AND stock_quantity >= v_qty;
      GET DIAGNOSTICS v_touched = ROW_COUNT;
      IF v_touched = 0 THEN
        RAISE EXCEPTION 'INSUFFICIENT_STOCK';
      END IF;
    END IF;

    v_subtotal := v_subtotal + (v_product.price * v_qty);
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product.id,
      'name', v_product.name,
      'name_ar', v_product.name_ar,
      'qty', v_qty,
      'unit_price', v_product.price,
      'line_total', v_product.price * v_qty
    );
  END LOOP;

  v_discount := LEAST(GREATEST(COALESCE(p_discount, 0), 0), v_subtotal);
  v_total := v_subtotal - v_discount;

  INSERT INTO public.pos_sales
    (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
     payment_method, customer_name, notes, idempotency_key)
  VALUES
    (p_merchant_id, v_uid, v_lines, v_subtotal, v_discount, v_total,
     p_payment_method, NULLIF(btrim(COALESCE(p_customer_name, '')), ''),
     p_notes, p_idempotency_key)
  RETURNING id INTO v_sale_id;

  -- Same commission posting as orders/bookings: merchant owes the platform
  -- its rate on the walk-in gross, once.
  v_rate := COALESCE(
    public.get_commission_rate('merchant', v_merchant.type, v_merchant.owner_user_id), 0);
  IF v_rate > 0 THEN
    v_commission := public.calculate_commission(v_total, v_rate);
    INSERT INTO public.platform_commissions
      (member_id, reference_type, reference_id, gross_amount, commission_rate,
       commission_amount, net_amount, currency, status)
    VALUES (v_merchant.owner_user_id, 'pos_sale', v_sale_id, v_total, v_rate,
            v_commission, v_total - v_commission, 'EGP', 'computed')
    ON CONFLICT (reference_type, reference_id) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'sale_id', v_sale_id,
    'subtotal', v_subtotal,
    'discount', v_discount,
    'total', v_total,
    'items', v_lines
  );
END;
$function$;
CREATE OR REPLACE FUNCTION public.accept_order(p_order_id uuid, p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_order orders%ROWTYPE;
BEGIN
  -- Authorization: the driver must exist and belong to the caller, or the
  -- caller must be a global owner operating the dispatch console.
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF v_order.dispatch_status <> 'PENDING_DISPATCH' OR v_order.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'STALE', 'dispatch_status', v_order.dispatch_status);
  END IF;
  -- Non-owner callers may only accept an offer actually pending for their driver.
  IF NOT public._is_owner_uid(auth.uid()) AND NOT EXISTS (
    SELECT 1 FROM public.order_dispatch
     WHERE order_id = p_order_id
       AND candidate_driver_id = p_driver_id
       AND status IN ('pending', 'offered')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NO_PENDING_OFFER');
  END IF;
  UPDATE public.orders
    SET driver_id = p_driver_id, dispatch_status = 'ASSIGNED', status = 'preparing'
    WHERE id = p_order_id;
  UPDATE public.order_dispatch
    SET status = 'accepted', candidate_driver_id = p_driver_id, updated_at = now()
    WHERE order_id = p_order_id;
  PERFORM public.log_admin_action('DISPATCH_ACCEPT', 'order', p_order_id::text,
    NULL, jsonb_build_object('driver', p_driver_id), NULL, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$function$;
CREATE OR REPLACE FUNCTION public.pharmacy_import_drug(p_drug_id uuid, p_merchant_id uuid, p_price numeric DEFAULT NULL::numeric, p_stock integer DEFAULT 0)
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

  -- Duplicate guard: re-importing the same drug returns the existing product.
  SELECT id INTO v_product_id FROM public.products
   WHERE merchant_id = p_merchant_id
     AND ((v_drug.barcode IS NOT NULL AND barcode = v_drug.barcode)
          OR (v_drug.barcode IS NULL
              AND name = v_drug.name_en || COALESCE(' ' || v_drug.strength, '')))
   ORDER BY created_at
   LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'product_id', v_product_id, 'duplicate', true);
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
    NULL,
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
CREATE OR REPLACE FUNCTION public.get_admin_analytics(date_from timestamp with time zone DEFAULT NULL::timestamp with time zone, date_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_from TIMESTAMPTZ := COALESCE(date_from, NOW() - INTERVAL '30 days');
  v_to   TIMESTAMPTZ := COALESCE(date_to, NOW());
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN jsonb_build_object(
    -- All-time true totals (key names preserved for existing callers)
    'total_orders',    (SELECT COUNT(*) FROM public.orders),
    'total_revenue',   (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'delivered'),
    'total_users',     (SELECT COUNT(*) FROM public.users),
    'total_drivers',   (SELECT COUNT(*) FROM public.drivers),
    'total_merchants', (SELECT COUNT(*) FROM public.merchants),
    -- Windowed values, explicitly labeled
    'window_orders',        (SELECT COUNT(*) FROM public.orders WHERE created_at BETWEEN v_from AND v_to),
    'window_revenue',       (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'delivered' AND created_at BETWEEN v_from AND v_to),
    'window_new_users',     (SELECT COUNT(*) FROM public.users WHERE created_at BETWEEN v_from AND v_to),
    'window_new_drivers',   (SELECT COUNT(*) FROM public.drivers WHERE created_at BETWEEN v_from AND v_to),
    'window_new_merchants', (SELECT COUNT(*) FROM public.merchants WHERE created_at BETWEEN v_from AND v_to),
    -- POS walk-in revenue (status 'completed' excludes voided sales)
    'pos_revenue_total',  (SELECT COALESCE(SUM(total_amount), 0) FROM public.pos_sales WHERE status = 'completed'),
    'pos_sales_count',    (SELECT COUNT(*) FROM public.pos_sales WHERE status = 'completed'),
    'pos_revenue_window', (SELECT COALESCE(SUM(total_amount), 0) FROM public.pos_sales WHERE status = 'completed' AND created_at BETWEEN v_from AND v_to),
    'window_from', v_from,
    'window_to',   v_to
  );
END;
$function$;
CREATE OR REPLACE FUNCTION public._settlement_escalation_sweep()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_cfg public.platform_settings;
  ob RECORD;
  v_count integer := 0;
  v_driver RECORD;
  v_amount numeric;
  v_days integer;
BEGIN
  PERFORM set_config('app.escalation_rpc', 'true', true);
  SELECT * INTO v_cfg FROM public._settlement_settings();
  v_amount := COALESCE(v_cfg.settlement_suspension_amount, 1500);
  v_days := COALESCE(v_cfg.settlement_suspension_days, 5);

  -- 1) Overdue individual obligations -> ops complaint (unchanged behavior)
  FOR ob IN
    SELECT o.*, d.user_id AS driver_uid
      FROM public.driver_obligations o
      JOIN public.drivers d ON d.id = o.driver_id
     WHERE o.status = 'open'
       AND o.escalated_at IS NULL
       AND o.due_at + make_interval(hours => COALESCE(v_cfg.settlement_escalation_hours, 24)) < now()
  LOOP
    INSERT INTO public.complaints
      (order_id, ride_id, complainant_id, respondent_id, reporter_id,
       complaint_type, category, subject, description, status, priority)
    VALUES
      (ob.order_id, ob.ride_id, ob.driver_uid, ob.driver_uid, ob.driver_uid,
       'driver', 'settlement_overdue',
       'مديونية كاش متأخرة',
       'الكابتن متأخر عن توريد ' || ob.amount::text || ' ' || ob.currency ||
         ' (نوع: ' || ob.kind || '، مستحق لـ ' || ob.owed_to || ') منذ ' ||
         ob.due_at::date::text || '.',
       'pending', 'high');
    UPDATE public.driver_obligations SET escalated_at = now() WHERE id = ob.id;
    v_count := v_count + 1;
  END LOOP;

  -- 2) Outstanding > suspension amount -> auto-suspend 5 days
  FOR v_driver IN
    SELECT o.driver_id, d.user_id AS driver_uid,
           sum(o.amount) FILTER (WHERE o.status IN ('open','disputed')) AS outstanding
      FROM public.driver_obligations o
      JOIN public.drivers d ON d.id = o.driver_id
     WHERE o.status IN ('open','disputed')
     GROUP BY o.driver_id, d.user_id
    HAVING sum(o.amount) FILTER (WHERE o.status IN ('open','disputed')) > v_amount
  LOOP
    -- Skip if already suspended for settlement and still within the window
    IF EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = v_driver.driver_id
        AND d.settlement_suspended_until IS NOT NULL
        AND d.settlement_suspended_until > now()
    ) THEN
      CONTINUE;
    END IF;

    UPDATE public.drivers
       SET settlement_suspended_until = now() + make_interval(days => v_days),
           is_online = false
     WHERE id = v_driver.driver_id;
    UPDATE public.users
       SET account_status = 'suspended'
     WHERE id = v_driver.driver_uid
       AND account_status = 'active';

    INSERT INTO public.notifications (user_id, title, body, type, data, priority)
    VALUES (
      v_driver.driver_uid,
      'إيقاف مؤقت لمدة ' || v_days || ' أيام',
      'تم إيقاف حسابك ' || v_days || ' أيام لأن المديونية غير الموردة تجاوزت ' ||
        v_amount::text || ' جنيه. الإجمالي القائم: ' ||
        COALESCE(v_driver.outstanding,0)::text || ' جنيه. قم بالتوريد لاستعادة حسابك.',
      'settlement_suspension',
      jsonb_build_object('driver_id', v_driver.driver_id,
                         'outstanding', v_driver.outstanding,
                         'suspended_days', v_days),
      'high');
    v_count := v_count + 1;

    -- Ops audit trail (kept from previous behavior)
    IF NOT EXISTS (
      SELECT 1 FROM public.complaints c
       WHERE c.respondent_id = v_driver.driver_uid
         AND c.category = 'settlement_suspension_review'
         AND c.status IN ('pending','investigating','escalated','open')
    ) THEN
      INSERT INTO public.complaints
        (complainant_id, respondent_id, reporter_id, complaint_type, category,
         subject, description, status, priority)
      VALUES
        (v_driver.driver_uid, v_driver.driver_uid, v_driver.driver_uid,
         'driver', 'settlement_suspension_review',
         'إيقاف كابتن لتجاوز حد التسوية',
         'تم إيقاف الكابتن ' || v_days || ' أيام: مديونية غير موردة ' ||
           COALESCE(v_driver.outstanding,0)::text || ' جنيه (الحد: ' || v_amount::text || ').',
         'pending', 'urgent');
      v_count := v_count + 1;
    END IF;
  END LOOP;

  -- 3) Reactivate drivers whose suspension expired and balance is back in limit.
  --    If still over the limit at expiry, extend the suspension another window.
  FOR v_driver IN
    SELECT d.id AS driver_id, d.user_id AS driver_uid, d.settlement_suspended_until,
           COALESCE((SELECT sum(o.amount) FROM public.driver_obligations o
                      WHERE o.driver_id = d.id AND o.status IN ('open','disputed')), 0) AS outstanding
      FROM public.drivers d
     WHERE d.settlement_suspended_until IS NOT NULL
       AND d.settlement_suspended_until <= now()
  LOOP
    IF v_driver.outstanding > v_amount THEN
      UPDATE public.drivers
         SET settlement_suspended_until = now() + make_interval(days => v_days)
       WHERE id = v_driver.driver_id;
      v_count := v_count + 1;
    ELSE
      UPDATE public.drivers SET settlement_suspended_until = NULL WHERE id = v_driver.driver_id;
      -- Do not revive a user suspended by ops for a different reason.
      UPDATE public.users
         SET account_status = 'active'
       WHERE id = v_driver.driver_uid
         AND account_status = 'suspended'
         AND NOT EXISTS (
           SELECT 1 FROM public.sanctions s
            WHERE s.target_user_id = v_driver.driver_uid
              AND s.is_active);
      INSERT INTO public.notifications (user_id, title, body, type, data, priority)
      VALUES (
        v_driver.driver_uid,
        'تمت استعادة حسابك',
        'انتهت فترة الإيقاف ومديونيتك الحالية ' || v_driver.outstanding::text ||
          ' جنيه ضمن الحد المسموح. يمكنك استقبال الطلبات من جديد.',
        'settlement_reactivation',
        jsonb_build_object('driver_id', v_driver.driver_id,
                           'outstanding', v_driver.outstanding),
        'high');
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$function$;
ALTER TABLE public.pos_sales
  ADD COLUMN IF NOT EXISTS voided_at timestamptz,
  ADD COLUMN IF NOT EXISTS voided_by uuid,
  ADD COLUMN IF NOT EXISTS void_reason text;

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
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF v_sale.status = 'voided' THEN
    RETURN jsonb_build_object('ok', true, 'sale_id', v_sale.id, 'already_voided', true);
  END IF;

  -- Restore stock for tracked items only (NULL stock = untracked).
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_sale.items) LOOP
    UPDATE public.products
       SET stock_quantity = stock_quantity + COALESCE((v_line->>'qty')::int, 0),
           updated_at = now()
     WHERE id = (v_line->>'product_id')::uuid
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
-- Rating engines: merchants.rating/total_reviews and drivers.rating are
-- guarded as engine-managed, but no engine recomputed them.
CREATE OR REPLACE FUNCTION public._sync_merchant_rating()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_merchant uuid := COALESCE(NEW.merchant_id, OLD.merchant_id);
BEGIN
  UPDATE public.merchants m
     SET rating = COALESCE((
           SELECT round(avg(r.rating)::numeric, 1)
             FROM public.reviews r
            WHERE r.merchant_id = v_merchant), 0),
         total_reviews = (
           SELECT count(*) FROM public.reviews r
            WHERE r.merchant_id = v_merchant)
   WHERE m.id = v_merchant;
  RETURN COALESCE(NEW, OLD);
END;
$function$;
DROP TRIGGER IF EXISTS trg_reviews_sync_merchant ON public.reviews;
CREATE TRIGGER trg_reviews_sync_merchant
  AFTER INSERT OR DELETE OR UPDATE OF rating ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public._sync_merchant_rating();

CREATE OR REPLACE FUNCTION public._sync_driver_rating()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride uuid := COALESCE(NEW.ride_id, OLD.ride_id);
  v_driver uuid;
BEGIN
  SELECT r.driver_id INTO v_driver FROM public.rides r WHERE r.id = v_ride;
  IF v_driver IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  UPDATE public.drivers d
     SET rating = COALESCE((
           SELECT round(avg(x.stars)::numeric, 1)
             FROM public.ride_ratings x
             JOIN public.rides rr ON rr.id = x.ride_id
            WHERE rr.driver_id = v_driver
              AND x.ratee_role = 'driver'), 0)
   WHERE d.id = v_driver;
  RETURN COALESCE(NEW, OLD);
END;
$function$;
DROP TRIGGER IF EXISTS trg_ride_ratings_sync_driver ON public.ride_ratings;
CREATE TRIGGER trg_ride_ratings_sync_driver
  AFTER INSERT OR DELETE OR UPDATE OF stars ON public.ride_ratings
  FOR EACH ROW EXECUTE FUNCTION public._sync_driver_rating();

REVOKE ALL ON FUNCTION public._sync_merchant_rating() FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public._sync_driver_rating() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_void_sale(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
