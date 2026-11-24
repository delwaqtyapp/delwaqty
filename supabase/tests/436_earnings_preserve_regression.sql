-- Run after migration 436, and against the pre-436 schema: it must pass
-- IDENTICALLY on both, proving the replaced _record_delivery_earnings
-- (395 body + the marked 436 block) preserves every existing settlement
-- path (#206/B1): cash platform-model merchant orders, the direct model,
-- the 188 replacement-driver delay waiver, and the 395 gift-credit
-- netting (cash and non-cash). Rollback-only synthetic fixtures; all
-- statements run as the migration role, no auth context needed.
BEGIN;
INSERT INTO public.commission_rules(entity_type,entity_key,rate,is_active,effective_from)
VALUES('account_type','driver',7,true,current_date),
      ('account_type','merchant',3,true,current_date);
DO $$
DECLARE
  c uuid := gen_random_uuid();
  m_user uuid := gen_random_uuid();
  u1 uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid();
  m1 uuid := gen_random_uuid();
  m2 uuid := gen_random_uuid();
  o1 uuid := gen_random_uuid();
  o2 uuid := gen_random_uuid();
  o3 uuid := gen_random_uuid();
  o4 uuid := gen_random_uuid();
  r1 uuid := gen_random_uuid();
  r2 uuid := gen_random_uuid();
  r3 uuid := gen_random_uuid();
  r4 uuid := gen_random_uuid();
  v_amt numeric;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),
    (u1,u1::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),
    (u1,u1::text||'@example.invalid') ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries)
    VALUES (d1,u1,'Synthetic preserve driver','online',true,true,true);
  INSERT INTO public.merchants(id,name,owner_user_id,latitude,longitude,type)
    VALUES (m1,'Synthetic platform merchant',m_user,30,31,'restaurant');
  INSERT INTO public.merchants(id,name,owner_user_id,latitude,longitude,type,settlement_model)
    VALUES (m2,'Synthetic direct merchant',m_user,30,31,'restaurant','direct');

  INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,
    delivery_latitude,delivery_longitude,payment_method)
    VALUES (o1,c,m1,100,120,20,30.001,31.001,'cash');
  INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,
    delivery_latitude,delivery_longitude,payment_method,platform_credit_applied)
    VALUES (o2,c,m2,200,240,40,30.001,31.001,'cash',30);
  INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,
    delivery_latitude,delivery_longitude,payment_method,platform_credit_applied)
    VALUES (o3,c,m1,100,120,20,30.001,31.001,'cash',50);
  INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,
    delivery_latitude,delivery_longitude,payment_method,platform_credit_applied)
    VALUES (o4,c,m1,100,120,20,30.001,31.001,'instapay',25);

  INSERT INTO public.rides(id,rider_id,driver_id,pickup_latitude,pickup_longitude,
    pickup_address,dropoff_latitude,dropoff_longitude,dropoff_address,ride_type,
    service_type,status,fare,order_id,payment_method,completed_at,delivered_at)
  VALUES
    (r1,c,d1,30.0,31.0,'p',30.1,31.1,'d','motorcycle','courier','completed',20,o1,'cash',now(),now()),
    (r2,c,d1,30.0,31.0,'p',30.1,31.1,'d','motorcycle','courier','completed',20,o2,'cash',now(),now()),
    (r3,c,d1,30.0,31.0,'p',30.1,31.1,'d','motorcycle','courier','completed',20,o3,'cash',now(),now()),
    (r4,c,d1,30.0,31.0,'p',30.1,31.1,'d','motorcycle','courier','completed',20,o4,'instapay',now(),now());

  -- 188: r3's order was redispatched for a delay - the replacement
  -- driver's commission is waived.
  INSERT INTO public.driver_delay_events(ride_id,order_id,driver_id,reported_by,reason,within_allowance,monthly_count)
    VALUES (r3,o3,d1,'merchant','synthetic delay',false,1);

  PERFORM public._record_delivery_earnings(r1);
  PERFORM public._record_delivery_earnings(r2);
  PERFORM public._record_delivery_earnings(r3);
  PERFORM public._record_delivery_earnings(r4);

  -- ── r1: cash, platform merchant, no credit ──
  IF (SELECT amount FROM public.driver_earnings WHERE ride_id = r1)
       IS DISTINCT FROM 18.60::numeric THEN
    RAISE EXCEPTION 'r1: driver earning != 20 less 7%%';
  END IF;
  IF (SELECT commission_amount FROM public.platform_commissions
       WHERE reference_type = 'ride' AND reference_id = r1)
       IS DISTINCT FROM 1.40::numeric THEN
    RAISE EXCEPTION 'r1: ride commission != 1.40';
  END IF;
  IF (SELECT commission_amount FROM public.platform_commissions
       WHERE reference_type = 'order' AND reference_id = o1)
       IS DISTINCT FROM 3.00::numeric THEN
    RAISE EXCEPTION 'r1: merchant commission != 3.00';
  END IF;
  IF (SELECT amount FROM public.driver_obligations
       WHERE ride_id = r1 AND kind = 'goods')
       IS DISTINCT FROM 100.00::numeric
     OR (SELECT owed_to FROM public.driver_obligations
       WHERE ride_id = r1 AND kind = 'goods') IS DISTINCT FROM 'platform' THEN
    RAISE EXCEPTION 'r1: goods obligation != 100 to platform';
  END IF;
  IF (SELECT amount FROM public.driver_obligations
       WHERE ride_id = r1 AND kind = 'commission')
       IS DISTINCT FROM 1.40::numeric THEN
    RAISE EXCEPTION 'r1: commission obligation != 1.40';
  END IF;
  IF (SELECT amount FROM public.merchant_ledger
       WHERE order_id = o1 AND entry_type = 'credit')
       IS DISTINCT FROM 97.00::numeric THEN
    RAISE EXCEPTION 'r1: merchant ledger credit != 97.00';
  END IF;
  IF EXISTS (SELECT 1 FROM public.platform_subsidies WHERE order_id = o1) THEN
    RAISE EXCEPTION 'r1: unexpected subsidy row';
  END IF;

  -- ── r2: cash, DIRECT merchant, credit 30 ──
  -- goods_pre = 240 + 30 - 40 = 230; goods owed = 230 - 30 = 200.
  IF (SELECT amount FROM public.driver_obligations
       WHERE ride_id = r2 AND kind = 'goods')
       IS DISTINCT FROM 200.00::numeric
     OR (SELECT owed_to FROM public.driver_obligations
       WHERE ride_id = r2 AND kind = 'goods') IS DISTINCT FROM 'merchant' THEN
    RAISE EXCEPTION 'r2: goods obligation != 200 to merchant (direct model)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.merchant_ledger WHERE order_id = o2) THEN
    RAISE EXCEPTION 'r2: direct model must not write merchant_ledger';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.platform_subsidies
       WHERE order_id = o2 AND kind = 'delay_apology_credit'
         AND amount = 30 AND settlement_model = 'direct'
         AND reimburses = 'driver' AND remittance_reduction = 30
         AND driver_payable = 0 AND merchant_payable = 30
         AND status = 'netted') THEN
    RAISE EXCEPTION 'r2: direct-model subsidy row wrong';
  END IF;

  -- ── r3: cash, platform merchant, credit 50, DELAY WAIVER ──
  -- The replacement driver pays no commission: full 20 earning.
  IF (SELECT amount FROM public.driver_earnings WHERE ride_id = r3)
       IS DISTINCT FROM 20.00::numeric THEN
    RAISE EXCEPTION 'r3: 188 waiver lost - earning != full fare';
  END IF;
  IF (SELECT commission_amount FROM public.platform_commissions
       WHERE reference_type = 'ride' AND reference_id = r3)
       IS DISTINCT FROM 0.00::numeric THEN
    RAISE EXCEPTION 'r3: 188 waiver lost - ride commission != 0';
  END IF;
  IF EXISTS (SELECT 1 FROM public.driver_obligations
              WHERE ride_id = r3 AND kind = 'commission') THEN
    RAISE EXCEPTION 'r3: commission obligation booked despite the waiver';
  END IF;
  -- goods_pre = 120 + 50 - 20 = 150; goods owed = 150 - 50 = 100.
  IF (SELECT amount FROM public.driver_obligations
       WHERE ride_id = r3 AND kind = 'goods')
       IS DISTINCT FROM 100.00::numeric THEN
    RAISE EXCEPTION 'r3: goods obligation != 100 after credit netting';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.platform_subsidies
       WHERE order_id = o3 AND kind = 'delay_apology_credit'
         AND amount = 50 AND settlement_model = 'platform'
         AND remittance_reduction = 50 AND driver_payable = 0
         AND merchant_payable = 0 AND status = 'netted') THEN
    RAISE EXCEPTION 'r3: platform-model subsidy row wrong';
  END IF;
  IF (SELECT amount FROM public.merchant_ledger
       WHERE order_id = o3 AND entry_type = 'credit')
       IS DISTINCT FROM 97.00::numeric THEN
    RAISE EXCEPTION 'r3: merchant ledger credit != 97.00';
  END IF;

  -- ── r4: NON-cash, credit 25: no remittance, accounting-only subsidy ──
  IF EXISTS (SELECT 1 FROM public.driver_obligations
              WHERE ride_id = r4 AND kind = 'goods') THEN
    RAISE EXCEPTION 'r4: non-cash order booked a goods obligation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.platform_subsidies
       WHERE order_id = o4 AND kind = 'delay_apology_credit'
         AND amount = 25 AND remittance_reduction = 0
         AND driver_payable = 0 AND merchant_payable = 0
         AND status = 'netted_noncash') THEN
    RAISE EXCEPTION 'r4: non-cash subsidy row wrong';
  END IF;

  -- ── Idempotence on every ride ──
  PERFORM public._record_delivery_earnings(r1);
  PERFORM public._record_delivery_earnings(r2);
  PERFORM public._record_delivery_earnings(r3);
  PERFORM public._record_delivery_earnings(r4);
  -- r1, r2 and r3 each book one goods obligation (r4 is non-cash);
  -- r2, r3 and r4 each book one subsidy row.
  IF (SELECT count(*) FROM public.driver_earnings
       WHERE ride_id IN (r1, r2, r3, r4)) <> 4
     OR (SELECT count(*) FROM public.driver_obligations
       WHERE ride_id IN (r1, r2, r3, r4) AND kind = 'goods') <> 3
     OR (SELECT count(*) FROM public.platform_subsidies
       WHERE order_id IN (o2, o3, o4)) <> 3 THEN
    RAISE EXCEPTION 'earnings accrual not idempotent across all paths';
  END IF;

  RAISE NOTICE '436 earnings-preserve regression: ALL CHECKS PASSED';
END $$;
ROLLBACK;
