-- 172_order_settlement_accrual.sql
-- Bughunt F5: orders that complete WITHOUT a rides row (merchant-completes
-- the order) accrued nothing: no driver earnings, no commission rows, no
-- cash obligations, no merchant ledger credit. The ride path already accrues
-- via _record_delivery_earnings (mig 161). This migration adds an
-- order-scoped accrual mirroring 161's logic, fired by a trigger on
-- orders.status -> 'delivered', with a cross-check that skips orders whose
-- linked ride already accrued. Ledger rows only; no money moves.

-- 1. driver_earnings can reference an order directly.
ALTER TABLE public.driver_earnings
  ADD COLUMN IF NOT EXISTS order_id uuid REFERENCES public.orders(id);
CREATE UNIQUE INDEX IF NOT EXISTS driver_earnings_order_uidx
  ON public.driver_earnings (order_id) WHERE order_id IS NOT NULL;

-- 2. platform_commissions: driver-side commission on an order needs its own
--    reference_type ('order' is used for the merchant-side row; the pair
--    (reference_type, reference_id) is unique).
ALTER TABLE public.platform_commissions
  DROP CONSTRAINT IF EXISTS platform_commissions_reference_type_check;
ALTER TABLE public.platform_commissions
  ADD CONSTRAINT platform_commissions_reference_type_check
  CHECK (reference_type IN ('order', 'order_driver', 'ride', 'service_booking'));

-- 3. driver_obligations: unique per (order_id, kind) for order-scoped rows
--    (ride-scoped rows already have (ride_id, kind)).
CREATE UNIQUE INDEX IF NOT EXISTS driver_obligations_order_kind_uidx
  ON public.driver_obligations (order_id, kind)
  WHERE ride_id IS NULL AND order_id IS NOT NULL;

-- 4. Order-scoped accrual. Mirrors _record_delivery_earnings (161) with the
--    order as the source of truth. Driver earns the delivery fee less the
--    driver commission; merchant accrues commission on the goods subtotal;
--    cash orders create goods + commission obligations and (platform model)
--    a merchant ledger credit. Idempotent per order.
CREATE OR REPLACE FUNCTION public._record_order_settlement(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  o public.orders%ROWTYPE;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_merchant_type text;
  v_merchant_model text;
  v_rate numeric;
  v_gross numeric;
  v_commission numeric;
  v_driver_commission numeric;
  v_currency text := 'EGP';
  v_due_hours integer;
  v_goods numeric;
  v_is_cash boolean;
BEGIN
  SELECT * INTO o FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND OR o.status <> 'delivered' OR o.driver_id IS NULL THEN
    RETURN;
  END IF;
  -- Idempotent: one accrual per order, regardless of path.
  IF EXISTS (SELECT 1 FROM public.driver_earnings WHERE order_id = p_order_id) THEN
    RETURN;
  END IF;
  -- A linked ride already accrued for this order (147/161 ride path).
  IF EXISTS (
    SELECT 1 FROM public.driver_earnings de
    JOIN public.rides r ON r.id = de.ride_id
    WHERE r.order_id = p_order_id
  ) THEN
    RETURN;
  END IF;

  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = o.driver_id;
  v_is_cash := lower(COALESCE(o.payment_method, '')) = 'cash';

  -- Driver: earns the delivery fee minus the driver-rate commission.
  v_gross := COALESCE(o.delivery_fee, 0);
  v_rate := COALESCE(public.get_commission_rate('driver', NULL, v_driver_uid), 0);
  v_commission := public.calculate_commission(v_gross, v_rate);
  v_driver_commission := v_commission;

  INSERT INTO public.driver_earnings (driver_id, order_id, type, amount, currency, description)
  VALUES (o.driver_id, p_order_id, 'trip', v_gross - v_commission, v_currency,
          'Order delivery fee ' || v_gross::text || ' less ' || v_rate::text || '% platform commission');

  INSERT INTO public.platform_commissions
    (member_id, reference_type, reference_id, gross_amount, commission_rate,
     commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'order_driver', p_order_id, v_gross, v_rate, v_commission,
          v_gross - v_commission, v_currency, 'computed')
  ON CONFLICT (reference_type, reference_id) DO NOTHING;

  -- Merchant: commission on the goods subtotal.
  IF o.merchant_id IS NOT NULL THEN
    SELECT owner_user_id, type, settlement_model
      INTO v_merchant_uid, v_merchant_type, v_merchant_model
      FROM public.merchants WHERE id = o.merchant_id;
    IF v_merchant_uid IS NOT NULL THEN
      v_gross := COALESCE(o.subtotal, 0);
      v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant_type, v_merchant_uid), 0);
      v_commission := public.calculate_commission(v_gross, v_rate);
      INSERT INTO public.platform_commissions
        (member_id, reference_type, reference_id, gross_amount, commission_rate,
         commission_amount, net_amount, currency, status)
      VALUES (v_merchant_uid, 'order', p_order_id, v_gross, v_rate, v_commission,
              v_gross - v_commission, v_currency, 'computed')
      ON CONFLICT (reference_type, reference_id) DO NOTHING;

      IF v_is_cash THEN
        SELECT settlement_remittance_due_hours INTO v_due_hours
          FROM public._settlement_settings();
        v_due_hours := COALESCE(v_due_hours, 24);

        -- Goods money owed by the driver (order value minus the delivery fee).
        v_goods := GREATEST(
          COALESCE(o.total_amount, 0) - COALESCE(o.delivery_fee, 0), 0);
        IF v_goods > 0 THEN
          INSERT INTO public.driver_obligations
            (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
             owed_to, due_at)
          VALUES
            (o.driver_id, NULL, p_order_id, o.merchant_id, 'goods',
             v_goods, v_currency,
             CASE WHEN v_merchant_model = 'direct' THEN 'merchant' ELSE 'platform' END,
             now() + make_interval(hours => v_due_hours))
          ON CONFLICT (order_id, kind) WHERE ride_id IS NULL AND order_id IS NOT NULL DO NOTHING;

          INSERT INTO public.notifications
            (user_id, title, body, type, data, send_push)
          SELECT v_driver_uid,
                 'تسوية كاش مستحقة',
                 'قبضت ' || v_goods::text || ' ' || v_currency ||
                   ' من الطلب. التوريد مستحق خلال ' || v_due_hours::text || ' ساعة.',
                 'settlement',
                 jsonb_build_object('order_id', p_order_id, 'amount', v_goods),
                 true
          WHERE NOT EXISTS (
            SELECT 1 FROM public.notifications n
             WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
               AND n.data->>'order_id' = p_order_id::text
          );
        END IF;

        -- Platform model: platform owes the merchant goods minus commission.
        IF v_merchant_model IS DISTINCT FROM 'direct' THEN
          INSERT INTO public.merchant_ledger
            (merchant_id, order_id, entry_type, amount, currency, description)
          VALUES
            (o.merchant_id, p_order_id, 'credit',
             v_gross - v_commission, v_currency,
             'Order goods ' || v_gross::text || ' less ' || v_rate::text || '% platform commission')
          ON CONFLICT (order_id, entry_type)
            WHERE order_id IS NOT NULL AND entry_type = 'credit'
            DO NOTHING;
        END IF;
      END IF;
    END IF;
  END IF;

  -- Driver-side commission on cash orders is debt until remitted.
  IF v_is_cash AND v_driver_commission > 0 THEN
    SELECT settlement_remittance_due_hours INTO v_due_hours
      FROM public._settlement_settings();
    INSERT INTO public.driver_obligations
      (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
       owed_to, due_at)
    VALUES
      (o.driver_id, NULL, p_order_id, o.merchant_id, 'commission',
       v_driver_commission, v_currency, 'platform',
       now() + make_interval(hours => COALESCE(v_due_hours, 24)))
    ON CONFLICT (order_id, kind) WHERE ride_id IS NULL AND order_id IS NOT NULL DO NOTHING;
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public._record_order_settlement(uuid) FROM PUBLIC, anon, authenticated;

-- 5. Fire on every delivered transition, covering merchant-complete and any
--    future path. The function skips orders already accrued via a ride.
CREATE OR REPLACE FUNCTION public._trg_order_settlement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.status = 'delivered' AND OLD.status IS DISTINCT FROM 'delivered' THEN
    PERFORM public._record_order_settlement(NEW.id);
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public._trg_order_settlement() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS orders_settlement_after_delivered ON public.orders;
CREATE TRIGGER orders_settlement_after_delivered
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public._trg_order_settlement();
