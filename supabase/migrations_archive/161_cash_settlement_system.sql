-- 161_cash_settlement_system.sql
-- Cash settlement system (design doc v2, owner-approved 2026-11-20):
--   * driver cash ceiling EGP 1000, remittance due 24h, escalation 24h after
--     due, suspension review at 3 days overdue or EGP 5000 outstanding.
--   * ALL numbers live in platform_settings (admin-editable), never hardcoded
--     in logic below: every read goes through _settlement_settings().
--   * BOTH settlement models: 'platform' (default) and 'direct', chosen per
--     merchant. Regional admin physically receives model-A remittances with
--     mutual confirmation codes. Phase-2 pre-funded deposit is NOT here.
-- Design-only money rule: no real transfer/charge/payout is executed here;
-- every table records obligations and ledger entries for human settlement.

-- ============================================================================
-- 1. Settings (single-row platform_settings table; new typed columns)
-- ============================================================================
ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS settlement_driver_cash_ceiling numeric NOT NULL DEFAULT 1000,
  ADD COLUMN IF NOT EXISTS settlement_remittance_due_hours integer NOT NULL DEFAULT 24,
  ADD COLUMN IF NOT EXISTS settlement_escalation_hours integer NOT NULL DEFAULT 24,
  ADD COLUMN IF NOT EXISTS settlement_suspension_days integer NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS settlement_suspension_amount numeric NOT NULL DEFAULT 5000,
  ADD COLUMN IF NOT EXISTS settlement_payout_cadence text NOT NULL DEFAULT 'daily';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'platform_settings_payout_cadence_check'
  ) THEN
    ALTER TABLE public.platform_settings
      ADD CONSTRAINT platform_settings_payout_cadence_check
      CHECK (settlement_payout_cadence IN ('daily','weekly','biweekly'));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public._settlement_settings()
RETURNS public.platform_settings
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT * FROM public.platform_settings ORDER BY id LIMIT 1;
$function$;

-- ============================================================================
-- 2. Merchant settlement model choice
-- ============================================================================
ALTER TABLE public.merchants
  ADD COLUMN IF NOT EXISTS settlement_model text NOT NULL DEFAULT 'platform';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'merchants_settlement_model_check'
  ) THEN
    ALTER TABLE public.merchants
      ADD CONSTRAINT merchants_settlement_model_check
      CHECK (settlement_model IN ('platform','direct'));
  END IF;
END $$;

-- ============================================================================
-- 3. driver_obligations: one row per debt unit (goods / commission)
--    Amounts are immutable; corrections are reversing rows (kind 'reversal').
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.driver_obligations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id),
  ride_id uuid REFERENCES public.rides(id),
  order_id uuid REFERENCES public.orders(id),
  merchant_id uuid REFERENCES public.merchants(id),
  kind text NOT NULL DEFAULT 'goods' CHECK (kind IN ('goods','commission','reversal')),
  amount numeric NOT NULL CHECK (amount >= 0),
  currency text NOT NULL DEFAULT 'EGP',
  owed_to text NOT NULL CHECK (owed_to IN ('platform','merchant')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','settled','disputed','waived')),
  due_at timestamptz NOT NULL,
  settlement_code text,
  settled_at timestamptz,
  settled_via text,
  dispute_reason text,
  escalated_at timestamptz,
  reminded_due_soon_at timestamptz,
  reminded_overdue_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
-- One obligation per (ride, kind) keeps _record_delivery_earnings idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS driver_obligations_ride_kind_uidx
  ON public.driver_obligations (ride_id, kind) WHERE ride_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS driver_obligations_driver_status_idx
  ON public.driver_obligations (driver_id, status);
CREATE INDEX IF NOT EXISTS driver_obligations_merchant_idx
  ON public.driver_obligations (merchant_id) WHERE merchant_id IS NOT NULL;

-- ============================================================================
-- 4. merchant_ledger: the merchant receivables book (model A + online orders)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.merchant_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id),
  order_id uuid REFERENCES public.orders(id),
  entry_type text NOT NULL CHECK (entry_type IN ('credit','debit','reversal')),
  amount numeric NOT NULL CHECK (amount >= 0),
  currency text NOT NULL DEFAULT 'EGP',
  description text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS merchant_ledger_order_credit_uidx
  ON public.merchant_ledger (order_id, entry_type)
  WHERE order_id IS NOT NULL AND entry_type = 'credit';
CREATE INDEX IF NOT EXISTS merchant_ledger_merchant_idx
  ON public.merchant_ledger (merchant_id);

-- ============================================================================
-- 5. merchant_payout_requests: daily-cadence payout, admin-approved
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.merchant_payout_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id),
  amount numeric NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'EGP',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  requested_by uuid NOT NULL,
  reviewed_by uuid,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS merchant_payout_requests_merchant_idx
  ON public.merchant_payout_requests (merchant_id, status);

-- ============================================================================
-- 6. Hook: obligation + ledger creation inside _record_delivery_earnings
--    (idempotent: unique indexes above make re-runs no-ops)
-- ============================================================================
CREATE OR REPLACE FUNCTION public._record_delivery_earnings(p_ride_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r public.rides%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_merchant_type text;
  v_merchant_model text;
  v_rate numeric;
  v_gross numeric;
  v_commission numeric;
  v_driver_commission numeric;
  v_currency text;
  v_due_hours integer;
  v_goods numeric;
  v_is_cash boolean;
BEGIN
  SELECT * INTO r FROM public.rides WHERE id = p_ride_id;
  IF NOT FOUND OR r.driver_id IS NULL THEN
    RETURN;
  END IF;
  -- Idempotent: one earning/commission pair per ride.
  IF EXISTS (SELECT 1 FROM public.driver_earnings WHERE ride_id = p_ride_id) THEN
    RETURN;
  END IF;

  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = r.driver_id;
  v_currency := COALESCE(NULLIF(r.currency, ''), 'EGP');
  v_is_cash := lower(COALESCE(r.payment_method, '')) = 'cash';

  -- Driver: earns the delivery fare minus the driver-rate commission.
  v_gross := COALESCE(r.fare, 0);
  v_rate := COALESCE(public.get_commission_rate('driver', NULL, v_driver_uid), 0);
  v_commission := public.calculate_commission(v_gross, v_rate);
  v_driver_commission := v_commission;

  INSERT INTO public.driver_earnings (driver_id, ride_id, type, amount, currency, description)
  VALUES (r.driver_id, p_ride_id, 'trip', v_gross - v_commission, v_currency,
          'Delivery fare ' || v_gross::text || ' less ' || v_rate::text || '% platform commission');

  INSERT INTO public.platform_commissions
    (member_id, reference_type, reference_id, gross_amount, commission_rate,
     commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'ride', p_ride_id, v_gross, v_rate, v_commission,
          v_gross - v_commission, v_currency, 'computed')
  ON CONFLICT (reference_type, reference_id) DO NOTHING;

  -- Merchant: commission on the goods subtotal for merchant orders.
  IF r.order_id IS NOT NULL THEN
    SELECT * INTO v_order FROM public.orders WHERE id = r.order_id;
    IF FOUND AND v_order.merchant_id IS NOT NULL THEN
      SELECT owner_user_id, type, settlement_model
        INTO v_merchant_uid, v_merchant_type, v_merchant_model
        FROM public.merchants WHERE id = v_order.merchant_id;
      IF v_merchant_uid IS NOT NULL THEN
        v_gross := COALESCE(v_order.subtotal, 0);
        v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant_type, v_merchant_uid), 0);
        v_commission := public.calculate_commission(v_gross, v_rate);
        INSERT INTO public.platform_commissions
          (member_id, reference_type, reference_id, gross_amount, commission_rate,
           commission_amount, net_amount, currency, status)
        VALUES (v_merchant_uid, 'order', v_order.id, v_gross, v_rate, v_commission,
                v_gross - v_commission, v_currency, 'computed')
        ON CONFLICT (reference_type, reference_id) DO NOTHING;

        IF v_is_cash THEN
          SELECT settlement_remittance_due_hours INTO v_due_hours
            FROM public._settlement_settings();
          v_due_hours := COALESCE(v_due_hours, 24);

          -- Goods money: order value minus the delivery fee (driver keeps the
          -- fare side). Owed to the platform (model A) or the merchant (B).
          v_goods := GREATEST(
            COALESCE(v_order.total_amount, 0) - COALESCE(v_order.delivery_fee, 0), 0);
          IF v_goods > 0 THEN
            INSERT INTO public.driver_obligations
              (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
               owed_to, due_at)
            VALUES
              (r.driver_id, p_ride_id, v_order.id, v_order.merchant_id, 'goods',
               v_goods, v_currency,
               CASE WHEN v_merchant_model = 'direct' THEN 'merchant' ELSE 'platform' END,
               now() + make_interval(hours => v_due_hours))
            ON CONFLICT (ride_id, kind) WHERE ride_id IS NOT NULL DO NOTHING;

            INSERT INTO public.notifications
              (user_id, title, body, type, data, send_push)
            SELECT v_driver_uid,
                   'تسوية كاش مستحقة',
                   'قبضت ' || v_goods::text || ' ' || v_currency ||
                     ' من الطلب. التوريد مستحق خلال ' || v_due_hours::text || ' ساعة.',
                   'settlement',
                   jsonb_build_object('ride_id', p_ride_id, 'amount', v_goods),
                   true
            WHERE NOT EXISTS (
              SELECT 1 FROM public.notifications n
               WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
                 AND n.data->>'ride_id' = p_ride_id::text
            );
          END IF;

          -- Model A: platform owes the merchant goods minus its commission.
          IF v_merchant_model IS DISTINCT FROM 'direct' THEN
            INSERT INTO public.merchant_ledger
              (merchant_id, order_id, entry_type, amount, currency, description)
            VALUES
              (v_order.merchant_id, v_order.id, 'credit',
               v_gross - v_commission, v_currency,
               'Order goods ' || v_gross::text || ' less ' || v_rate::text || '% platform commission')
            ON CONFLICT (order_id, entry_type)
              WHERE order_id IS NOT NULL AND entry_type = 'credit'
              DO NOTHING;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;

  -- Cash rides of any kind: the platform's driver-side commission is debt
  -- until remitted (pure cash rides have no goods obligation).
  IF v_is_cash AND v_driver_commission > 0 THEN
    SELECT settlement_remittance_due_hours INTO v_due_hours
      FROM public._settlement_settings();
    INSERT INTO public.driver_obligations
      (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
       owed_to, due_at)
    VALUES
      (r.driver_id, p_ride_id, r.order_id, r.merchant_id, 'commission',
       v_driver_commission, v_currency, 'platform',
       now() + make_interval(hours => COALESCE(v_due_hours, 24)))
    ON CONFLICT (ride_id, kind) WHERE ride_id IS NOT NULL DO NOTHING;
  END IF;
END;
$function$;

-- ============================================================================
-- 7. Dispatch gate: over-ceiling / overdue drivers are excluded from CASH
--    dispatches only. Disputed rows count at half weight (design 4.5).
-- ============================================================================
CREATE OR REPLACE FUNCTION public._dispatch_delivery_internal(p_ride_id uuid, p_radius_km numeric DEFAULT 10, p_limit integer DEFAULT 5)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride RECORD;
  v_driver RECORD;
  v_offered_count INTEGER := 0;
  v_found_any BOOLEAN := false;
  v_is_cash BOOLEAN := false;
  v_ceiling numeric;
BEGIN
  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;
  IF v_ride.status != 'searching' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_searching');
  END IF;

  v_is_cash := lower(COALESCE(v_ride.payment_method, '')) = 'cash'
    OR EXISTS (
      SELECT 1 FROM public.orders o
       WHERE o.id = v_ride.order_id AND lower(COALESCE(o.payment_method,'')) = 'cash'
    );
  IF v_is_cash THEN
    SELECT settlement_driver_cash_ceiling INTO v_ceiling
      FROM public._settlement_settings();
    v_ceiling := COALESCE(v_ceiling, 1000);
  END IF;

  UPDATE public.ride_requests SET status='expired',responded_at=now()
    WHERE ride_id=p_ride_id AND status='offered' AND expires_at <= now();

  FOR v_driver IN
    SELECT d.id, d.user_id,
      haversine_km(v_ride.pickup_latitude, v_ride.pickup_longitude,
                   d.current_latitude, d.current_longitude) AS dist_km
    FROM drivers d
    WHERE d.status = 'online'
      AND d.location_updated_at > now() - interval '2 minutes'
      AND d.is_verified = true
      AND d.is_active = true
      -- Only active engagements exclude: an offer that EXPIRED unanswered may
      -- be re-offered (automatic retry); a rejected, accepted or cancelled
      -- one may not.
      AND NOT EXISTS (SELECT 1 FROM public.ride_requests previous WHERE previous.ride_id=p_ride_id AND previous.driver_id=d.id AND previous.status IN ('offered','accepted','rejected','cancelled'))
      AND NOT EXISTS (SELECT 1 FROM public.rides busy WHERE busy.driver_id=d.id AND busy.status IN ('matched','arrived','inTrip'))
      AND d.active_vehicle_id IS NOT NULL
      AND d.active_vehicle_id IN (
        SELECT v.id FROM vehicles v
        WHERE v.driver_id = d.id
          AND v.is_active = true
          AND (v.category = v_ride.ride_type OR v_ride.service_type != 'ride')
      )
      AND (d.accepts_deliveries = true OR v_ride.service_type = 'ride')
      AND d.current_latitude IS NOT NULL
      AND d.current_longitude IS NOT NULL
      AND haversine_km(v_ride.pickup_latitude, v_ride.pickup_longitude,
                       d.current_latitude, d.current_longitude) <= p_radius_km
      -- Settlement gate (cash only): no overdue open obligation and the
      -- weighted open total (open=1x, disputed=0.5x) stays within the ceiling.
      AND (
        NOT v_is_cash
        OR (
          NOT EXISTS (
            SELECT 1 FROM public.driver_obligations ob
             WHERE ob.driver_id = d.id AND ob.status = 'open' AND ob.due_at < now()
          )
          AND COALESCE((
            SELECT sum(CASE WHEN ob.status = 'open' THEN ob.amount ELSE ob.amount / 2 END)
              FROM public.driver_obligations ob
             WHERE ob.driver_id = d.id AND ob.status IN ('open','disputed')
          ), 0) <= v_ceiling
        )
      )
    ORDER BY dist_km ASC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 5), 30))
  LOOP
    -- The (ride_id, driver_id) uniqueness means a re-offer revives the
    -- expired row with a fresh window instead of inserting a twin.
    INSERT INTO ride_requests (ride_id, driver_id, status, distance_km, offered_at, expires_at)
    VALUES (
      p_ride_id, v_driver.id, 'offered', v_driver.dist_km,
      NOW(), NOW() + interval '20 seconds'
    )
    ON CONFLICT (ride_id, driver_id) DO UPDATE
      SET status = 'offered', distance_km = EXCLUDED.distance_km,
          offered_at = NOW(), expires_at = NOW() + interval '20 seconds',
          responded_at = NULL;
    v_offered_count := v_offered_count + 1;
    v_found_any := true;
  END LOOP;

  IF NOT v_found_any AND EXISTS (
    SELECT 1 FROM public.ride_requests WHERE ride_id=p_ride_id
      AND status='offered' AND expires_at > now()
  ) THEN
    RETURN jsonb_build_object('success', true, 'offered_to', 0, 'reason', 'offers_pending');
  END IF;
  IF NOT v_found_any THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_drivers_available');
  END IF;

  RETURN jsonb_build_object('success', true, 'offered_to', v_offered_count);
END;
$function$;

-- ============================================================================
-- 8. Escalation sweep (event-driven: called from dispatch + read RPCs; no
--    server timers). Overdue by escalation_hours -> admin complaint.
--    Suspension thresholds open a review complaint; a human suspends.
-- ============================================================================
CREATE OR REPLACE FUNCTION public._settlement_escalation_sweep()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cfg public.platform_settings;
  ob RECORD;
  v_count integer := 0;
  v_driver RECORD;
BEGIN
  -- Engine-origin marker so complaints_fixup_insert keeps our priority/status
  -- (transaction-local; honored only from definer engine RPCs like this one).
  PERFORM set_config('app.escalation_rpc', 'true', true);
  SELECT * INTO v_cfg FROM public._settlement_settings();

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

  -- Suspension review: 3+ days overdue on any row, or total outstanding over
  -- the configured amount. Opens ONE review complaint per driver at a time.
  FOR v_driver IN
    SELECT o.driver_id, d.user_id AS driver_uid,
           bool_or(o.status = 'open' AND o.due_at + make_interval(days => COALESCE(v_cfg.settlement_suspension_days, 3)) < now()) AS long_overdue,
           sum(o.amount) FILTER (WHERE o.status IN ('open','disputed')) AS outstanding
      FROM public.driver_obligations o
      JOIN public.drivers d ON d.id = o.driver_id
     WHERE o.status IN ('open','disputed')
     GROUP BY o.driver_id, d.user_id
    HAVING bool_or(o.status = 'open' AND o.due_at + make_interval(days => COALESCE(v_cfg.settlement_suspension_days, 3)) < now())
        OR sum(o.amount) FILTER (WHERE o.status IN ('open','disputed')) > COALESCE(v_cfg.settlement_suspension_amount, 5000)
  LOOP
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
         'مراجعة إيقاف حساب كابتن',
         'تجاوز حدود التسوية (تأخير ' || COALESCE(v_cfg.settlement_suspension_days,3)::text ||
           ' أيام أو مديونية ' || COALESCE(v_cfg.settlement_suspension_amount,5000)::text ||
           '). الإجمالي القائم: ' || COALESCE(v_driver.outstanding,0)::text || ' جنيه.',
         'pending', 'urgent');
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$function$;

-- ============================================================================
-- 9. Settlement RPCs
-- ============================================================================

-- Merchant chooses his model; switching to 'direct' is blocked while the
-- platform still owes him (design 1: money never changes route mid-way).
CREATE OR REPLACE FUNCTION public.merchant_set_settlement_model(p_model text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_merchant public.merchants%ROWTYPE;
  v_balance numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_model NOT IN ('platform','direct') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_MODEL');
  END IF;
  SELECT * INTO v_merchant FROM public.merchants
   WHERE owner_user_id = auth.uid() LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NO_MERCHANT');
  END IF;
  IF p_model = 'direct' AND v_merchant.settlement_model IS DISTINCT FROM 'direct' THEN
    SELECT COALESCE(sum(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0)
      INTO v_balance
      FROM public.merchant_ledger WHERE merchant_id = v_merchant.id;
    IF v_balance > 0 THEN
      RETURN jsonb_build_object('ok', false, 'code', 'UNPAID_BALANCE', 'balance', v_balance);
    END IF;
  END IF;
  UPDATE public.merchants SET settlement_model = p_model, updated_at = now()
   WHERE id = v_merchant.id;
  RETURN jsonb_build_object('ok', true, 'model', p_model);
END;
$function$;

-- Model A: regional admin (or platform admin) hands the driver a one-time
-- 4-digit code after physically receiving the cash.
CREATE OR REPLACE FUNCTION public.admin_create_settlement_code(p_obligation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ob public.driver_obligations%ROWTYPE;
  v_code text;
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.admin_region_assignments WHERE admin_id = auth.uid())
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  SELECT * INTO v_ob FROM public.driver_obligations WHERE id = p_obligation_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF v_ob.status <> 'open' OR v_ob.owed_to <> 'platform' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  v_code := lpad(floor(random() * 10000)::int::text, 4, '0');
  UPDATE public.driver_obligations
     SET settlement_code = v_code, updated_at = now()
   WHERE id = p_obligation_id;
  RETURN jsonb_build_object('ok', true, 'code', v_code);
END;
$function$;

-- Driver closes the remittance with the code he was handed.
CREATE OR REPLACE FUNCTION public.driver_confirm_settlement(p_obligation_id uuid, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ob public.driver_obligations%ROWTYPE;
BEGIN
  SELECT * INTO v_ob FROM public.driver_obligations WHERE id = p_obligation_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.drivers d WHERE d.id = v_ob.driver_id AND d.user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF v_ob.status <> 'open' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  IF v_ob.settlement_code IS NULL OR v_ob.settlement_code <> p_code THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_CODE');
  END IF;
  UPDATE public.driver_obligations
     SET status = 'settled', settled_at = now(), settled_via = 'admin_code',
         settlement_code = NULL, updated_at = now()
   WHERE id = p_obligation_id;
  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- Model B: merchant confirms the driver paid him directly.
CREATE OR REPLACE FUNCTION public.merchant_confirm_obligation_paid(p_obligation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ob public.driver_obligations%ROWTYPE;
BEGIN
  SELECT * INTO v_ob FROM public.driver_obligations WHERE id = p_obligation_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.merchants m
     WHERE m.id = v_ob.merchant_id AND m.owner_user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF v_ob.status <> 'open' OR v_ob.owed_to <> 'merchant' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  UPDATE public.driver_obligations
     SET status = 'settled', settled_at = now(), settled_via = 'merchant_confirm',
         updated_at = now()
   WHERE id = p_obligation_id;
  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- Model B: merchant reports non-payment -> admin complaint (design 4.5).
CREATE OR REPLACE FUNCTION public.merchant_report_obligation_unpaid(p_obligation_id uuid, p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ob public.driver_obligations%ROWTYPE;
  v_merchant_uid uuid;
  v_driver_uid uuid;
BEGIN
  SELECT * INTO v_ob FROM public.driver_obligations WHERE id = p_obligation_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  SELECT owner_user_id INTO v_merchant_uid FROM public.merchants
   WHERE id = v_ob.merchant_id;
  IF auth.uid() IS NULL OR v_merchant_uid IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF v_ob.status <> 'open' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = v_ob.driver_id;
  INSERT INTO public.complaints
    (order_id, ride_id, complainant_id, respondent_id, reporter_id,
     complaint_type, category, subject, description, status, priority)
  VALUES
    (v_ob.order_id, v_ob.ride_id, v_merchant_uid, v_driver_uid, v_merchant_uid,
     'driver', 'settlement_unpaid',
     'التاجر يبلّغ: الكابتن لم يسدّد',
       'مديونية ' || v_ob.amount::text || ' ' || v_ob.currency ||
       ' عن الطلب ' || COALESCE(v_ob.order_id::text, '-') ||
       COALESCE('. ملاحظة التاجر: ' || p_note, ''),
     'pending', 'high');
  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- Driver disputes the amount (dispatch gate weighs it at half).
CREATE OR REPLACE FUNCTION public.dispute_obligation(p_obligation_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ob public.driver_obligations%ROWTYPE;
BEGIN
  SELECT * INTO v_ob FROM public.driver_obligations WHERE id = p_obligation_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.drivers d WHERE d.id = v_ob.driver_id AND d.user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF v_ob.status <> 'open' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  UPDATE public.driver_obligations
     SET status = 'disputed', dispute_reason = p_reason, updated_at = now()
   WHERE id = p_obligation_id;
  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- Admin-only write-off; recorded, never deleted (design 4.6).
CREATE OR REPLACE FUNCTION public.admin_waive_obligation(p_obligation_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  UPDATE public.driver_obligations
     SET status = 'waived', updated_at = now()
   WHERE id = p_obligation_id AND status IN ('open','disputed');
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  PERFORM public.log_admin_action('OBLIGATION_WAIVED', 'driver_obligation',
    p_obligation_id::text, NULL, jsonb_build_object('reason', p_reason), p_reason, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- Driver's own obligations; doubles as the event that runs the sweep and the
-- due-soon / overdue reminder ladder (no server timers).
CREATE OR REPLACE FUNCTION public.get_my_obligations()
RETURNS SETOF public.driver_obligations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_driver_id uuid;
  v_driver_uid uuid := auth.uid();
  ob RECORD;
BEGIN
  IF v_driver_uid IS NULL THEN
    RETURN;
  END IF;
  PERFORM public._settlement_escalation_sweep();
  SELECT id INTO v_driver_id FROM public.drivers WHERE user_id = v_driver_uid;
  IF v_driver_id IS NULL THEN
    RETURN;
  END IF;

  -- Reminder ladder: 4h before due, then once when overdue.
  FOR ob IN
    SELECT * FROM public.driver_obligations
     WHERE driver_id = v_driver_id AND status = 'open'
       AND due_at - interval '4 hours' < now() AND reminded_due_soon_at IS NULL
       AND due_at > now()
  LOOP
    INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
    VALUES (v_driver_uid, 'تذكير بتسوية كاش',
            'فاضل أقل من ٤ ساعات على استحقاق توريد ' || ob.amount::text || ' ' || ob.currency || '.',
            'settlement', jsonb_build_object('obligation_id', ob.id), true);
    UPDATE public.driver_obligations SET reminded_due_soon_at = now() WHERE id = ob.id;
  END LOOP;

  FOR ob IN
    SELECT * FROM public.driver_obligations
     WHERE driver_id = v_driver_id AND status = 'open'
       AND due_at < now() AND reminded_overdue_at IS NULL
  LOOP
    INSERT INTO public.notifications (user_id, title, body, type, data, send_push, priority)
    VALUES (v_driver_uid, 'مديونية متأخرة',
            'عدّى ميعاد توريد ' || ob.amount::text || ' ' || ob.currency ||
              '. سددها عشان تفضل قادر تاخد طلبات كاش.',
            'settlement', jsonb_build_object('obligation_id', ob.id), true, 'high');
    UPDATE public.driver_obligations SET reminded_overdue_at = now() WHERE id = ob.id;
  END LOOP;

  RETURN QUERY
    SELECT * FROM public.driver_obligations
     WHERE driver_id = v_driver_id
     ORDER BY created_at DESC;
END;
$function$;

-- Merchant payout request (model A). Cadence is advisory (daily default);
-- every request still needs admin approval, like wallet top-ups.
CREATE OR REPLACE FUNCTION public.merchant_request_payout(p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_merchant public.merchants%ROWTYPE;
  v_balance numeric;
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  SELECT * INTO v_merchant FROM public.merchants
   WHERE owner_user_id = auth.uid() LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NO_MERCHANT');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  END IF;
  SELECT COALESCE(sum(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0)
    INTO v_balance
    FROM public.merchant_ledger WHERE merchant_id = v_merchant.id;
  IF p_amount > v_balance THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INSUFFICIENT_BALANCE', 'balance', v_balance);
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.merchant_payout_requests
     WHERE merchant_id = v_merchant.id AND status = 'pending'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'PENDING_EXISTS');
  END IF;
  INSERT INTO public.merchant_payout_requests (merchant_id, amount, requested_by)
  VALUES (v_merchant.id, p_amount, auth.uid())
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_review_payout(p_request_id uuid, p_approve boolean, p_reason text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_req public.merchant_payout_requests%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  SELECT * INTO v_req FROM public.merchant_payout_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  UPDATE public.merchant_payout_requests
     SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
         reviewed_by = auth.uid(), reviewed_at = now(), rejection_reason = p_reason
   WHERE id = p_request_id;
  IF p_approve THEN
    INSERT INTO public.merchant_ledger
      (merchant_id, entry_type, amount, currency, description, created_by)
    VALUES
      (v_req.merchant_id, 'debit', v_req.amount, v_req.currency,
       'Payout request ' || p_request_id::text, auth.uid());
  END IF;
  PERFORM public.log_admin_action(
    CASE WHEN p_approve THEN 'PAYOUT_APPROVED' ELSE 'PAYOUT_REJECTED' END,
    'merchant_payout_request', p_request_id::text, NULL,
    jsonb_build_object('amount', v_req.amount, 'reason', p_reason), p_reason, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- Merchant view of his own ledger + balance.
CREATE OR REPLACE FUNCTION public.get_my_merchant_ledger()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_merchant_id uuid;
  v_balance numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  SELECT id INTO v_merchant_id FROM public.merchants WHERE owner_user_id = auth.uid() LIMIT 1;
  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NO_MERCHANT');
  END IF;
  SELECT COALESCE(sum(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0)
    INTO v_balance FROM public.merchant_ledger WHERE merchant_id = v_merchant_id;
  RETURN jsonb_build_object(
    'ok', true, 'balance', v_balance,
    'entries', COALESCE((
      SELECT jsonb_agg(row_to_json(l) ORDER BY l.created_at DESC)
        FROM (SELECT * FROM public.merchant_ledger
               WHERE merchant_id = v_merchant_id
               ORDER BY created_at DESC LIMIT 100) l
    ), '[]'::jsonb)
  );
END;
$function$;

-- ============================================================================
-- 10. RLS: read-only for owners; all writes through the definer RPCs above
-- ============================================================================
ALTER TABLE public.driver_obligations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_payout_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_obligations_read_own ON public.driver_obligations;
CREATE POLICY driver_obligations_read_own ON public.driver_obligations
  FOR SELECT TO authenticated USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.drivers d
                WHERE d.id = driver_id AND d.user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.merchants m
                WHERE m.id = merchant_id AND m.owner_user_id = auth.uid())
  );

DROP POLICY IF EXISTS merchant_ledger_read_own ON public.merchant_ledger;
CREATE POLICY merchant_ledger_read_own ON public.merchant_ledger
  FOR SELECT TO authenticated USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.merchants m
                WHERE m.id = merchant_id AND m.owner_user_id = auth.uid())
  );

DROP POLICY IF EXISTS merchant_payout_requests_read_own ON public.merchant_payout_requests;
CREATE POLICY merchant_payout_requests_read_own ON public.merchant_payout_requests
  FOR SELECT TO authenticated USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.merchants m
                WHERE m.id = merchant_id AND m.owner_user_id = auth.uid())
  );

REVOKE INSERT, UPDATE, DELETE ON public.driver_obligations FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.merchant_ledger FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.merchant_payout_requests FROM authenticated, anon;

REVOKE EXECUTE ON FUNCTION public.admin_create_settlement_code(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_waive_obligation(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_payout(uuid, boolean, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public._settlement_escalation_sweep() FROM authenticated, anon;
REVOKE EXECUTE ON FUNCTION public._settlement_settings() FROM authenticated, anon;
