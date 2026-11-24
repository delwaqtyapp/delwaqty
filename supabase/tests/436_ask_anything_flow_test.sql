-- Run after migration 436. Every fixture and resulting row is rolled back.
-- Verifies the ask-anything flow end to end: structured request, quote
-- negotiation and fare lock, per-item invoice approval, shopping close,
-- the start_trip guard, and the goods-ledger earnings note.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid();          -- rider
  du uuid := gen_random_uuid();         -- driver user
  other uuid := gen_random_uuid();      -- unrelated user
  d uuid := gen_random_uuid();          -- drivers row id
  v_ride uuid;
  v_ride2 uuid;
  a jsonb;
  v_quote uuid;
  v_quote2 uuid;
  v_item1 uuid; v_item2 uuid; v_item3 uuid;
  v_denied boolean;
  v_n int;
  v_fare numeric;
  v_goods numeric;
BEGIN
  INSERT INTO auth.users(id, email) VALUES
    (u, u::text || '@example.invalid'),
    (du, du::text || '@example.invalid'),
    (other, other::text || '@example.invalid');
  INSERT INTO public.users(id, email, role) VALUES
    (u, u::text || '@example.invalid', 'customer'),
    (du, du::text || '@example.invalid', 'driver'),
    (other, other::text || '@example.invalid', 'customer')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.drivers(id, user_id, full_name) VALUES (d, du, 'Test Driver');

  -- ── Request validation ──
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  PERFORM set_config('role', 'authenticated', true);

  a := public.request_courier_shopping(
    30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff',
    '[{"product_name":"طماطم","unit":"kilo"},{"product_name":"مناديل","unit":"amount","amount_egp":50}]'::jsonb,
    2, NULL, 'standard');
  IF NOT (a ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'request_courier_shopping rejected a valid request: %', a;
  END IF;
  v_ride := (a ->> 'delivery_id')::uuid;
  IF (a ->> 'quote_baseline')::numeric <> 20 THEN
    RAISE EXCEPTION 'quote baseline for 2 shops should be 20, got %', a;
  END IF;

  SELECT fare INTO v_fare FROM public.rides WHERE id = v_ride;
  PERFORM set_config('role', 'postgres', true);
  IF v_fare IS NOT NULL THEN
    RAISE EXCEPTION 'fare must stay NULL until a quote is accepted';
  END IF;
  IF NOT (SELECT is_ask_anything FROM public.rides WHERE id = v_ride) THEN
    RAISE EXCEPTION 'ride not flagged is_ask_anything';
  END IF;
  IF (SELECT count(*) FROM public.courier_request_items WHERE ride_id = v_ride) <> 2 THEN
    RAISE EXCEPTION 'expected 2 request items';
  END IF;
  IF (SELECT count(*) FROM public.courier_request_items
       WHERE ride_id = v_ride AND unit = 'amount' AND amount_egp = 50) <> 1 THEN
    RAISE EXCEPTION 'amount item not stored';
  END IF;
  PERFORM set_config('role', 'authenticated', true);

  -- Invalid item shapes are rejected.
  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[{"product_name":"x","unit":"dozen"}]'::jsonb, 1, NULL, 'standard') ->> 'reason') <> 'INVALID_ITEMS' THEN
    RAISE EXCEPTION 'bad unit accepted';
  END IF;
  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[{"product_name":"x","unit":"amount"}]'::jsonb, 1, NULL, 'standard') ->> 'reason') <> 'INVALID_ITEMS' THEN
    RAISE EXCEPTION 'amount unit without amount accepted';
  END IF;
  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[]'::jsonb, 1, NULL, 'standard') ->> 'reason') <> 'INVALID_ITEMS' THEN
    RAISE EXCEPTION 'empty items accepted';
  END IF;
  IF (public.request_courier_shopping(30.0,31.0,'p',30.1,31.1,'d',
      '[{"product_name":"x","unit":"kilo"}]'::jsonb, 0, NULL, 'standard') ->> 'reason') <> 'INVALID_INPUT' THEN
    RAISE EXCEPTION 'zero shops accepted';
  END IF;

  -- Direct table writes are denied; RLS hides the ride from strangers.
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
  IF (SELECT count(*) FROM public.courier_request_items WHERE ride_id = v_ride) <> 0 THEN
    RAISE EXCEPTION 'stranger can read request items';
  END IF;
  IF (public.propose_courier_quote(v_ride, 25, NULL) ->> 'reason') NOT IN ('FORBIDDEN', 'INVALID_STATE') THEN
    RAISE EXCEPTION 'stranger could propose a quote';
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);

  -- ── Quote flow ──
  -- No driver yet: INVALID_STATE for rider-open, NO_QUOTE_TO_COUNTER after match.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET status = 'matched', driver_id = d WHERE id = v_ride;
  PERFORM set_config('role', 'authenticated', true);
  IF (public.propose_courier_quote(v_ride, 30, NULL) ->> 'reason') <> 'NO_QUOTE_TO_COUNTER' THEN
    RAISE EXCEPTION 'rider opened the negotiation';
  END IF;

  -- Driver proposes; rider counters; driver rejects; driver re-proposes; rider accepts.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.propose_courier_quote(v_ride, 40, 'بعيد شوية');
  IF NOT (a ->> 'ok')::boolean OR (a ->> 'role') <> 'driver' THEN
    RAISE EXCEPTION 'driver proposal failed: %', a;
  END IF;
  v_quote := (a ->> 'quote_id')::uuid;
  -- One pending quote only.
  a := public.propose_courier_quote(v_ride, 45, NULL);
  IF (SELECT count(*) FROM public.courier_quotes WHERE ride_id = v_ride AND status = 'pending') <> 1 THEN
    RAISE EXCEPTION 'more than one pending quote';
  END IF;
  v_quote := (a ->> 'quote_id')::uuid;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.propose_courier_quote(v_ride, 35, 'كفاية كده');
  IF NOT (a ->> 'ok')::boolean OR (a ->> 'role') <> 'customer' THEN
    RAISE EXCEPTION 'rider counter failed: %', a;
  END IF;
  v_quote2 := (a ->> 'quote_id')::uuid;
  IF (SELECT status FROM public.courier_quotes WHERE id = v_quote) <> 'superseded' THEN
    RAISE EXCEPTION 'driver quote not superseded by counter';
  END IF;

  -- The proposer cannot answer their own quote.
  IF (public.respond_courier_quote(v_quote2, 'accept') ->> 'reason') <> 'FORBIDDEN' THEN
    RAISE EXCEPTION 'rider accepted their own counter';
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  IF NOT (public.respond_courier_quote(v_quote2, 'reject') ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'driver could not reject the counter';
  END IF;
  a := public.propose_courier_quote(v_ride, 45, 'سعر نهائي');
  v_quote := (a ->> 'quote_id')::uuid;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.respond_courier_quote(v_quote, 'accept');
  IF NOT (a ->> 'ok')::boolean OR NOT (a ->> 'locked')::boolean THEN
    RAISE EXCEPTION 'accept failed: %', a;
  END IF;
  PERFORM set_config('role', 'postgres', true);
  IF (SELECT fare FROM public.rides WHERE id = v_ride) <> 45
     OR NOT (SELECT courier_quote_locked FROM public.rides WHERE id = v_ride) THEN
    RAISE EXCEPTION 'fare not locked to the accepted quote';
  END IF;
  PERFORM set_config('role', 'authenticated', true);

  -- After the lock no new quotes.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  IF (public.propose_courier_quote(v_ride, 50, NULL) ->> 'reason') <> 'QUOTE_ALREADY_LOCKED' THEN
    RAISE EXCEPTION 'quote proposed after lock';
  END IF;

  -- ── Invoice flow ──
  a := public.add_courier_invoice_item(v_ride, 'سوبر ماركت النور', 'طماطم', 25.50, 'kilo', 1, NULL);
  IF NOT (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'add item 1 failed: %', a; END IF;
  v_item1 := (a ->> 'item_id')::uuid;
  a := public.add_courier_invoice_item(v_ride, 'سوبر ماركت النور', 'زيت', 80, NULL, NULL,
        'https://example.invalid/receipt1.jpg');
  v_item2 := (a ->> 'item_id')::uuid;
  a := public.add_courier_invoice_item(v_ride, 'عطارة الهدى', 'بهارات', 30, NULL, NULL, NULL);
  v_item3 := (a ->> 'item_id')::uuid;

  -- Strangers and the rider cannot add items.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', other)::text, true);
  IF (public.add_courier_invoice_item(v_ride, 'x', 'y', 1, NULL, NULL, NULL) ->> 'reason') <> 'FORBIDDEN' THEN
    RAISE EXCEPTION 'stranger added an invoice item';
  END IF;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.add_courier_invoice_item(v_ride, 'x', 'y', 1, NULL, NULL, NULL);
  IF (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'rider added an invoice item'; END IF;

  -- The rider decides item by item.
  IF NOT (public.decide_courier_invoice_item(v_item1, 'approve') ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'approve failed';
  END IF;
  IF NOT (public.decide_courier_invoice_item(v_item2, 'reject') ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'reject failed';
  END IF;
  -- Decided items cannot be re-decided.
  IF (public.decide_courier_invoice_item(v_item1, 'reject') ->> 'reason') <> 'ITEM_NOT_PENDING' THEN
    RAISE EXCEPTION 'decided item re-decided';
  END IF;
  -- The driver cannot approve items himself.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.decide_courier_invoice_item(v_item3, 'approve');
  IF (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'driver approved an item'; END IF;

  -- The driver cancels the rejected item while at the shop.
  IF NOT (public.cancel_courier_invoice_item(v_item2) ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'driver could not cancel the rejected item';
  END IF;
  -- An approved item cannot be cancelled.
  IF (public.cancel_courier_invoice_item(v_item1) ->> 'reason') <> 'INVALID_STATE' THEN
    RAISE EXCEPTION 'approved item cancelled';
  END IF;

  -- finish_courier_shopping blocks while item3 is pending.
  a := public.finish_courier_shopping(v_ride);
  IF (a ->> 'reason') <> 'ITEMS_PENDING' THEN
    RAISE EXCEPTION 'shopping finished with a pending item: %', a;
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  PERFORM public.decide_courier_invoice_item(v_item3, 'approve');

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.finish_courier_shopping(v_ride);
  IF NOT (a ->> 'ok')::boolean THEN RAISE EXCEPTION 'finish failed: %', a; END IF;
  v_goods := (a ->> 'goods_total')::numeric;
  IF v_goods <> 55.50 THEN
    RAISE EXCEPTION 'goods total should be 25.50 + 30 = 55.50, got %', v_goods;
  END IF;
  IF (a ->> 'shops')::int <> 2 THEN
    RAISE EXCEPTION 'expected 2 distinct shops, got %', a;
  END IF;
  IF (a ->> 'customer_total')::numeric <> 100.50 THEN
    RAISE EXCEPTION 'customer total should be 45 + 55.50 = 100.50, got %', a;
  END IF;

  -- No new items after shopping closed.
  IF (public.add_courier_invoice_item(v_ride, 'x', 'y', 1, NULL, NULL, NULL) ->> 'reason') <> 'INVALID_STATE' THEN
    RAISE EXCEPTION 'item added after shopping closed';
  END IF;

  -- ── start_trip guard on a second ride that never finished shopping ──
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', u)::text, true);
  a := public.request_courier_shopping(
    30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff',
    '[{"product_name":"خبز","unit":"quarter"}]'::jsonb, 1, NULL, 'standard');
  v_ride2 := (a ->> 'delivery_id')::uuid;
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET status = 'arrived', driver_id = d,
         courier_quote_locked = true WHERE id = v_ride2;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', du)::text, true);
  a := public.start_trip(v_ride2, d, '000000');
  IF (a ->> 'reason') IS DISTINCT FROM 'shopping_not_finished' THEN
    RAISE EXCEPTION 'start_trip allowed unfinished shopping: %', a;
  END IF;

  -- ── Earnings: fare commission only, goods recorded, no goods obligation ──
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.rides SET status = 'completed', completed_at = now(),
         delivered_at = now(), payment_method = 'cash' WHERE id = v_ride;
  PERFORM public._record_delivery_earnings(v_ride);
  IF NOT EXISTS (SELECT 1 FROM public.driver_earnings WHERE ride_id = v_ride) THEN
    RAISE EXCEPTION 'no driver earning recorded for the locked fare';
  END IF;
  IF EXISTS (SELECT 1 FROM public.driver_obligations
              WHERE ride_id = v_ride AND kind = 'goods') THEN
    RAISE EXCEPTION 'a goods obligation was booked for the driver (double charge)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.trip_events
                  WHERE ride_id = v_ride AND event_type = 'courier_goods_recorded'
                    AND (metadata ->> 'goods_total')::numeric = 55.50) THEN
    RAISE EXCEPTION 'goods pass-through trip event missing';
  END IF;

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

  RAISE NOTICE '436 ask-anything flow: ALL CHECKS PASSED';
END $$;
ROLLBACK;
