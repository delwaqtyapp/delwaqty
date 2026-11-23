-- 420: offline customer id resolution + shift_open duplicate id
-- (reviews #118/#117b). Transaction-wrapped.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid(); m uuid := gen_random_uuid();
  c1 uuid := gen_random_uuid(); s1 uuid := gen_random_uuid();
  v_sale uuid := gen_random_uuid(); v_pay uuid := gen_random_uuid();
  v_bad uuid := gen_random_uuid(); v_bad2 uuid := gen_random_uuid();
  v_cash_sale uuid := gen_random_uuid();
  v_ops jsonb; v_r jsonb; v_cust uuid;
  v_shift_a uuid; v_shift_b uuid;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u::text||'@x.i');
  INSERT INTO public.users(id,email,role) VALUES (u,u::text||'@x.i','merchant') ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.merchants(id,owner_user_id,name,type) VALUES (m,u,'420','grocery');
  INSERT INTO public.cashier_licenses(merchant_id, license_key, plan, status, grace_days)
  VALUES (m,'420-K1','trial','active',7);
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', u::text, true);

  -- batch: customer, deferred sale referencing the CUSTOMER OP id,
  -- debt_payment referencing the same, shift_open, duplicate shift_open
  v_ops := jsonb_build_array(
    jsonb_build_object('type','customer','op_id',c1,'created_offline_at',now(),
      'payload', jsonb_build_object('name','Offline Ziad','phone','0100')),
    jsonb_build_object('type','sale','op_id',v_sale,'created_offline_at',now(),
      'payload', jsonb_build_object(
        'items', jsonb_build_array(jsonb_build_object('product_id',NULL,'qty',2,'unit_price',10,'name','X','discount_amount',0,'is_weight_based',false)),
        'payments', jsonb_build_array(jsonb_build_object('method','deferred','amount',20)),
        'customer_id', c1::text, 'customer_name','Offline Ziad')),
    jsonb_build_object('type','debt_payment','op_id',v_pay,'created_offline_at',now(),
      'payload', jsonb_build_object('customer_id', c1::text, 'amount', 5, 'note','دفعة')),
    jsonb_build_object('type','shift_open','op_id',s1,'created_offline_at',now(),
      'payload', jsonb_build_object('opening_float',100)),
    jsonb_build_object('type','shift_open','op_id',s1,'created_offline_at',now(),
      'payload', jsonb_build_object('opening_float',100))
  );
  v_r := public.cashier_sync_push(m, v_ops);
  ASSERT (v_r->>'ok')::boolean, '420: batch call failed';
  ASSERT (SELECT count(*) FROM jsonb_array_elements(v_r->'results') e WHERE (e->>'ok')::boolean) = 5,
    '420: not all ops ok: ' || v_r::text;

  -- customer created under the client op id; sale + ledger rows resolved
  SELECT id INTO v_cust FROM public.pos_customers WHERE merchant_id=m AND client_op_id=c1;
  ASSERT v_cust IS NOT NULL, '420: customer op not applied';
  ASSERT EXISTS (SELECT 1 FROM public.pos_sales WHERE merchant_id=m AND idempotency_key=v_sale::text AND pos_customer_id=v_cust),
    '420: sale customer not resolved';
  ASSERT EXISTS (SELECT 1 FROM public.pos_debt_ledger WHERE merchant_id=m AND sale_id IS NOT NULL AND kind='charge' AND amount=20 AND customer_id=v_cust),
    '420: deferred charge not resolved to server customer';
  ASSERT EXISTS (SELECT 1 FROM public.pos_debt_ledger WHERE merchant_id=m AND client_op_id=v_pay AND kind='payment' AND amount=5 AND customer_id=v_cust),
    '420: debt payment not resolved to server customer';

  -- duplicate shift_open returns the existing shift id
  SELECT (e->>'shift_id')::uuid INTO v_shift_a FROM jsonb_array_elements(v_r->'results') e
   WHERE e->>'op_id' = s1::text LIMIT 1;
  ASSERT v_shift_a IS NOT NULL, '420: shift_open returned no id';
  v_r := public.cashier_sync_push(m, jsonb_build_array(
    jsonb_build_object('type','shift_open','op_id',s1,'created_offline_at',now(),
      'payload', jsonb_build_object('opening_float',100))));
  SELECT (e->>'shift_id')::uuid INTO v_shift_b FROM jsonb_array_elements(v_r->'results') e
   WHERE e->>'op_id' = s1::text LIMIT 1;
  ASSERT v_shift_b IS NOT NULL AND v_shift_b = v_shift_a, '420: duplicate shift_open did not return existing id';

  -- sale referencing the SERVER customer id directly still works
  v_r := public.cashier_sync_push(m, jsonb_build_array(
    jsonb_build_object('type','sale','op_id',v_cash_sale,'created_offline_at',now(),
      'payload', jsonb_build_object(
        'items', jsonb_build_array(jsonb_build_object('product_id',NULL,'qty',1,'unit_price',7,'name','Y','discount_amount',0,'is_weight_based',false)),
        'payments', jsonb_build_array(jsonb_build_object('method','cash','amount',7)),
        'customer_id', v_cust::text))));
  ASSERT (v_r->'results'->0->>'ok')::boolean, '420: server-id sale failed: ' || v_r::text;
  ASSERT EXISTS (SELECT 1 FROM public.pos_sales WHERE merchant_id=m AND idempotency_key=v_cash_sale::text AND pos_customer_id=v_cust),
    '420: server-id sale customer lost';

  -- deferred sale with an UNRESOLVABLE customer: whole op fails, no sale row
  v_r := public.cashier_sync_push(m, jsonb_build_array(
    jsonb_build_object('type','sale','op_id',v_bad,'created_offline_at',now(),
      'payload', jsonb_build_object(
        'items', jsonb_build_array(jsonb_build_object('product_id',NULL,'qty',1,'unit_price',9,'name','Z','discount_amount',0,'is_weight_based',false)),
        'payments', jsonb_build_array(jsonb_build_object('method','deferred','amount',9)),
        'customer_id', gen_random_uuid()::text))));
  ASSERT NOT (v_r->'results'->0->>'ok')::boolean
     AND v_r->'results'->0->>'reason' = 'CUSTOMER_UNRESOLVED',
    '420: unresolved deferred sale not refused: ' || v_r::text;
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales WHERE merchant_id=m AND idempotency_key=v_bad::text),
    '420: refused deferred sale left a pos_sales row';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_debt_ledger WHERE merchant_id=m AND amount=9),
    '420: refused deferred sale left a ledger row';

  -- debt_payment with an UNRESOLVABLE customer fails the same way
  v_r := public.cashier_sync_push(m, jsonb_build_array(
    jsonb_build_object('type','debt_payment','op_id',v_bad2,'created_offline_at',now(),
      'payload', jsonb_build_object('customer_id', gen_random_uuid()::text, 'amount', 3))));
  ASSERT NOT (v_r->'results'->0->>'ok')::boolean
     AND v_r->'results'->0->>'reason' = 'CUSTOMER_UNRESOLVED',
    '420: unresolved payment not refused: ' || v_r::text;

  -- 420 v2 (review #129): ANY deferred amount without a resolved customer
  -- is refused - omitted, null, blank, unknown and foreign references
  -- alike - with zero side effects (no sale, payments, stock, debt,
  -- commission rows).
  PERFORM set_config('role','none',true);
  DECLARE
    m2 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); foreign_cust uuid := gen_random_uuid();
    n_sales int; n_pay int; n_moves int; n_debt int; n_comm int;
  BEGIN
    INSERT INTO auth.users(id,email) VALUES (u2,u2::text||'@x.i');
    INSERT INTO public.users(id,email,role) VALUES (u2,u2::text||'@x.i','merchant') ON CONFLICT(id) DO NOTHING;
    INSERT INTO public.merchants(id,owner_user_id,name,type) VALUES (m2,u2,'420b','grocery');
    INSERT INTO public.pos_customers(id,merchant_id,name) VALUES (foreign_cust,m2,'Someone else');
    SELECT (SELECT count(*) FROM public.pos_sales WHERE merchant_id=m),
           (SELECT count(*) FROM public.pos_sale_payments p JOIN public.pos_sales s2 ON s2.id=p.sale_id WHERE s2.merchant_id=m),
           (SELECT count(*) FROM public.pos_stock_moves WHERE merchant_id=m),
           (SELECT count(*) FROM public.pos_debt_ledger WHERE merchant_id=m),
           (SELECT count(*) FROM public.platform_commissions c JOIN public.merchants mm ON mm.owner_user_id=c.member_id WHERE mm.id=m)
      INTO n_sales, n_pay, n_moves, n_debt, n_comm;
    PERFORM set_config('role','authenticated',true);
    PERFORM set_config('request.jwt.claim.sub', u::text, true);
    FOR v_r IN
      SELECT public.cashier_sync_push(m, jsonb_build_array(
        jsonb_build_object('type','sale','op_id',gen_random_uuid(),'created_offline_at',now(),
          'payload', jsonb_build_object(
            'items', jsonb_build_array(jsonb_build_object('product_id',NULL,'qty',1,'unit_price',9,'name','Z','discount_amount',0,'is_weight_based',false)),
            'payments', jsonb_build_array(jsonb_build_object('method','deferred','amount',9)))
            || CASE t.k WHEN 'omit' THEN '{}'::jsonb ELSE jsonb_build_object('customer_id', t.v) END)))
      FROM (VALUES ('omit',NULL),('null',NULL),('blank',''),('unknown',gen_random_uuid()::text),('foreign',foreign_cust::text)) AS t(k,v)
    LOOP
      ASSERT NOT (v_r->'results'->0->>'ok')::boolean
         AND v_r->'results'->0->>'reason' = 'CUSTOMER_UNRESOLVED',
        '420v2: deferred sale not refused: ' || v_r::text;
    END LOOP;
    PERFORM set_config('role','none',true);
    ASSERT (SELECT count(*) FROM public.pos_sales WHERE merchant_id=m) = n_sales
       AND (SELECT count(*) FROM public.pos_sale_payments p JOIN public.pos_sales s2 ON s2.id=p.sale_id WHERE s2.merchant_id=m) = n_pay
       AND (SELECT count(*) FROM public.pos_stock_moves WHERE merchant_id=m) = n_moves
       AND (SELECT count(*) FROM public.pos_debt_ledger WHERE merchant_id=m) = n_debt
       AND (SELECT count(*) FROM public.platform_commissions c JOIN public.merchants mm ON mm.owner_user_id=c.member_id WHERE mm.id=m) = n_comm,
      '420v2: refused deferred sales left side effects';
  END;
END $$;
SELECT '420 customer resolution matrix passed' AS result;
ROLLBACK;
