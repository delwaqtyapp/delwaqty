-- Run after migration 146. Every fixture and resulting row is rolled back.
-- Verifies: in-custody cancel refused, incident report/resolve lifecycle,
-- driver pre-pickup cancel auto-redispatches to another driver and excludes
-- the canceller, rider pre-pickup cancel still cancels outright, and the
-- internal dispatch function is not client-callable.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid();      -- customer
  m_user uuid := gen_random_uuid(); -- merchant owner
  u1 uuid := gen_random_uuid();     -- driver 1 (cancels)
  u2 uuid := gen_random_uuid();     -- driver 2 (should receive re-offer)
  d1 uuid := gen_random_uuid();
  d2 uuid := gen_random_uuid();
  v1 uuid := gen_random_uuid();
  v2 uuid := gen_random_uuid();
  m uuid := gen_random_uuid();
  o uuid := gen_random_uuid();
  r uuid;
  a jsonb;
  v_incident uuid;
  v_count int;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),
    (u1,u1::text||'@example.invalid'),(u2,u2::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),
    (u1,u1::text||'@example.invalid'),(u2,u2::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,current_latitude,current_longitude)
    VALUES (d1,u1,'Synthetic driver one','online',true,true,true,30,31),
           (d2,u2,'Synthetic driver two','online',true,true,true,30.001,31.001);
  INSERT INTO public.vehicles(id,driver_id,category,plate_number,is_active)
    VALUES (v1,d1,'motorcycle','AUDIT-1',true),(v2,d2,'motorcycle','AUDIT-2',true);
  UPDATE public.drivers SET active_vehicle_id=v1, location_updated_at=now() WHERE id=d1;
  UPDATE public.drivers SET active_vehicle_id=v2, location_updated_at=now() WHERE id=d2;
  INSERT INTO public.merchants(id,name,owner_user_id,latitude,longitude)
    VALUES (m,'Synthetic incident merchant',m_user,30,31);
  INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
    VALUES (o,c,m,100,120,20,30.001,31.001,'instapay');

  -- Internal dispatch must not be client-callable.
  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  BEGIN
    PERFORM public._dispatch_delivery_internal(gen_random_uuid(), 25.0, 15);
    RAISE EXCEPTION '_dispatch_delivery_internal executable by authenticated caller';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  PERFORM set_config('role','none',true);

  -- Merchant dispatches; driver 1 (nearest) gets the offer and accepts.
  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.merchant_dispatch_order_driver(o);
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'merchant dispatch failed: %', a; END IF;
  SELECT id INTO r FROM public.rides WHERE order_id=o;
  IF r IS NULL THEN RAISE EXCEPTION 'no linked ride'; END IF;

  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.accept_ride_request(r, d1);
  PERFORM set_config('role','none',true);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'driver 1 accept failed: %', a; END IF;

  -- Driver 1 cancels before pickup: ride must return to searching, driver 1
  -- excluded, driver 2 offered automatically, order kept alive.
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.cancel_ride_lifecycle(r, 'driver', 'changed mind');
  PERFORM set_config('role','none',true);
  IF a->>'success' <> 'true' OR a->>'status' <> 'redispatching' THEN
    RAISE EXCEPTION 'pre-pickup driver cancel did not redispatch: %', a;
  END IF;
  IF a->>'offered' <> 'true' THEN RAISE EXCEPTION 'redispatch found no drivers: %', a; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rides WHERE id=r AND status='searching' AND driver_id IS NULL) THEN
    RAISE EXCEPTION 'ride not back to searching';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ride_requests WHERE ride_id=r AND driver_id=d1 AND status='cancelled') THEN
    RAISE EXCEPTION 'cancelling driver request not marked cancelled';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ride_requests WHERE ride_id=r AND driver_id=d2 AND status='offered') THEN
    RAISE EXCEPTION 'replacement driver not offered';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orders WHERE id=o AND status<>'cancelled' AND dispatch_status='OFFERED' AND driver_id IS NULL) THEN
    RAISE EXCEPTION 'order not kept alive in OFFERED state';
  END IF;

  -- Driver 2 accepts the re-offer; fresh handoff codes were issued.
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.accept_ride_request(r, d2);
  PERFORM set_config('role','none',true);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'driver 2 accept after redispatch failed: %', a; END IF;

  -- Move to pickup and into custody.
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.driver_arrive(r, d2);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'driver 2 arrive failed: %', a; END IF;
  a := public.delivery_handoff_code('pickup', r, NULL);
  PERFORM set_config('role','none',true);
  IF a->>'ok' IS DISTINCT FROM 'false' OR a->>'reason' IS DISTINCT FROM 'FORBIDDEN' THEN
    RAISE EXCEPTION 'driver could read pickup code: %', a;
  END IF;
  -- Merchant reads the pickup code; driver starts the trip with it.
  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.delivery_handoff_code('pickup', r, NULL);
  PERFORM set_config('role','none',true);
  IF a->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'merchant code read failed: %', a; END IF;

  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.start_trip(r, d2, a->>'code');
  PERFORM set_config('role','none',true);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'driver 2 start failed: %', a; END IF;

  -- In custody: neither side may plain-cancel.
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.cancel_ride_lifecycle(r, 'driver', 'broken bike');
  PERFORM set_config('role','none',true);
  IF a->>'reason' IS DISTINCT FROM 'in_custody' THEN
    RAISE EXCEPTION 'driver in-custody cancel not refused: %', a;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.cancel_ride_lifecycle(r, 'rider', 'changed mind');
  PERFORM set_config('role','none',true);
  IF a->>'reason' IS DISTINCT FROM 'in_custody' THEN
    RAISE EXCEPTION 'rider in-custody cancel not refused: %', a;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rides WHERE id=r AND status='inTrip') THEN
    RAISE EXCEPTION 'ride lost inTrip status after refused cancels';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orders WHERE id=o AND status<>'cancelled') THEN
    RAISE EXCEPTION 'order cancelled while goods in custody';
  END IF;

  -- Incident flow: driver reports, a stranger cannot, admin resolves.
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.report_delivery_incident(r, 'other', 'not my ride');
  PERFORM set_config('role','none',true);
  IF a->>'reason' IS DISTINCT FROM 'forbidden' THEN
    RAISE EXCEPTION 'stranger could report incident: %', a;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.report_delivery_incident(r, 'breakdown', 'bike died, goods safe');
  PERFORM set_config('role','none',true);
  IF (a->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'driver incident report failed: %', a; END IF;
  v_incident := (a->>'incident_id')::uuid;

  -- Non-admin cannot resolve.
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.resolve_delivery_incident(v_incident, 'returned_to_merchant', NULL);
  PERFORM set_config('role','none',true);
  IF a->>'reason' IS DISTINCT FROM 'forbidden' THEN
    RAISE EXCEPTION 'non-admin resolved incident: %', a;
  END IF;

  -- The incidents table itself is unreachable by clients.
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  PERFORM set_config('role','authenticated',true);
  BEGIN
    PERFORM id FROM public.delivery_incidents LIMIT 1;
    RAISE EXCEPTION 'delivery_incidents readable by authenticated caller';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  PERFORM set_config('role','none',true);

  -- Admin resolves as returned_to_merchant: ride and order closed.
  UPDATE public.users SET role='owner', role_key='owner' WHERE id=c;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  a := public.resolve_delivery_incident(v_incident, 'returned_to_merchant', 'goods back at store');
  PERFORM set_config('role','none',true);
  IF (a->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'admin resolve failed: %', a; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rides WHERE id=r AND status='cancelled' AND cancelled_by='system') THEN
    RAISE EXCEPTION 'ride not cancelled by support after return';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orders WHERE id=o AND status='cancelled') THEN
    RAISE EXCEPTION 'order not cancelled after return';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.delivery_incidents WHERE id=v_incident AND status='resolved' AND resolution='returned_to_merchant') THEN
    RAISE EXCEPTION 'incident not recorded resolved';
  END IF;
END;
$$;
ROLLBACK;
