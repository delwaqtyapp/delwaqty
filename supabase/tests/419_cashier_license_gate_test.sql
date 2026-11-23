-- 419 v2: license eligibility matrix, per-op lock behavior, suspend cascade,
-- status-oracle guard (reviews #119/#128 + security notes). Wrapped.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid(); m uuid := gen_random_uuid(); other uuid := gen_random_uuid();
  v_r jsonb; v_err text; v_sale uuid := gen_random_uuid(); v_void uuid := gen_random_uuid();
  v_pay uuid := gen_random_uuid();
  v_saleop jsonb; v_voidop jsonb; v_payop jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u::text||'@x.i'),(other,other::text||'@x.i');
  INSERT INTO public.users(id,email,role) VALUES (u,u::text||'@x.i','merchant'),(other,other::text||'@x.i','customer')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.merchants(id,owner_user_id,name,type) VALUES (m,u,'419','grocery');

  v_saleop := jsonb_build_object('type','sale','op_id',v_sale,'created_offline_at',now(),
    'payload', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('product_id',NULL,'qty',1,'unit_price',10,'name','X','discount_amount',0,'is_weight_based',false)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount',10))));
  v_voidop := jsonb_build_object('type','sale_void','op_id',v_void,'created_offline_at',now(),
    'payload', jsonb_build_object('sale_op_id', v_sale::text, 'reason','419 void'));
  v_payop := jsonb_build_object('type','debt_payment','op_id',v_pay,'created_offline_at',now(),
    'payload', jsonb_build_object('customer_id', NULL, 'amount', 1));

  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', u::text, true);

  -- no oracle and no bypass: authenticated callers cannot EXECUTE the
  -- helpers directly at all, with or without a uid (grants revoked).
  PERFORM set_config('request.jwt.claim.sub', other::text, true);
  BEGIN PERFORM public.cashier_license_check(m); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '419: authenticated called check: ' || v_err;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  BEGIN PERFORM public.cashier_license_check(m); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '419: no-uid bypass of check: ' || v_err;
  PERFORM set_config('request.jwt.claim.sub', other::text, true);
  BEGIN PERFORM public.cashier_license_gate(m); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '419: authenticated called gate: ' || v_err;
  BEGIN PERFORM public._cashier_has_pro(m); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '419: authenticated called has_pro: ' || v_err;
  PERFORM set_config('request.jwt.claim.sub', u::text, true);

  -- no license: gated op refused per-op with LICENSE_REQUIRED (no raise)
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_saleop));
  ASSERT v_r->'results'->0->>'reason' = 'LICENSE_REQUIRED'
     AND NOT (v_r->'results'->0->>'ok')::boolean, '419: no-license sale not refused: ' || v_r::text;
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales WHERE merchant_id=m), '419: refused sale wrote a row';

  -- daily_close still hard-raises
  BEGIN v_r := public.cashier_daily_close(m, gen_random_uuid(), 0); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err = 'LICENSE_REQUIRED', '419: daily_close not gated: ' || v_err;

  -- suspended only: sale refused LICENSE_SUSPENDED, but recovery ops apply
  PERFORM set_config('role','none',true);
  INSERT INTO public.cashier_licenses(merchant_id,license_key,plan,status,grace_days)
  VALUES (m,'419-K1','trial','suspended',7);
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_saleop));
  ASSERT v_r->'results'->0->>'reason' = 'LICENSE_SUSPENDED', '419: suspended not refused: ' || v_r::text;

  -- active past grace -> LICENSE_EXPIRED
  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET status='active', expires_at=now()-interval '30 days', grace_days=7 WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_saleop));
  ASSERT v_r->'results'->0->>'reason' = 'LICENSE_EXPIRED', '419: past-grace active not refused: ' || v_r::text;

  -- active in grace -> allowed
  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET expires_at=now()-interval '2 days', grace_days=7 WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_saleop));
  ASSERT (v_r->'results'->0->>'ok')::boolean, '419: in-grace active refused: ' || v_r::text;

  -- expired status INSIDE grace -> allowed (validate grace_until contract)
  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET status='expired', expires_at=now()-interval '1 days', grace_days=7 WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_saleop));
  ASSERT (v_r->'results'->0->>'ok')::boolean, '419: expired-in-grace refused: ' || v_r::text;

  -- expired status with FUTURE expires_at = inconsistent data: fail closed
  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET status='expired', expires_at=now()+interval '30 days' WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_saleop));
  ASSERT v_r->'results'->0->>'reason' = 'LICENSE_EXPIRED', '419: inconsistent expired row not refused: ' || v_r::text;

  -- issued with NULL expires_at = lifetime -> allowed
  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET status='issued', expires_at=NULL WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_saleop));
  ASSERT (v_r->'results'->0->>'ok')::boolean, '419: lifetime issued refused: ' || v_r::text;
  ASSERT EXISTS (SELECT 1 FROM public.pos_sales WHERE merchant_id=m AND idempotency_key=v_sale::text AND status='completed'),
    '419: unlocked sale not recorded';

  -- suspended sibling does NOT block a valid license (the check predicate
  -- in isolation; suspension itself stays per-license - no cascade).
  PERFORM set_config('role','none',true);
  INSERT INTO public.cashier_licenses(merchant_id,license_key,plan,status,grace_days)
  VALUES (m,'419-K2','core_monthly','suspended',7);
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_saleop));
  ASSERT (v_r->'results'->0->>'ok')::boolean, '419: suspended sibling blocked valid license: ' || v_r::text;

  -- mixed batch while LOCKED: void applies, new sale refused, batch intact.
  -- Lock the merchant by suspending every row (cascade should also do it).
  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET status='suspended' WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_voidop, v_saleop));
  ASSERT (v_r->'results'->0->>'ok')::boolean, '419: void blocked while locked: ' || v_r::text;
  ASSERT v_r->'results'->1->>'reason' = 'LICENSE_SUSPENDED'
     AND NOT (v_r->'results'->1->>'ok')::boolean, '419: new sale not refused while locked: ' || v_r::text;
  PERFORM set_config('role','none',true);
  ASSERT EXISTS (SELECT 1 FROM public.pos_sales WHERE merchant_id=m AND idempotency_key=v_sale::text AND status='voided'),
    '419: void did not apply while locked';
  ASSERT (SELECT count(*) FROM public.pos_sales WHERE merchant_id=m) = 1,
    '419: locked batch wrote an extra sale';
  PERFORM set_config('role','authenticated',true);

  -- debt_payment allowed while locked (fails only on its own merits:
  -- unresolved customer here -> CUSTOMER_UNRESOLVED, NOT a license refusal)
  v_r := public.cashier_sync_push(m, jsonb_build_array(v_payop));
  ASSERT v_r->'results'->0->>'reason' = 'CUSTOMER_UNRESOLVED', '419: payment hit license gate: ' || v_r::text;

  -- daily_close raises while locked
  BEGIN v_r := public.cashier_daily_close(m, gen_random_uuid(), 0); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err = 'LICENSE_SUSPENDED', '419: daily_close not locked: ' || v_err;

  -- suspension stays per-license (no cascade trigger exists)
  ASSERT NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                      WHERE n.nspname='public' AND p.proname='_cashier_license_cascade_suspend'),
    '419: rejected cascade function still present';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='cashier_licenses_cascade_suspend' AND NOT tgisinternal),
    '419: rejected cascade trigger still present';

END $$;
SELECT '419 v2 matrix passed' AS result;
ROLLBACK;
