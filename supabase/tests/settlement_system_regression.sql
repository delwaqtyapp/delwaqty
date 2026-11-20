-- Run after migration 161. Every fixture and resulting row is rolled back.
-- Verifies: cash completion creates goods + commission obligations and the
-- merchant ledger credit; the dispatch gate excludes overdue/over-ceiling
-- drivers from CASH dispatches only; the admin-code and merchant-confirm
-- settlement flows; dispute half-weight; escalation + suspension-review
-- sweeps; payout request/approval; RLS and privilege guards.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid();
  m_user uuid := gen_random_uuid();
  u1 uuid := gen_random_uuid();
  adm uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid();
  v1 uuid := gen_random_uuid();
  m uuid := gen_random_uuid();
  o uuid := gen_random_uuid();
  r uuid;
  a jsonb;
  v_ob uuid;
  v_ob2 uuid;
  v_code text;
  v_count int;
  v_balance numeric;
  v_payout uuid;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),
    (u1,u1::text||'@example.invalid'),(adm,adm::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),
    (u1,u1::text||'@example.invalid'),(adm,adm::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;
  UPDATE public.users SET role='admin' WHERE id=adm;
  INSERT INTO public.admin_management(admin_id, supervisor_id, is_active)
    VALUES (adm, m_user, true);
  INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,current_latitude,current_longitude)
    VALUES (d1,u1,'Synthetic settlement driver','online',true,true,true,30,31);
  INSERT INTO public.vehicles(id,driver_id,category,plate_number,is_active)
    VALUES (v1,d1,'motorcycle','AUDIT-S',true);
  UPDATE public.drivers SET active_vehicle_id=v1, location_updated_at=now() WHERE id=d1;
  INSERT INTO public.merchants(id,name,owner_user_id,latitude,longitude,type)
    VALUES (m,'Synthetic settlement merchant',m_user,30,31,'restaurant');

  -- ── helpers: run the full cash order -> delivered flow ──────────────
  -- (inlined twice below with different merchants)

  -- ============ 1. Model A cash order: obligations + ledger credit =====
  INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
    VALUES (o,c,m,100,120,20,30.001,31.001,'cash');

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
  a := public.driver_arrive(r, d1);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'arrive failed: %', a; END IF;
  PERFORM set_config('role','none',true);

  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.delivery_handoff_code('pickup', r, NULL);
  PERFORM set_config('role','none',true);

  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.start_trip(r, d1, a->>'code');
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'start failed: %', a; END IF;
  PERFORM set_config('role','none',true);

  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.delivery_handoff_code('dropoff', r, NULL);
  PERFORM set_config('role','none',true);

  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.complete_delivery(r, d1, NULL, NULL, a->>'code');
  PERFORM set_config('role','none',true);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'completion failed: %', a; END IF;

  -- Goods obligation: total(120) - fee(20) = 100, owed to platform, due ~24h.
  SELECT id INTO v_ob FROM public.driver_obligations
   WHERE ride_id=r AND kind='goods';
  IF v_ob IS NULL THEN RAISE EXCEPTION 'no goods obligation for cash order'; END IF;
  PERFORM 1 FROM public.driver_obligations
   WHERE id=v_ob AND amount=100 AND owed_to='platform' AND status='open'
     AND due_at > now() + interval '23 hours';
  IF NOT FOUND THEN RAISE EXCEPTION 'goods obligation wrong: %',
    (SELECT row_to_json(x) FROM public.driver_obligations x WHERE id=v_ob); END IF;

  -- Commission obligation: 7% of fare(20) = 1.40 to platform.
  PERFORM 1 FROM public.driver_obligations
   WHERE ride_id=r AND kind='commission' AND amount=round(20*0.07,2)
     AND owed_to='platform' AND status='open';
  IF NOT FOUND THEN RAISE EXCEPTION 'no commission obligation for cash order'; END IF;

  -- Merchant ledger credit: subtotal 100 less 3% = 97.
  PERFORM 1 FROM public.merchant_ledger
   WHERE merchant_id=m AND order_id=o AND entry_type='credit' AND amount=97;
  IF NOT FOUND THEN RAISE EXCEPTION 'no merchant ledger credit'; END IF;

  -- Driver got the settlement notification.
  PERFORM 1 FROM public.notifications
   WHERE user_id=u1 AND type='settlement' AND data->>'ride_id'=r::text;
  IF NOT FOUND THEN RAISE EXCEPTION 'no settlement notification'; END IF;

  -- Idempotency: a second earnings pass creates nothing new.
  PERFORM public._record_delivery_earnings(r);
  SELECT count(*) INTO v_count FROM public.driver_obligations WHERE ride_id=r;
  IF v_count <> 2 THEN RAISE EXCEPTION 'obligation idempotency broken: %', v_count; END IF;

  -- ============ 2. Dispatch gate ========================================
  -- Not overdue, under ceiling: a fresh cash order still dispatches to d1.
  DECLARE
    o2 uuid := gen_random_uuid();
    r2 uuid;
  BEGIN
    INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
      VALUES (o2,c,m,50,70,20,30.001,31.001,'cash');
    PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.merchant_dispatch_order_driver(o2);
    PERFORM set_config('role','none',true);
    IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'under-ceiling dispatch blocked: %', a; END IF;
    SELECT id INTO r2 FROM public.rides WHERE order_id=o2;
    PERFORM 1 FROM public.ride_requests WHERE ride_id=r2 AND driver_id=d1;
    IF NOT FOUND THEN RAISE EXCEPTION 'under-ceiling driver not offered'; END IF;
    UPDATE public.rides SET status='cancelled' WHERE id=r2;
    DELETE FROM public.ride_requests WHERE ride_id=r2;

    -- Overdue open obligation: excluded from cash dispatch.
    UPDATE public.driver_obligations SET due_at = now() - interval '1 hour' WHERE id=v_ob;
    INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
      VALUES (gen_random_uuid(),c,m,50,70,20,30.001,31.001,'cash')
      RETURNING id INTO o2;
    PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.merchant_dispatch_order_driver(o2);
    PERFORM set_config('role','none',true);
    IF a->>'ok' = 'true' THEN
      SELECT id INTO r2 FROM public.rides WHERE order_id=o2;
      PERFORM 1 FROM public.ride_requests WHERE ride_id=r2 AND driver_id=d1 AND status IN ('offered','accepted');
      IF FOUND THEN RAISE EXCEPTION 'overdue driver offered cash dispatch'; END IF;
    END IF;

    -- ...but a NON-cash order still dispatches to him.
    INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
      VALUES (gen_random_uuid(),c,m,50,70,20,30.001,31.001,'instapay')
      RETURNING id INTO o2;
    PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.merchant_dispatch_order_driver(o2);
    PERFORM set_config('role','none',true);
    IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'non-cash dispatch wrongly gated: %', a; END IF;
    SELECT id INTO r2 FROM public.rides WHERE order_id=o2;
    PERFORM 1 FROM public.ride_requests WHERE ride_id=r2 AND driver_id=d1;
    IF NOT FOUND THEN RAISE EXCEPTION 'overdue driver lost non-cash dispatch'; END IF;
    UPDATE public.rides SET status='cancelled' WHERE id=r2;
    DELETE FROM public.ride_requests WHERE ride_id=r2;
  END;

  -- ============ 3. Escalation + suspension sweeps =======================
  -- v_ob is 1h overdue; escalation window is 24h -> not yet escalated.
  PERFORM public._settlement_escalation_sweep();
  PERFORM 1 FROM public.complaints WHERE category='settlement_overdue' AND ride_id=r;
  IF FOUND THEN RAISE EXCEPTION 'escalation fired before its window'; END IF;

  UPDATE public.driver_obligations SET due_at = now() - interval '25 hours' WHERE id=v_ob;
  PERFORM public._settlement_escalation_sweep();
  PERFORM 1 FROM public.complaints WHERE category='settlement_overdue' AND ride_id=r AND priority='high';
  IF NOT FOUND THEN RAISE EXCEPTION 'no escalation complaint'; END IF;
  PERFORM 1 FROM public.driver_obligations WHERE id=v_ob AND escalated_at IS NOT NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'escalated_at not stamped'; END IF;
  -- Second sweep: no duplicate.
  PERFORM public._settlement_escalation_sweep();
  SELECT count(*) INTO v_count FROM public.complaints WHERE category='settlement_overdue' AND ride_id=r;
  IF v_count <> 1 THEN RAISE EXCEPTION 'duplicate escalation complaints: %', v_count; END IF;

  -- Suspension review: outstanding above the 5000 setting.
  INSERT INTO public.driver_obligations(driver_id,kind,amount,owed_to,due_at)
    VALUES (d1,'goods',6000,'platform',now() + interval '1 day');
  PERFORM public._settlement_escalation_sweep();
  PERFORM 1 FROM public.complaints WHERE category='settlement_suspension_review' AND priority='urgent';
  IF NOT FOUND THEN RAISE EXCEPTION 'no suspension-review complaint'; END IF;
  PERFORM public._settlement_escalation_sweep();
  SELECT count(*) INTO v_count FROM public.complaints WHERE category='settlement_suspension_review';
  IF v_count <> 1 THEN RAISE EXCEPTION 'duplicate suspension reviews: %', v_count; END IF;

  -- ============ 4. Admin-code settlement (model A) ======================
  -- Non-admin cannot mint a code.
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.admin_create_settlement_code(v_ob);
  PERFORM set_config('role','none',true);
  IF a->>'code' IS DISTINCT FROM 'FORBIDDEN' THEN RAISE EXCEPTION 'code mint not admin-gated: %', a; END IF;

  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.admin_create_settlement_code(v_ob);
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'admin code mint failed: %', a; END IF;
  v_code := a->>'code';
  IF v_code !~ '^[0-9]{4}$' THEN RAISE EXCEPTION 'bad code shape: %', v_code; END IF;

  -- Wrong code rejected; right code settles.
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.driver_confirm_settlement(v_ob, '0000');
  IF a->>'code' IS DISTINCT FROM 'INVALID_CODE' THEN RAISE EXCEPTION 'wrong code accepted: %', a; END IF;
  a := public.driver_confirm_settlement(v_ob, v_code);
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'right code rejected: %', a; END IF;
  PERFORM 1 FROM public.driver_obligations
   WHERE id=v_ob AND status='settled' AND settled_via='admin_code' AND settlement_code IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'settlement state wrong'; END IF;

  -- ============ 5. Dispute half-weight ==================================
  -- Fresh driver d2 with ONE disputed 1500 obligation: half weight = 750
  -- (<= 1000 ceiling) so cash dispatch still reaches him; flipped back to
  -- open, 1500 > 1000 blocks him.
  SELECT id INTO v_ob2 FROM public.driver_obligations
   WHERE driver_id=d1 AND kind='goods' AND amount=6000;
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.dispute_obligation(v_ob2, 'المبلغ غلط');
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'dispute failed: %', a; END IF;
  DECLARE
    o3 uuid := gen_random_uuid();
    r3 uuid;
    u2 uuid := gen_random_uuid();
    d2 uuid := gen_random_uuid();
    v2 uuid := gen_random_uuid();
    v_obd uuid;
  BEGIN
    INSERT INTO auth.users(id,email) VALUES (u2,u2::text||'@example.invalid');
    INSERT INTO public.users(id,email) VALUES (u2,u2::text||'@example.invalid') ON CONFLICT(id) DO NOTHING;
    INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,current_latitude,current_longitude)
      VALUES (d2,u2,'Synthetic dispute driver','online',true,true,true,30,31);
    INSERT INTO public.vehicles(id,driver_id,category,plate_number,is_active)
      VALUES (v2,d2,'motorcycle','AUDIT-D',true);
    UPDATE public.drivers SET active_vehicle_id=v2, location_updated_at=now() WHERE id=d2;
    INSERT INTO public.driver_obligations(driver_id,kind,amount,owed_to,due_at)
      VALUES (d2,'goods',1500,'platform',now() + interval '1 day')
      RETURNING id INTO v_obd;
    PERFORM set_config('request.jwt.claim.sub', u2::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.dispute_obligation(v_obd, 'اختبار اعتراض');
    PERFORM set_config('role','none',true);
    IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'd2 dispute failed: %', a; END IF;

    INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
      VALUES (o3,c,m,50,70,20,30.001,31.001,'cash');
    PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.merchant_dispatch_order_driver(o3);
    PERFORM set_config('role','none',true);
    IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'disputed half-weight wrongly gated: %', a; END IF;
    SELECT id INTO r3 FROM public.rides WHERE order_id=o3;
    PERFORM 1 FROM public.ride_requests WHERE ride_id=r3 AND driver_id=d2;
    IF NOT FOUND THEN RAISE EXCEPTION 'disputed half-weight driver not offered'; END IF;
    PERFORM 1 FROM public.ride_requests WHERE ride_id=r3 AND driver_id=d1;
    IF FOUND THEN RAISE EXCEPTION 'over-ceiling d1 offered cash dispatch'; END IF;
    UPDATE public.rides SET status='cancelled' WHERE id=r3;
    DELETE FROM public.ride_requests WHERE ride_id=r3;

    -- Flip the dispute back to open: 1500 > 1000 blocks d2 now.
    UPDATE public.driver_obligations SET status='open' WHERE id=v_obd;
    INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
      VALUES (gen_random_uuid(),c,m,50,70,20,30.001,31.001,'cash')
      RETURNING id INTO o3;
    PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.merchant_dispatch_order_driver(o3);
    PERFORM set_config('role','none',true);
    IF a->>'ok' = 'true' THEN
      SELECT id INTO r3 FROM public.rides WHERE order_id=o3;
      PERFORM 1 FROM public.ride_requests WHERE ride_id=r3 AND driver_id=d2 AND status IN ('offered','accepted');
      IF FOUND THEN RAISE EXCEPTION 'over-ceiling d2 offered cash dispatch'; END IF;
    END IF;
  END;

  -- ============ 6. Merchant model switch guard ==========================
  -- m has a 97 ledger credit: switching to direct is blocked.
  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.merchant_set_settlement_model('direct');
  IF a->>'code' IS DISTINCT FROM 'UNPAID_BALANCE' THEN
    RAISE EXCEPTION 'model switch not blocked by balance: %', a;
  END IF;
  PERFORM set_config('role','none',true);

  -- ============ 7. Payout request + approval ============================
  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.merchant_request_payout(1000);
  IF a->>'code' IS DISTINCT FROM 'INSUFFICIENT_BALANCE' THEN
    RAISE EXCEPTION 'over-balance payout allowed: %', a;
  END IF;
  a := public.merchant_request_payout(50);
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'payout request failed: %', a; END IF;
  v_payout := (a->>'id')::uuid;

  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.admin_review_payout(v_payout, true);
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'payout approval failed: %', a; END IF;
  PERFORM 1 FROM public.merchant_ledger
   WHERE merchant_id=m AND entry_type='debit' AND amount=50;
  IF NOT FOUND THEN RAISE EXCEPTION 'payout debit missing'; END IF;

  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.get_my_merchant_ledger();
  PERFORM set_config('role','none',true);
  IF (a->>'balance')::numeric <> 47 THEN RAISE EXCEPTION 'ledger balance wrong: %', a; END IF;

  -- Balance now spent: model switch to direct succeeds.
  -- (balance 47 > 0 still blocks; pay it out first)
  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.merchant_request_payout(47);
  v_payout := (a->>'id')::uuid;
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'second payout failed: %', a; END IF;
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  PERFORM set_config('role','authenticated',true);
  PERFORM public.admin_review_payout(v_payout, true);
  PERFORM set_config('role','none',true);
  PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.merchant_set_settlement_model('direct');
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'model switch after zeroing failed: %', a; END IF;

  -- ============ 8. Model B: merchant confirms / reports =================
  DECLARE
    o4 uuid := gen_random_uuid();
    r4 uuid;
    v_obm uuid;
    u3 uuid := gen_random_uuid();
    d3 uuid := gen_random_uuid();
    v3 uuid := gen_random_uuid();
  BEGIN
    -- d1 (6000 disputed) and d2 (1500 open) are both over the cash ceiling by
    -- design; the model-B flow needs a clean driver.
    INSERT INTO auth.users(id,email) VALUES (u3,u3::text||'@example.invalid');
    INSERT INTO public.users(id,email) VALUES (u3,u3::text||'@example.invalid') ON CONFLICT(id) DO NOTHING;
    INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,current_latitude,current_longitude)
      VALUES (d3,u3,'Synthetic model-B driver','online',true,true,true,30,31);
    INSERT INTO public.vehicles(id,driver_id,category,plate_number,is_active)
      VALUES (v3,d3,'motorcycle','AUDIT-B',true);
    UPDATE public.drivers SET active_vehicle_id=v3, location_updated_at=now() WHERE id=d3;
    INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
      VALUES (o4,c,m,100,120,20,30.001,31.001,'cash');
    PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.merchant_dispatch_order_driver(o4);
    PERFORM set_config('role','none',true);
    IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'model B dispatch failed: %', a; END IF;
    SELECT id INTO r4 FROM public.rides WHERE order_id=o4;
    PERFORM set_config('request.jwt.claim.sub', u3::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.accept_ride_request(r4, d3);
    a := public.driver_arrive(r4, d3);
    PERFORM set_config('role','none',true);
    PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.delivery_handoff_code('pickup', r4, NULL);
    PERFORM set_config('role','none',true);
    PERFORM set_config('request.jwt.claim.sub', u3::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.start_trip(r4, d3, a->>'code');
    PERFORM set_config('role','none',true);
    PERFORM set_config('request.jwt.claim.sub', c::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.delivery_handoff_code('dropoff', r4, NULL);
    PERFORM set_config('role','none',true);
    PERFORM set_config('request.jwt.claim.sub', u3::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.complete_delivery(r4, d3, NULL, NULL, a->>'code');
    PERFORM set_config('role','none',true);
    IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'model B completion failed: %', a; END IF;

    -- Goods owed to the MERCHANT now; no ledger credit in model B.
    SELECT id INTO v_obm FROM public.driver_obligations
     WHERE ride_id=r4 AND kind='goods' AND owed_to='merchant';
    IF v_obm IS NULL THEN RAISE EXCEPTION 'model B obligation not owed to merchant'; END IF;
    PERFORM 1 FROM public.merchant_ledger WHERE order_id=o4;
    IF FOUND THEN RAISE EXCEPTION 'model B wrongly credited the ledger'; END IF;

    -- Driver cannot self-confirm; merchant confirms.
    PERFORM set_config('request.jwt.claim.sub', u3::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.merchant_confirm_obligation_paid(v_obm);
    IF a->>'code' IS DISTINCT FROM 'FORBIDDEN' THEN RAISE EXCEPTION 'driver self-confirmed: %', a; END IF;
    PERFORM set_config('role','none',true);
    PERFORM set_config('request.jwt.claim.sub', m_user::text, true);
    PERFORM set_config('role','authenticated',true);
    a := public.merchant_report_obligation_unpaid(v_obm, 'لسه مادفعش');
    IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'unpaid report failed: %', a; END IF;
    a := public.merchant_confirm_obligation_paid(v_obm);
    PERFORM set_config('role','none',true);
    IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'merchant confirm failed: %', a; END IF;
    PERFORM 1 FROM public.driver_obligations
     WHERE id=v_obm AND status='settled' AND settled_via='merchant_confirm';
    IF NOT FOUND THEN RAISE EXCEPTION 'merchant settle state wrong'; END IF;
    PERFORM 1 FROM public.complaints WHERE category='settlement_unpaid' AND ride_id=r4;
    IF NOT FOUND THEN RAISE EXCEPTION 'unpaid complaint missing'; END IF;
  END;

  -- ============ 9. RLS + privilege guards ===============================
  -- Driver reads his own obligations via RLS; the customer sees none.
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  PERFORM set_config('role','authenticated',true);
  PERFORM 1 FROM public.driver_obligations WHERE driver_id=d1;
  IF NOT FOUND THEN RAISE EXCEPTION 'driver cannot read own obligations'; END IF;
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);
  PERFORM 1 FROM public.driver_obligations WHERE driver_id=d1;
  IF FOUND THEN RAISE EXCEPTION 'customer sees driver obligations'; END IF;
  -- Direct writes are revoked.
  BEGIN
    INSERT INTO public.driver_obligations(driver_id,kind,amount,owed_to,due_at)
      VALUES (d1,'goods',1,'platform',now());
    RAISE EXCEPTION 'authenticated direct insert into driver_obligations';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.merchant_ledger(merchant_id,entry_type,amount)
      VALUES (m,'credit',1);
    RAISE EXCEPTION 'authenticated direct insert into merchant_ledger';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('role','none',true);

  -- Admin waive: logged and terminal.
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.admin_waive_obligation(v_ob2, 'اختبار شطب');
  PERFORM set_config('role','none',true);
  IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'waive failed: %', a; END IF;
  PERFORM 1 FROM public.driver_obligations WHERE id=v_ob2 AND status='waived';
  IF NOT FOUND THEN RAISE EXCEPTION 'waive state wrong'; END IF;

  RAISE NOTICE 'settlement_system_regression: all assertions passed';
END $$;
ROLLBACK;
