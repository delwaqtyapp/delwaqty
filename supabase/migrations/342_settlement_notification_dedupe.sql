-- 342: settlement notifications were inserted twice for one delivery when both
-- posting paths ran: _record_delivery_earnings dedupes on data.ride_id and
-- _record_order_settlement on data.order_id, so each missed the other's row
-- (observed on prod: same 90 EGP settlement notified twice at the same
-- timestamp). Both dedupe checks now recognize either key.

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

  -- Idempotent across paths: when the order-scoped accrual (172 trigger on
  -- orders.status -> delivered) already ran for the linked order, skip.
  -- complete_delivery updates orders.status BEFORE calling this function,
  -- so without this check both paths accrue (regression found in E2E).
  IF r.order_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.driver_earnings WHERE order_id = r.order_id) THEN
    RETURN;
  END IF;

  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = r.driver_id;
  v_currency := COALESCE(NULLIF(r.currency, ''), 'EGP');
  v_is_cash := lower(COALESCE(r.payment_method, '')) = 'cash';

  -- Driver: earns the delivery fare minus the driver-rate commission.
  v_gross := COALESCE(r.fare, 0);
  v_rate := COALESCE(public.get_commission_rate('driver', NULL, v_driver_uid), 0);
  v_commission := public.calculate_commission(v_gross, v_rate);
  -- 188: driver-delay waiver - the platform takes NO commission from the
  -- replacement driver on an order that was redispatched for a delay.
  if r.order_id is not null and exists (
    select 1 from public.driver_delay_events de where de.order_id = r.order_id
  ) then
    v_commission := 0;
  end if;
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
                 AND (n.data->>'ride_id' = p_ride_id::text
                      OR n.data->>'order_id' = v_order.id::text)
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
$function$
;

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
  -- 188: driver-delay waiver - the platform takes NO commission from the
  -- replacement driver on an order that was redispatched for a delay.
  if p_order_id is not null and exists (
    select 1 from public.driver_delay_events de where de.order_id = p_order_id
  ) then
    v_commission := 0;
  end if;
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
               AND (n.data->>'order_id' = p_order_id::text
                    OR n.data->>'ride_id' IN (
                      SELECT r2.id::text FROM public.rides r2
                       WHERE r2.order_id = p_order_id))
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
$function$
;
