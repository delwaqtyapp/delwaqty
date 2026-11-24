-- Run after migration 436. Every fixture and resulting row is rolled back.
-- Covers the ask-anything flow end to end plus the #207-#210 and B2
-- matrices: null/malformed actions, lock order, terminal states,
-- reassignment, caps/throttles, baseline floor, cancel lifecycle, cash
-- only, the real start/complete route, commission + idempotence, and the
-- RLS matrix on the three new tables.
-- Note: throttle aging UPDATEs are test-only, run as the migration role.
BEGIN;
-- Deterministic rule fixture (mirrors settlement_system_regression).
INSERT INTO public.commission_rules(entity_type,entity_key,rate,is_active,effective_from)
VALUES('account_type','driver',7,true,current_date);
DO $$
DECLARE
  u uuid := gen_random_uuid();          -- rider
  du uuid := gen_random_uuid();         -- driver user
  du2 uuid := gen_random_uuid();        -- second driver user
  other uuid := gen_random_uuid();      -- unrelated user
  d uuid := gen_random_uuid();          -- drivers row id
  d2 uuid := gen_random_uuid();         -- second drivers row id
  v_ride uuid; v_ride2 uuid; v_ride3 uuid; v_ride4 uuid;
  a jsonb;
  v_quote uuid; v_quote2 uuid;
  v_item1 uuid; v_item2 uuid; v_item3 uuid;
  v_denied boolean;
  v_goods numeric;
  v_rate numeric;
  v_expected numeric;
BEGIN
  INSERT INTO auth.users(id, email) VALUES
    (u, u::text || '@example.invalid'),
    (du, du::text || '@example.invalid'),
    (du2, du2::text || '@example.invalid'),
    (other, other::text || '@example.invalid');
  INSERT INTO public.users(id, email, role) VALUES
    (u, u::text || '@example.invalid', 'customer'),
    (du, du::text || '@example.invalid', 'driver'),
    (du2, du2::text || '@example.invalid', 'driver'),
    (other, other::text || '@example.invalid', 'customer')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.drivers(id, user_id, full_name) VALUES
    (d, du, 'Test Driver'), (d2, du2, 'Test Driver 2');

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  PERFORM set_config('role', 'authenticated', true);

  -- ── Request: valid, plus item-shape and bounds matrix ──
  a := public.request_courier_shopping(
    30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff',
    '[{"product_name":"طماطم","unit":"kilo"},{"product_name":"مناديل","unit":"amount","amount_egp":50}]'::jsonb,
    2, NULL, 'standard');
  IF NOT (a ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'request_courier_shopping rejected a valid request: %', a;
  END IF;
  v_ride := (a ->> 'delivery_id')::uuid;
  IF (a ->> 'quote_baseline')::numeric IS DISTINCT FROM 20 THEN
    RAISE EXCEPTION 'quote baseline for 2 shops should be 20, got %', a;
  END IF;
  PERFORM set_config('role', 'postgres', true);
  IF (SELECT fare FROM public.rides WHERE id = v_ride) IS NOT NULL THEN
    RAISE EXCEPTION 'fare must stay NULL until a quote is accepted';
  END IF;
  IF (SELECT payment_method FROM public.rides WHERE id = v_ride) IS DISTINCT FROM 'cash' THEN
    RAISE EXCEPTION 'B2b: ask-anything ride not pinned to cash';
  END IF;
  IF NOT (SELECT is_ask_anything FROM public.rides WHERE id = v_ride) THEN
    RAISE EXCEPTION 'ride not flagged is_ask_anything';
  END IF;
  PERFORM set_config('role', 'authenticated', true);

  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[{"product_name":"x","unit":"dozen"}]'::jsonb, 1, NULL, 'standard') ->> 'reason') <> 'INVALID_ITEMS' THEN
    RAISE EXCEPTION 'bad unit accepted';
  END IF;
  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[{"product_name":"x","unit":"amount"}]'::jsonb, 1, NULL, 'standard') ->> 'reason') <> 'INVALID_ITEMS' THEN
    RAISE EXCEPTION 'amount unit without amount accepted';
  END IF;
  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[{"product_name":"x","unit":"amount","amount_egp":"NaN"}]'::jsonb, 1, NULL, 'standard') ->> 'reason') <> 'INVALID_ITEMS' THEN
    RAISE EXCEPTION 'NaN amount accepted';
  END IF;
  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[]'::jsonb, 1, NULL, 'standard') ->> 'reason') <> 'INVALID_ITEMS' THEN
    RAISE EXCEPTION 'empty items accepted';
  END IF;
  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[{"product_name":"x","unit":"kilo"}]'::jsonb, 0, NULL, 'standard') ->> 'reason') <> 'INVALID_INPUT' THEN
    RAISE EXCEPTION 'zero shops accepted';
  END IF;

  -- Direct writes denied; RLS hides the ride from strangers.
  v_denied := false;
  BEGIN
    INSERT INTO public.courier_request_items (ride_id, product_name, unit)
    VALUES (v_ride, 'hack', 'kilo');
  EXCEPTION WHEN OTHERS THEN v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'authenticated INSERT into courier_request_items succeeded';
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', other)::text, true);
  IF (SELECT count(*) FROM public.courier_request_items WHERE ride_id = v_ride) <> 0
     OR (SELECT count(*) FROM public.courier_quotes WHERE ride_id = v_ride) <> 0
     OR (SELECT count(*) FROM public.courier_invoice_items WHERE ride_id = v_ride) <> 0 THEN
    RAISE EXCEPTION 'RLS: stranger can read ask-anything rows';
  END IF;
  IF (public.propose_courier_quote(v_ride, 25, NULL) ->> 'reason') NOT IN ('FORBIDDEN', 'INVALID_STATE') THEN
    RAISE EXCEPTION 'stranger could propose a quote';
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);

  -- ── Quote flow ──
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET status = 'matched', driver_id = d WHERE id = v_ride;
  PERFORM set_config('role', 'authenticated', true);
  IF (public.propose_courier_quote(v_ride, 30, NULL) ->> 'reason') <> 'NO_QUOTE_TO_COUNTER' THEN
    RAISE EXCEPTION 'rider opened the negotiation';
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  -- #209: the driver cannot go below the baseline (20 for 2 shops).
  a := public.propose_courier_quote(v_ride, 19, NULL);
  IF (a ->> 'reason') IS DISTINCT FROM 'BELOW_BASELINE' THEN
    RAISE EXCEPTION 'driver proposal below baseline accepted: %', a;
  END IF;
  -- NULL / malformed amounts.
  IF (public.propose_courier_quote(v_ride, NULL, NULL) ->> 'reason') <> 'INVALID_AMOUNT' THEN
    RAISE EXCEPTION 'NULL amount accepted';
  END IF;
  IF (public.propose_courier_quote(v_ride, 'NaN'::numeric, NULL) ->> 'reason') <> 'INVALID_AMOUNT' THEN
    RAISE EXCEPTION 'NaN quote accepted';
  END IF;
  IF (public.propose_courier_quote(v_ride, 'Infinity'::numeric, NULL) ->> 'reason') <> 'INVALID_AMOUNT' THEN
    RAISE EXCEPTION 'Infinity quote accepted';
  END IF;

  a := public.propose_courier_quote(v_ride, 40, 'بعيد شوية');
  IF NOT (a ->> 'ok')::boolean OR (a ->> 'role') IS DISTINCT FROM 'driver' THEN
    RAISE EXCEPTION 'driver proposal failed: %', a;
  END IF;
  v_quote := (a ->> 'quote_id')::uuid;
  -- Throttle: an immediate second proposal is refused.
  IF (public.propose_courier_quote(v_ride, 41, NULL) ->> 'reason') <> 'THROTTLED' THEN
    RAISE EXCEPTION 'quote throttle missing';
  END IF;
  -- Age the quote (test-only) and supersede.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.courier_quotes SET created_at = now() - interval '1 minute' WHERE ride_id = v_ride;
  PERFORM set_config('role', 'authenticated', true);
  a := public.propose_courier_quote(v_ride, 45, NULL);
  IF NOT (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'superseding proposal failed: %', a; END IF;
  IF (SELECT count(*) FROM public.courier_quotes WHERE ride_id = v_ride AND status = 'pending') <> 1 THEN
    RAISE EXCEPTION 'more than one pending quote';
  END IF;
  v_quote := (a ->> 'quote_id')::uuid;

  -- Rider counters below the baseline; the driver cannot accept it (#209).
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.courier_quotes SET created_at = now() - interval '1 minute' WHERE ride_id = v_ride;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.propose_courier_quote(v_ride, 18, 'كفاية كده');
  IF NOT (a ->> 'ok')::boolean OR (a ->> 'role') IS DISTINCT FROM 'customer' THEN
    RAISE EXCEPTION 'rider counter failed: %', a;
  END IF;
  v_quote2 := (a ->> 'quote_id')::uuid;
  IF (SELECT status FROM public.courier_quotes WHERE id = v_quote) IS DISTINCT FROM 'superseded' THEN
    RAISE EXCEPTION 'driver quote not superseded by counter';
  END IF;

  -- #207: NULL and malformed actions; self-answer.
  IF (public.respond_courier_quote(v_quote2, NULL) ->> 'reason') <> 'INVALID_INPUT' THEN
    RAISE EXCEPTION 'NULL action did not fail closed';
  END IF;
  IF (public.respond_courier_quote(v_quote2, 'maybe') ->> 'reason') <> 'INVALID_INPUT' THEN
    RAISE EXCEPTION 'malformed action accepted';
  END IF;
  IF (public.respond_courier_quote(v_quote2, 'accept') ->> 'reason') <> 'FORBIDDEN' THEN
    RAISE EXCEPTION 'rider accepted their own counter';
  END IF;

  -- The driver cannot accept the below-baseline counter.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.respond_courier_quote(v_quote2, 'accept');
  IF (a ->> 'reason') IS DISTINCT FROM 'BELOW_BASELINE' THEN
    RAISE EXCEPTION 'below-baseline counter accepted: %', a;
  END IF;
  IF NOT (public.respond_courier_quote(v_quote2, 'reject') ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'driver could not reject the counter';
  END IF;
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.courier_quotes SET created_at = now() - interval '1 minute' WHERE ride_id = v_ride;
  PERFORM set_config('role', 'authenticated', true);
  a := public.propose_courier_quote(v_ride, 45, 'سعر نهائي');
  IF NOT (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'final proposal failed: %', a; END IF;
  v_quote := (a ->> 'quote_id')::uuid;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.respond_courier_quote(v_quote, 'accept');
  IF NOT (a ->> 'ok')::boolean OR NOT (a ->> 'locked')::boolean THEN
    RAISE EXCEPTION 'accept failed: %', a;
  END IF;
  PERFORM set_config('role', 'postgres', true);
  IF (SELECT fare FROM public.rides WHERE id = v_ride) IS DISTINCT FROM 45::numeric
     OR NOT (SELECT courier_quote_locked FROM public.rides WHERE id = v_ride) THEN
    RAISE EXCEPTION 'fare not locked to the accepted quote';
  END IF;
  PERFORM set_config('role', 'authenticated', true);

  -- A decided quote cannot be answered again; no new quotes after lock.
  IF (public.respond_courier_quote(v_quote, 'reject') ->> 'reason') <> 'QUOTE_ALREADY_LOCKED' THEN
    RAISE EXCEPTION 'decided quote answered after lock';
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  IF (public.propose_courier_quote(v_ride, 50, NULL) ->> 'reason') <> 'QUOTE_ALREADY_LOCKED' THEN
    RAISE EXCEPTION 'quote proposed after lock';
  END IF;

  -- ── Invoice flow ──
  a := public.add_courier_invoice_item(v_ride, 'سوبر ماركت النور', 'طماطم', 25.50, 'kilo', 1, NULL);
  IF NOT (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'add item 1 failed: %', a; END IF;
  v_item1 := (a ->> 'item_id')::uuid;
  -- Throttle: an immediate second add is refused.
  IF (public.add_courier_invoice_item(v_ride, 'x', 'y', 1, NULL, NULL, NULL) ->> 'reason') <> 'THROTTLED' THEN
    RAISE EXCEPTION 'item throttle missing';
  END IF;
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.courier_invoice_items SET created_at = now() - interval '1 minute' WHERE ride_id = v_ride;
  PERFORM set_config('role', 'authenticated', true);
  a := public.add_courier_invoice_item(v_ride, 'سوبر ماركت النور', 'زيت', 80, NULL, NULL,
        'https://example.invalid/receipt1.jpg');
  v_item2 := (a ->> 'item_id')::uuid;
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.courier_invoice_items SET created_at = now() - interval '1 minute' WHERE ride_id = v_ride;
  PERFORM set_config('role', 'authenticated', true);
  a := public.add_courier_invoice_item(v_ride, 'عطارة الهدى', 'بهارات', 30, NULL, NULL, NULL);
  v_item3 := (a ->> 'item_id')::uuid;

  -- Bounds matrix on items.
  IF (public.add_courier_invoice_item(v_ride, 's', 'p', 'NaN'::numeric, NULL, NULL, NULL) ->> 'reason') <> 'INVALID_INPUT' THEN
    RAISE EXCEPTION 'NaN price accepted';
  END IF;
  IF (public.add_courier_invoice_item(v_ride, 's', 'p', 10, NULL, 0, NULL) ->> 'reason') <> 'INVALID_INPUT' THEN
    RAISE EXCEPTION 'zero quantity accepted';
  END IF;
  IF (public.add_courier_invoice_item(v_ride, 's', 'p', 10, NULL, 2000, NULL) ->> 'reason') <> 'INVALID_INPUT' THEN
    RAISE EXCEPTION 'quantity 2000 accepted';
  END IF;

  -- Strangers and the rider cannot add items.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', other)::text, true);
  IF (public.add_courier_invoice_item(v_ride, 'x', 'y', 1, NULL, NULL, NULL) ->> 'reason') <> 'FORBIDDEN' THEN
    RAISE EXCEPTION 'stranger added an invoice item';
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.add_courier_invoice_item(v_ride, 'x', 'y', 1, NULL, NULL, NULL);
  IF (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'rider added an invoice item'; END IF;

  -- RLS: the rider and the assigned driver read all three tables.
  IF (SELECT count(*) FROM public.courier_invoice_items WHERE ride_id = v_ride) <> 3 THEN
    RAISE EXCEPTION 'RLS: rider cannot read invoice items';
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  IF (SELECT count(*) FROM public.courier_invoice_items WHERE ride_id = v_ride) <> 3
     OR (SELECT count(*) FROM public.courier_quotes WHERE ride_id = v_ride) < 1
     OR (SELECT count(*) FROM public.courier_request_items WHERE ride_id = v_ride) <> 2 THEN
    RAISE EXCEPTION 'RLS: assigned driver cannot read ask-anything rows';
  END IF;

  -- The rider decides item by item.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  IF (public.decide_courier_invoice_item(v_item1, NULL) ->> 'reason') <> 'INVALID_INPUT' THEN
    RAISE EXCEPTION 'NULL decide action did not fail closed';
  END IF;
  IF NOT (public.decide_courier_invoice_item(v_item1, 'approve') ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'approve failed';
  END IF;
  IF NOT (public.decide_courier_invoice_item(v_item2, 'reject') ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'reject failed';
  END IF;
  IF (public.decide_courier_invoice_item(v_item1, 'reject') ->> 'reason') <> 'ITEM_NOT_PENDING' THEN
    RAISE EXCEPTION 'decided item re-decided';
  END IF;

  -- B2: while the rejection awaits cancellation the driver adds nothing.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  IF (public.add_courier_invoice_item(v_ride, 's', 'p', 1, NULL, NULL, NULL) ->> 'reason') <> 'REJECTED_ITEMS_OPEN' THEN
    RAISE EXCEPTION 'driver added an item with an open rejection';
  END IF;
  -- The driver cannot approve items himself.
  a := public.decide_courier_invoice_item(v_item3, 'approve');
  IF (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'driver approved an item'; END IF;
  -- finish blocks on the pending item AND on the uncancelled rejection.
  a := public.finish_courier_shopping(v_ride);
  IF (a ->> 'reason') IS DISTINCT FROM 'ITEMS_PENDING' THEN
    RAISE EXCEPTION 'shopping finished with a pending item: %', a;
  END IF;
  -- Cancel the rejected item; finish still blocks on item3.
  IF NOT (public.cancel_courier_invoice_item(v_item2) ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'driver could not cancel the rejected item';
  END IF;
  IF (public.cancel_courier_invoice_item(v_item1) ->> 'reason') <> 'INVALID_STATE' THEN
    RAISE EXCEPTION 'approved item cancelled';
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  PERFORM public.decide_courier_invoice_item(v_item3, 'approve');

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.finish_courier_shopping(v_ride);
  IF NOT (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'finish failed: %', a; END IF;
  v_goods := (a ->> 'goods_total')::numeric;
  IF v_goods IS DISTINCT FROM 55.50::numeric THEN
    RAISE EXCEPTION 'goods total should be 25.50 + 30 = 55.50, got %', v_goods;
  END IF;
  IF (a ->> 'shops')::int <> 2 THEN
    RAISE EXCEPTION 'expected 2 distinct shops, got %', a;
  END IF;
  IF (a ->> 'customer_total')::numeric IS DISTINCT FROM 100.50::numeric THEN
    RAISE EXCEPTION 'customer total should be 45 + 55.50 = 100.50, got %', a;
  END IF;
  -- #208: finish is not repeatable; no adds or decisions after close.
  IF (public.finish_courier_shopping(v_ride) ->> 'reason') <> 'INVALID_STATE' THEN
    RAISE EXCEPTION 'finish repeated';
  END IF;
  IF (public.add_courier_invoice_item(v_ride, 's', 'p', 1, NULL, NULL, NULL) ->> 'reason') <> 'INVALID_STATE' THEN
    RAISE EXCEPTION 'item added after shopping closed';
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  IF (public.decide_courier_invoice_item(v_item1, 'reject') ->> 'reason') <> 'INVALID_STATE' THEN
    RAISE EXCEPTION 'item decided after shopping closed';
  END IF;

  -- ── Caps matrix on a throwaway ride ──
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO public.rides (rider_id, driver_id, pickup_latitude, pickup_longitude,
    pickup_address, dropoff_latitude, dropoff_longitude, dropoff_address,
    ride_type, service_type, status, is_ask_anything, courier_quote_locked,
    courier_shop_count, fare, payment_method)
  VALUES (u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
          'matched', true, true, 1, 20, 'cash')
  RETURNING id INTO v_ride4;
  INSERT INTO public.courier_invoice_items (ride_id, shop_name, product_name, price)
  SELECT v_ride4, 'متجر واحد', 'صنف ' || g, 10 FROM generate_series(1, 50) g;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  IF (public.add_courier_invoice_item(v_ride4, 'متجر واحد', 'زيادة', 1, NULL, NULL, NULL) ->> 'reason') <> 'ITEM_CAP' THEN
    RAISE EXCEPTION '51st item accepted';
  END IF;
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.courier_invoice_items WHERE ride_id = v_ride4;
  INSERT INTO public.courier_invoice_items (ride_id, shop_name, product_name, price)
  SELECT v_ride4, 'متجر ' || g, 'صنف', 10 FROM generate_series(1, 20) g;
  UPDATE public.courier_invoice_items SET created_at = now() - interval '1 minute' WHERE ride_id = v_ride4;
  PERFORM set_config('role', 'authenticated', true);
  IF (public.add_courier_invoice_item(v_ride4, 'متجر 21', 'زيادة', 1, NULL, NULL, NULL) ->> 'reason') <> 'SHOP_CAP' THEN
    RAISE EXCEPTION '21st distinct shop accepted';
  END IF;
  -- Same-shop add under the shop cap still works.
  IF NOT (public.add_courier_invoice_item(v_ride4, 'متجر 1', 'زيادة', 1, NULL, NULL, NULL) ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'same-shop add under the cap refused';
  END IF;
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.courier_invoice_items WHERE ride_id = v_ride4;
  INSERT INTO public.courier_invoice_items (ride_id, shop_name, product_name, price)
  SELECT v_ride4, 'متجر واحد', 'صنف ' || g, 100000 FROM generate_series(1, 49) g;
  UPDATE public.courier_invoice_items SET created_at = now() - interval '1 minute' WHERE ride_id = v_ride4;
  PERFORM set_config('role', 'authenticated', true);
  -- 49 x 100,000 = 4,900,000; one more legal item reaches 5,000,000.
  IF (public.add_courier_invoice_item(v_ride4, 'متجر واحد', 'زيادة', 100000, NULL, NULL, NULL) ->> 'reason') <> 'GOODS_CAP' THEN
    RAISE EXCEPTION 'goods aggregate reaching 5,000,000 accepted';
  END IF;
  -- Quote cap: 20 quotes per ride (unlock the fare so the cap check
  -- is what answers, not QUOTE_ALREADY_LOCKED).
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET courier_quote_locked = false WHERE id = v_ride4;
  INSERT INTO public.courier_quotes (ride_id, proposed_by_role, proposed_by, amount, status)
  SELECT v_ride4, 'driver', du, 20, 'superseded' FROM generate_series(1, 20) g;
  UPDATE public.courier_quotes SET created_at = now() - interval '1 minute' WHERE ride_id = v_ride4;
  PERFORM set_config('role', 'authenticated', true);
  IF (public.propose_courier_quote(v_ride4, 25, NULL) ->> 'reason') <> 'QUOTE_CAP' THEN
    RAISE EXCEPTION '21st quote accepted';
  END IF;

  -- ── start_trip guard on a ride that never finished shopping ──
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.request_courier_shopping(
    30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff',
    '[{"product_name":"خبز","unit":"quarter"}]'::jsonb, 1, NULL, 'standard');
  v_ride2 := (a ->> 'delivery_id')::uuid;
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET status = 'arrived', driver_id = d,
         courier_quote_locked = true WHERE id = v_ride2;
  -- A rides trigger may already have generated challenges; force known
  -- codes either way (test-only, as the migration role).
  INSERT INTO public.delivery_handoff_challenges (ride_id, stage, code)
  VALUES (v_ride2, 'pickup', '1234'), (v_ride2, 'dropoff', '5678'),
         (v_ride, 'pickup', '1234'), (v_ride, 'dropoff', '5678')
  ON CONFLICT (ride_id, stage) DO UPDATE
    SET code = EXCLUDED.code, verified_at = NULL, attempts = 0,
        expires_at = now() + interval '1 hour', locked_until = NULL;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.start_trip(v_ride2, d, '1234');
  IF (a ->> 'reason') IS DISTINCT FROM 'shopping_not_finished' THEN
    RAISE EXCEPTION 'start_trip allowed unfinished shopping: %', a;
  END IF;

  -- ── Real start -> complete route on the finished ride ──
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET status = 'arrived' WHERE id = v_ride;
  PERFORM set_config('role', 'authenticated', true);
  a := public.start_trip(v_ride, d, '1234');
  IF NOT COALESCE((a ->> 'success')::boolean, false) THEN
    RAISE EXCEPTION 'start_trip failed on a finished ask-anything ride: %', a;
  END IF;
  a := public.complete_delivery(v_ride, d, NULL, NULL, '5678');
  IF NOT COALESCE((a ->> 'success')::boolean, false) THEN
    RAISE EXCEPTION 'complete_delivery failed: %', a;
  END IF;
  -- Earnings ran through the real route: one earning, exact commission
  -- split, no goods obligation, one goods pass-through event.
  PERFORM set_config('role', 'postgres', true);
  v_rate := COALESCE(public.get_commission_rate('driver', NULL, du), 0);
  v_expected := 45 - public.calculate_commission(45, v_rate);
  IF (SELECT count(*) FROM public.driver_earnings WHERE ride_id = v_ride) <> 1 THEN
    RAISE EXCEPTION 'expected exactly one driver earning';
  END IF;
  IF (SELECT amount FROM public.driver_earnings WHERE ride_id = v_ride)
       IS DISTINCT FROM v_expected THEN
    RAISE EXCEPTION 'driver earning != 45 less the rule commission';
  END IF;
  IF (SELECT count(*) FROM public.platform_commissions
       WHERE reference_type = 'ride' AND reference_id = v_ride) <> 1 THEN
    RAISE EXCEPTION 'platform commission row missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.driver_obligations
              WHERE ride_id = v_ride AND kind = 'goods') THEN
    RAISE EXCEPTION 'a goods obligation was booked for the driver (double charge)';
  END IF;
  IF (SELECT count(*) FROM public.trip_events
       WHERE ride_id = v_ride AND event_type = 'courier_goods_recorded'
         AND (metadata ->> 'goods_total')::numeric = 55.50) <> 1 THEN
    RAISE EXCEPTION 'goods pass-through trip event missing or duplicated';
  END IF;
  -- Idempotence: a second run adds nothing.
  PERFORM public._record_delivery_earnings(v_ride);
  IF (SELECT count(*) FROM public.driver_earnings WHERE ride_id = v_ride) <> 1
     OR (SELECT count(*) FROM public.trip_events
          WHERE ride_id = v_ride AND event_type = 'courier_goods_recorded') <> 1 THEN
    RAISE EXCEPTION 'earnings not idempotent';
  END IF;
  PERFORM set_config('role', 'authenticated', true);

  -- ── B2a: cancel lifecycle ──
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO public.rides (rider_id, driver_id, pickup_latitude, pickup_longitude,
    pickup_address, dropoff_latitude, dropoff_longitude, dropoff_address,
    ride_type, service_type, status, is_ask_anything, courier_quote_locked,
    courier_shop_count, fare, payment_method)
  VALUES (u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
          'matched', true, true, 1, 20, 'cash')
  RETURNING id INTO v_ride3;
  INSERT INTO public.courier_invoice_items (ride_id, shop_name, product_name, price, status)
  VALUES (v_ride3, 'متجر', 'صنف', 10, 'approved');
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.cancel_ride_lifecycle(v_ride3, 'driver', 'test');
  IF COALESCE((a ->> 'success')::boolean, true)
     OR (a ->> 'reason') IS DISTINCT FROM 'ask_anything_goods_in_progress' THEN
    RAISE EXCEPTION 'driver cancelled a ride with bought goods: %', a;
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.cancel_ride_lifecycle(v_ride3, 'rider', 'test');
  IF COALESCE((a ->> 'success')::boolean, true)
     OR (a ->> 'reason') IS DISTINCT FROM 'ask_anything_goods_in_progress' THEN
    RAISE EXCEPTION 'rider cancelled a ride with bought goods: %', a;
  END IF;

  -- Driver backs out BEFORE goods: state resets for the next driver.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.courier_invoice_items SET status = 'pending' WHERE ride_id = v_ride3;
  INSERT INTO public.courier_quotes (ride_id, proposed_by_role, proposed_by, amount, status)
  VALUES (v_ride3, 'driver', du, 20, 'pending');
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.cancel_ride_lifecycle(v_ride3, 'driver', 'test');
  IF NOT COALESCE((a ->> 'success')::boolean, false) THEN
    RAISE EXCEPTION 'pre-goods driver cancel failed: %', a;
  END IF;
  PERFORM set_config('role', 'postgres', true);
  IF (SELECT fare FROM public.rides WHERE id = v_ride3) IS NOT NULL
     OR (SELECT courier_quote_locked FROM public.rides WHERE id = v_ride3)
     OR (SELECT courier_shopping_finished FROM public.rides WHERE id = v_ride3)
     OR (SELECT courier_goods_total FROM public.rides WHERE id = v_ride3) IS DISTINCT FROM 0::numeric
     OR EXISTS (SELECT 1 FROM public.courier_quotes
                 WHERE ride_id = v_ride3 AND status = 'pending')
     OR EXISTS (SELECT 1 FROM public.courier_invoice_items
                 WHERE ride_id = v_ride3 AND status IN ('pending', 'rejected')) THEN
    RAISE EXCEPTION 'B2a: redispatch left ask-anything money state behind';
  END IF;
  PERFORM set_config('role', 'authenticated', true);

  -- Rider full cancel on a locked ride clears the money state too.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET status = 'matched', driver_id = d, fare = 20,
         courier_quote_locked = true WHERE id = v_ride3;
  INSERT INTO public.courier_quotes (ride_id, proposed_by_role, proposed_by, amount, status)
  VALUES (v_ride3, 'driver', du, 20, 'pending');
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.cancel_ride_lifecycle(v_ride3, 'rider', 'test');
  IF NOT COALESCE((a ->> 'success')::boolean, false) THEN
    RAISE EXCEPTION 'pre-goods rider cancel failed: %', a;
  END IF;
  PERFORM set_config('role', 'postgres', true);
  IF (SELECT fare FROM public.rides WHERE id = v_ride3) IS NOT NULL
     OR (SELECT courier_quote_locked FROM public.rides WHERE id = v_ride3)
     OR EXISTS (SELECT 1 FROM public.courier_quotes
                 WHERE ride_id = v_ride3 AND status = 'pending') THEN
    RAISE EXCEPTION 'B2a: rider cancel left money state on a dead ride';
  END IF;
  PERFORM set_config('role', 'authenticated', true);

  -- ── Reassignment / terminal-state matrix on responses ──
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO public.rides (rider_id, driver_id, pickup_latitude, pickup_longitude,
    pickup_address, dropoff_latitude, dropoff_longitude, dropoff_address,
    ride_type, service_type, status, is_ask_anything, courier_shop_count,
    payment_method)
  VALUES (u, d, 30.0, 31.0, 'p', 30.1, 31.1, 'd', 'motorcycle', 'courier',
          'matched', true, 1, 'cash')
  RETURNING id INTO v_ride4;
  INSERT INTO public.courier_quotes (ride_id, proposed_by_role, proposed_by, amount, status)
  VALUES (v_ride4, 'driver', du, 20, 'pending') RETURNING id INTO v_quote;
  -- The proposing driver got swapped: the stale quote cannot be accepted.
  UPDATE public.rides SET driver_id = d2 WHERE id = v_ride4;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  IF (public.respond_courier_quote(v_quote, 'accept') ->> 'reason') IS DISTINCT FROM 'DRIVER_CHANGED' THEN
    RAISE EXCEPTION 'stale-driver quote accepted';
  END IF;
  -- A dead ride refuses answers.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET status = 'cancelled' WHERE id = v_ride4;
  PERFORM set_config('role', 'authenticated', true);
  IF (public.respond_courier_quote(v_quote, 'accept') ->> 'reason') <> 'INVALID_STATE' THEN
    RAISE EXCEPTION 'quote answered on a cancelled ride';
  END IF;

  -- ── B2b: the cash-only constraint holds ──
  PERFORM set_config('role', 'postgres', true);
  v_denied := false;
  BEGIN
    UPDATE public.rides SET payment_method = 'wallet' WHERE id = v_ride3;
  EXCEPTION WHEN check_violation THEN v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'B2b: ask-anything ride moved off cash';
  END IF;
  PERFORM set_config('role', 'authenticated', true);

  -- ── ACL spot checks ──
  IF has_function_privilege('anon',
       'public.request_courier_shopping(numeric,numeric,text,numeric,numeric,text,jsonb,integer,text,text)',
       'EXECUTE') THEN
    RAISE EXCEPTION 'anon can execute request_courier_shopping';
  END IF;
  IF NOT has_function_privilege('authenticated',
       'public.finish_courier_shopping(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated lost EXECUTE on finish_courier_shopping';
  END IF;
  IF has_function_privilege('authenticated',
       'public._record_delivery_earnings(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated can execute _record_delivery_earnings';
  END IF;

  RAISE NOTICE '436 ask-anything flow: ALL CHECKS PASSED';
END $$;
ROLLBACK;
