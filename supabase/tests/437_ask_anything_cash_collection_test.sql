-- Run after migration 437. Every fixture and resulting row is rolled back.
-- Covers the ask-anything cash branch in driver_cash_collection_state and
-- confirm_cash_collection: fare + goods with cents, fail closed on
-- unfinished shopping, zero approved items, the incident-cancelled ride,
-- and the unchanged ordinary courier and merchant paths; plus the
-- security condition that earnings/commission/settlement stay fare-only.
-- All nullable comparisons use IS DISTINCT FROM.
BEGIN;
INSERT INTO public.commission_rules(entity_type,entity_key,rate,is_active,effective_from)
VALUES('account_type','driver',7,true,current_date);
DO $$
DECLARE
  u uuid := gen_random_uuid();          -- rider
  du uuid := gen_random_uuid();         -- driver user
  owner_u uuid := gen_random_uuid();    -- owner
  d uuid := gen_random_uuid();          -- drivers row id
  r_fin uuid := gen_random_uuid();      -- finished, fare 45 + goods 55.50
  r_unf uuid := gen_random_uuid();      -- shopping unfinished
  r_zero uuid := gen_random_uuid();     -- finished, zero approved items
  r_cxl uuid := gen_random_uuid();      -- incident-cancelled, records kept
  r_plain uuid := gen_random_uuid();    -- ordinary courier
  r_merch uuid := gen_random_uuid();    -- merchant order ride
  o_merch uuid := gen_random_uuid();
  m_user uuid := gen_random_uuid();
  m1 uuid := gen_random_uuid();
  a jsonb;
BEGIN
  INSERT INTO auth.users(id, email) VALUES
    (u, u::text || '@example.invalid'), (du, du::text || '@example.invalid'),
    (owner_u, owner_u::text || '@example.invalid'),
    (m_user, m_user::text || '@example.invalid');
  INSERT INTO public.users(id, email, role) VALUES
    (u, u::text || '@example.invalid', 'customer'),
    (du, du::text || '@example.invalid', 'driver'),
    (owner_u, owner_u::text || '@example.invalid', 'owner'),
    (m_user, m_user::text || '@example.invalid', 'merchant')
  ON CONFLICT (id) DO NOTHING;
  -- The auth.users trigger pre-creates public.users rows as 'customer';
  -- promote the owner fixture explicitly.
  UPDATE public.users SET role = 'owner' WHERE id = owner_u;
  INSERT INTO public.drivers(id, user_id, full_name) VALUES (d, du, 'Cash 437 Driver');
  INSERT INTO public.merchants(id, name, owner_user_id, latitude, longitude, type)
    VALUES (m1, 'Cash 437 Merchant', m_user, 30, 31, 'restaurant');
  INSERT INTO public.orders(id, user_id, merchant_id, subtotal, total_amount,
    delivery_fee, delivery_latitude, delivery_longitude, payment_method)
    VALUES (o_merch, u, m1, 60, 77.25, 17.25, 30.001, 31.001, 'cash');

  INSERT INTO public.rides(id, rider_id, driver_id, pickup_latitude, pickup_longitude,
    pickup_address, dropoff_latitude, dropoff_longitude, dropoff_address, ride_type,
    service_type, status, fare, payment_method, is_ask_anything, courier_quote_locked,
    courier_goods_total, courier_shopping_finished, completed_at, delivered_at)
  VALUES
    (r_fin, u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
     'completed', 45, 'cash', true, true, 55.50, true, now(), now()),
    (r_unf, u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
     'arrived', 45, 'cash', true, true, 0, false, NULL, NULL),
    (r_zero, u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
     'completed', 45, 'cash', true, true, 0, true, now(), now()),
    (r_cxl, u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
     'cancelled', 45, 'cash', true, true, 55.50, true, NULL, NULL),
    (r_plain, u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
     'completed', 30, 'cash', false, false, 0, false, now(), now());
  INSERT INTO public.rides(id, rider_id, driver_id, pickup_latitude, pickup_longitude,
    pickup_address, dropoff_latitude, dropoff_longitude, dropoff_address, ride_type,
    service_type, status, fare, order_id, payment_method, completed_at, delivered_at)
  VALUES
    (r_merch, u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
     'completed', 17.25, o_merch, 'cash', now(), now());

  -- ── 1. Finished ask-anything: state and confirm collect fare + goods ──
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.driver_cash_collection_state(r_fin);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM true
     OR (a -> 'amount')::numeric IS DISTINCT FROM 100.50 THEN
    RAISE EXCEPTION 'state: finished ask-anything must collect 100.50, got %', a;
  END IF;
  a := public.confirm_cash_collection('ride', r_fin);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM true
     OR (a ->> 'code') IS DISTINCT FROM 'COLLECTED'
     OR (a -> 'amount')::numeric IS DISTINCT FROM 100.50 THEN
    RAISE EXCEPTION 'confirm: finished ask-anything must collect 100.50, got %', a;
  END IF;
  PERFORM set_config('role', 'postgres', true);
  IF NOT EXISTS (SELECT 1 FROM public.audit_log
                  WHERE action = 'CASH_COLLECTED' AND resource = 'ride'
                    AND resource_id = r_fin::text
                    AND (after ->> 'amount')::numeric = 100.50) THEN
    RAISE EXCEPTION 'audit: no CASH_COLLECTED row with amount 100.50';
  END IF;

  -- ── 2. Fail closed: unfinished shopping shows and collects nothing ──
  PERFORM set_config('role', 'authenticated', true);
  a := public.driver_cash_collection_state(r_unf);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM true
     OR (a ->> 'amount') IS NOT NULL THEN
    RAISE EXCEPTION 'state: unfinished shopping must show NULL amount, got %', a;
  END IF;
  a := public.confirm_cash_collection('ride', r_unf);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM false
     OR (a ->> 'code') IS DISTINCT FROM 'SHOPPING_UNFINISHED' THEN
    RAISE EXCEPTION 'confirm: unfinished shopping must fail closed, got %', a;
  END IF;

  -- ── 3. Zero approved items: goods 0, so fare only ──
  a := public.driver_cash_collection_state(r_zero);
  IF (a -> 'amount')::numeric IS DISTINCT FROM 45 THEN
    RAISE EXCEPTION 'state: zero-item ride must collect fare only (45), got %', a;
  END IF;
  a := public.confirm_cash_collection('ride', r_zero);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM true
     OR (a -> 'amount')::numeric IS DISTINCT FROM 45 THEN
    RAISE EXCEPTION 'confirm: zero-item ride must collect fare only (45), got %', a;
  END IF;

  -- ── 4. Incident-cancelled with goods: records kept, never collected ──
  a := public.driver_cash_collection_state(r_cxl);
  IF (a ->> 'amount') IS NOT NULL THEN
    RAISE EXCEPTION 'state: cancelled ride must show NULL amount, got %', a;
  END IF;
  a := public.confirm_cash_collection('ride', r_cxl);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM false
     OR (a ->> 'code') IS DISTINCT FROM 'RIDE_CANCELLED' THEN
    RAISE EXCEPTION 'confirm: cancelled ride must refuse (driver), got %', a;
  END IF;
  -- Not even the owner can collect on it: settlement goes through the
  -- incident report.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', owner_u)::text, true);
  a := public.confirm_cash_collection('ride', r_cxl);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM false
     OR (a ->> 'code') IS DISTINCT FROM 'RIDE_CANCELLED' THEN
    RAISE EXCEPTION 'confirm: cancelled ride must refuse (owner), got %', a;
  END IF;

  -- ── 5. Ordinary courier ride: fare only, unchanged ──
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.driver_cash_collection_state(r_plain);
  IF (a -> 'amount')::numeric IS DISTINCT FROM 30 THEN
    RAISE EXCEPTION 'state: plain courier must collect fare only (30), got %', a;
  END IF;
  a := public.confirm_cash_collection('ride', r_plain);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM true
     OR (a -> 'amount')::numeric IS DISTINCT FROM 30 THEN
    RAISE EXCEPTION 'confirm: plain courier must collect fare only (30), got %', a;
  END IF;

  -- ── 6. Merchant order ride: order total, unchanged ──
  a := public.driver_cash_collection_state(r_merch);
  IF (a -> 'amount')::numeric IS DISTINCT FROM 77.25 THEN
    RAISE EXCEPTION 'state: merchant ride must collect the order total, got %', a;
  END IF;
  a := public.confirm_cash_collection('ride', r_merch);
  IF (a ->> 'ok')::boolean IS DISTINCT FROM true
     OR (a -> 'amount')::numeric IS DISTINCT FROM 77.25 THEN
    RAISE EXCEPTION 'confirm: merchant ride must collect the order total, got %', a;
  END IF;
  PERFORM set_config('role', 'postgres', true);

  -- ── 7. Security condition: earnings/commission/settlement fare-only ──
  -- Goods are a pass-through; the platform earns on the fare alone.
  PERFORM public._record_delivery_earnings(r_fin);
  IF (SELECT amount FROM public.driver_earnings WHERE ride_id = r_fin)
       IS DISTINCT FROM 41.85 THEN
    RAISE EXCEPTION 'earnings must be fare-only (45 * 0.93 = 41.85), got %',
      (SELECT amount FROM public.driver_earnings WHERE ride_id = r_fin);
  END IF;
  IF (SELECT commission_amount FROM public.platform_commissions
       WHERE reference_type = 'ride' AND reference_id = r_fin)
       IS DISTINCT FROM 3.15 THEN
    RAISE EXCEPTION 'commission must be fare-only (45 * 0.07 = 3.15), got %',
      (SELECT commission_amount FROM public.platform_commissions
       WHERE reference_type = 'ride' AND reference_id = r_fin);
  END IF;
  IF (SELECT amount FROM public.driver_obligations
       WHERE ride_id = r_fin AND kind = 'commission') IS DISTINCT FROM 3.15 THEN
    RAISE EXCEPTION 'obligation must be the fare commission only (3.15), got %',
      (SELECT amount FROM public.driver_obligations
       WHERE ride_id = r_fin AND kind = 'commission');
  END IF;
  -- The goods the captain collects reimburse his own out-of-pocket spend
  -- at the shops: no goods obligation to the platform may exist.
  IF EXISTS (SELECT 1 FROM public.driver_obligations
             WHERE ride_id = r_fin AND kind = 'goods') THEN
    RAISE EXCEPTION 'goods obligation must not exist for ask-anything rides';
  END IF;
END $$;
ROLLBACK;
