-- Run after migration 147. Every fixture and resulting row is rolled back.
-- Verifies: completing an assigned delivery records the driver earning and
-- both commission rows exactly once, with the driver charged on the fare and
-- the merchant on the goods subtotal; the legacy no-ride completion is not
-- client-callable; the earnings helper is not client-callable.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid();
  m_user uuid := gen_random_uuid();
  u1 uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid();
  v1 uuid := gen_random_uuid();
  m uuid := gen_random_uuid();
  o uuid := gen_random_uuid();
  r uuid;
  a jsonb;
  v_fare numeric;
  v_subtotal numeric := 100;
  v_earning numeric;
  v_row public.platform_commissions%ROWTYPE;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),
    (u1,u1::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),
    (u1,u1::text||'@example.invalid') ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,current_latitude,current_longitude)
    VALUES (d1,u1,'Synthetic earnings driver','online',true,true,true,30,31);
  INSERT INTO public.vehicles(id,driver_id,category,plate_number,is_active)
    VALUES (v1,d1,'motorcycle','AUDIT-E',true);
  UPDATE public.drivers SET active_vehicle_id=v1, location_updated_at=now() WHERE id=d1;
  INSERT INTO public.merchants(id,name,owner_user_id,latitude,longitude,type)
    VALUES (m,'Synthetic earnings merchant',m_user,30,31,'restaurant');
  INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
    VALUES (o,c,m,v_subtotal,120,20,30.001,31.001,'instapay');

  -- Helper must not be client-callable.
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  BEGIN
    PERFORM public._record_delivery_earnings(gen_random_uuid());
    RAISE EXCEPTION '_record_delivery_earnings executable by authenticated caller';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  -- Full assigned-delivery flow.
  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.merchant_dispatch_order_driver(o);
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'dispatch failed: %', a; END IF;
  SELECT id INTO r FROM public.rides WHERE order_id=o;

  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.accept_ride_request(r, d1);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'accept failed: %', a; END IF;

  -- Legacy no-ride completion is callable but refuses real work for
  -- non-owners; ride-linked orders keep the USE_ASSIGNED_DELIVERY_FLOW guard.
  a := public.complete_delivery(o);
  IF a->>'reason' IS DISTINCT FROM 'USE_ASSIGNED_DELIVERY_FLOW' THEN
    RAISE EXCEPTION 'legacy order completion bypass allowed: %', a;
  END IF;
  a := public.driver_arrive(r, d1);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'arrive failed: %', a; END IF;
  PERFORM set_config('role','none',true);

  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.delivery_handoff_code('pickup', r, NULL);
  PERFORM set_config('role','none',true);
  IF a->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'pickup code read failed: %', a; END IF;

  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.start_trip(r, d1, a->>'code');
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'start failed: %', a; END IF;
  PERFORM set_config('role','none',true);

  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.delivery_handoff_code('dropoff', r, NULL);
  PERFORM set_config('role','none',true);
  IF a->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'dropoff code read failed: %', a; END IF;

  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.complete_delivery(r, d1, NULL, NULL, a->>'code');
  PERFORM set_config('role','none',true);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'completion failed: %', a; END IF;

  -- Driver earning: fare (20) less the 7% driver commission = 18.60.
  SELECT fare INTO v_fare FROM public.rides WHERE id=r;
  SELECT amount INTO v_earning FROM public.driver_earnings WHERE ride_id=r;
  IF v_earning IS NULL THEN
    RAISE EXCEPTION 'no driver earning recorded';
  END IF;
  IF v_earning <> round(v_fare * 0.93, 2) THEN
    RAISE EXCEPTION 'driver earning % != fare % less 7%%', v_earning, v_fare;
  END IF;

  -- Driver commission row: ('ride', ride), gross = fare, rate 7.
  SELECT * INTO v_row FROM public.platform_commissions
   WHERE reference_type='ride' AND reference_id=r AND member_id=u1;
  IF NOT FOUND THEN RAISE EXCEPTION 'no driver commission row'; END IF;
  IF v_row.gross_amount <> v_fare OR v_row.commission_rate <> 7
     OR v_row.commission_amount <> round(v_fare * 0.07, 2)
     OR v_row.status <> 'computed' THEN
    RAISE EXCEPTION 'driver commission row wrong: %', v_row;
  END IF;

  -- Merchant commission row: ('order', order), gross = subtotal, rate 3.
  SELECT * INTO v_row FROM public.platform_commissions
   WHERE reference_type='order' AND reference_id=o AND member_id=m_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'no merchant commission row'; END IF;
  IF v_row.gross_amount <> v_subtotal OR v_row.commission_rate <> 3
     OR v_row.commission_amount <> round(v_subtotal * 0.03, 2) THEN
    RAISE EXCEPTION 'merchant commission row wrong: %', v_row;
  END IF;

  -- Idempotent: re-running the helper records nothing twice.
  PERFORM public._record_delivery_earnings(r);
  IF (SELECT count(*) FROM public.driver_earnings WHERE ride_id=r) <> 1
     OR (SELECT count(*) FROM public.platform_commissions WHERE reference_type='ride' AND reference_id=r) <> 1
     OR (SELECT count(*) FROM public.platform_commissions WHERE reference_type='order' AND reference_id=o) <> 1 THEN
    RAISE EXCEPTION 'earnings recording not idempotent';
  END IF;
END;
$$;
ROLLBACK;
