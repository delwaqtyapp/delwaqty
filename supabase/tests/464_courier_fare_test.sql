-- Run after migration 464. Synthetic fixtures only, everything rolled back.
-- request_courier_delivery must store a server-computed fare that equals
-- estimate_delivery_fee, enforce the minimum fee, apply the priority
-- multiplier, fail closed without pricing and keep rejecting bad input.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid();
  a jsonb;
  v_ride RECORD;
  v_est jsonb;
  v_km numeric;
BEGIN
  INSERT INTO auth.users(id, email) VALUES (u, u::text || '@example.invalid');
  INSERT INTO public.users(id, email, role)
    VALUES (u, u::text || '@example.invalid', 'customer')
  ON CONFLICT (id) DO NOTHING;
  DELETE FROM public.delivery_pricing WHERE service_type = 'courier';
  INSERT INTO public.delivery_pricing(service_type, base_fee, per_km, per_kg,
    minimum_fee, priority_multiplier, express_multiplier, currency, is_active)
  VALUES ('courier', 15, 5, 2, 20, 1.2, 1.5, 'EGP', true);

  PERFORM set_config('request.jwt.claim.sub', u::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  PERFORM set_config('role', 'authenticated', true);

  -- (1) short trip: the stored fare is the minimum fee (20.00)
  a := public.request_courier_delivery(30.0, 31.0, 'p', 30.0001, 31.0001, 'd',
    'x', NULL, 'standard');
  ASSERT (a->>'ok')::boolean, '464 1a: ' || a::text;
  SELECT * INTO v_ride FROM public.rides WHERE id = (a->>'delivery_id')::uuid;
  ASSERT v_ride.fare = 20.00, '464 1b: short trip fare ' || coalesce(v_ride.fare::text, 'NULL');
  ASSERT (a->>'fare')::numeric = v_ride.fare, '464 1c: returned fare = stored fare';

  -- (2) longer trip: stored fare equals the estimate for the same distance
  a := public.request_courier_delivery(30.0, 31.0, 'p', 30.1, 31.1, 'd',
    'x', NULL, 'standard');
  SELECT * INTO v_ride FROM public.rides WHERE id = (a->>'delivery_id')::uuid;
  v_km := public.haversine_km(30.0, 31.0, 30.1, 31.1)::numeric;
  v_est := public.estimate_delivery_fee('courier', v_km, 1.0, 'standard');
  ASSERT v_ride.fare IS NOT NULL AND v_ride.fare > 20, '464 2a: ' || coalesce(v_ride.fare::text, 'NULL');
  ASSERT v_ride.fare = (v_est->>'fee')::numeric, '464 2b: fare != estimate';

  -- (3) priority multiplier is applied
  a := public.request_courier_delivery(30.0, 31.0, 'p', 30.1, 31.1, 'd',
    'x', NULL, 'express');
  SELECT * INTO v_ride FROM public.rides WHERE id = (a->>'delivery_id')::uuid;
  v_est := public.estimate_delivery_fee('courier', v_km, 1.0, 'express');
  ASSERT v_ride.fare = (v_est->>'fee')::numeric, '464 3: express fare';

  -- (4) caller still cannot price or link anything
  ASSERT v_ride.order_id IS NULL AND v_ride.merchant_id IS NULL
    AND v_ride.rider_id = u, '464 4: server-controlled fields';

  -- (5) bad input is still rejected, and writes no ride
  a := public.request_courier_delivery(NULL, 31.0, 'p', 30.1, 31.1, 'd', 'x', NULL, 'standard');
  ASSERT a->>'reason' = 'INVALID_INPUT', '464 5a: NULL coordinate';
  a := public.request_courier_delivery(30.0, 31.0, 'p', 30.1, 31.1, 'd', 'x', NULL, 'bogus');
  ASSERT a->>'reason' = 'INVALID_INPUT', '464 5b: unknown priority';

  -- (6) no active courier pricing: fail closed, no ride
  PERFORM set_config('role', 'none', true);
  UPDATE public.delivery_pricing SET is_active = false WHERE service_type = 'courier';
  PERFORM set_config('role', 'authenticated', true);
  PERFORM count(*) FROM public.rides;
  a := public.request_courier_delivery(30.0, 31.0, 'p', 30.1, 31.1, 'd', 'x', NULL, 'standard');
  ASSERT a->>'reason' = 'PRICING_UNAVAILABLE' AND NOT (a->>'ok')::boolean, '464 6a: ' || a::text;
  PERFORM set_config('role', 'none', true);
  ASSERT (SELECT count(*) FROM public.rides WHERE rider_id = u) = 3, '464 6b: no ride written without pricing';
  RAISE NOTICE '464 courier fare: all assertions passed';
END $$;
ROLLBACK;
