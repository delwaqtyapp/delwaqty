-- 415 regression: atomic coupon usage cap, duplicate compensation, payment
-- rails (cash/instapay/vodafone_cash only; wallet/card/NULL rejected with the
-- exact error codes the client localizes). Fixtures roll back.
BEGIN;
DO $$
DECLARE
  c1 uuid := gen_random_uuid(); c2 uuid := gen_random_uuid(); c3 uuid := gen_random_uuid();
  o  uuid := gen_random_uuid(); mer uuid := gen_random_uuid();
  pr1 uuid := gen_random_uuid();
  cpA uuid := gen_random_uuid(); cpB uuid := gen_random_uuid();
  v_res jsonb; v_err text;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (c1,c1::text||'@x.i'),(c2,c2::text||'@x.i'),(c3,c3::text||'@x.i'),(o,o::text||'@x.i');
  INSERT INTO public.users(id,email,role) VALUES
    (c1,c1::text||'@x.i','customer'),(c2,c2::text||'@x.i','customer'),
    (c3,c3::text||'@x.i','customer'),(o,o::text||'@x.i','merchant') ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.merchants(id, owner_user_id, name, delivery_fee, min_order,status,is_open)
    VALUES (mer, o, 'm415 Store', 15, 20,'active',true);
  INSERT INTO public.products(id, merchant_id, name, price, is_available, stock_quantity)
    VALUES (pr1, mer, 'Item A', 50, true, 10);
  INSERT INTO public.coupons(id, code, discount_type, discount_value, minimum_order,
      maximum_discount, usage_limit, used_count, merchant_id, is_active)
    VALUES (cpA, 'M415LIM2', 'percentage', 10, 0, NULL, 2, 0, NULL, true),
           (cpB, 'M415MIN500', 'percentage', 10, 500, NULL, NULL, 0, NULL, true);

  -- ── redeem_coupon: self-only, cap, duplicate compensation ────────────────
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', c1::text, true);
  v_res := public.redeem_coupon('M415LIM2', c1);
  ASSERT (v_res->>'success')::boolean, '415: first redeem failed: %', v_res;
  ASSERT (SELECT used_count FROM public.coupons WHERE id=cpA)=1, '415: count after first redeem';
  v_res := public.redeem_coupon('M415LIM2', c1);
  ASSERT v_res->>'reason'='already_redeemed', '415: duplicate not calm: %', v_res;
  ASSERT (SELECT used_count FROM public.coupons WHERE id=cpA)=1, '415: duplicate changed count';
  -- cross-account and anon redemption rejected
  v_res := public.redeem_coupon('M415LIM2', c2);
  ASSERT v_res->>'reason'='forbidden', '415: cross-account redeem allowed: %', v_res;
  PERFORM set_config('role','anon',true);
  PERFORM set_config('request.jwt.claim.sub','',true);
  v_err:=NULL; BEGIN PERFORM public.redeem_coupon('M415LIM2', c1);
  EXCEPTION WHEN OTHERS THEN v_err:=SQLERRM; END;
  ASSERT v_err IS NOT NULL, '415: anon executed redeem_coupon';
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', c2::text, true);
  v_res := public.redeem_coupon('M415LIM2', c2);
  ASSERT (v_res->>'success')::boolean, '415: second user redeem failed: %', v_res;
  PERFORM set_config('request.jwt.claim.sub', c3::text, true);
  v_res := public.redeem_coupon('M415LIM2', c3);
  ASSERT v_res->>'reason'='usage_limit_reached', '415: cap overshoot: %', v_res;
  ASSERT (SELECT used_count FROM public.coupons WHERE id=cpA)=2, '415: cap exceeded';
  v_res := public.redeem_coupon('NOPE415', c3);
  ASSERT v_res->>'reason'='coupon_not_found', '415: unknown coupon: %', v_res;

  -- ── increment_coupon_usage: cap + not found (service path) ───────────────
  PERFORM set_config('role','none',true);
  v_res := public.increment_coupon_usage('M415LIM2');
  ASSERT v_res->>'reason'='usage_limit_reached', '415: increment past cap: %', v_res;
  v_res := public.increment_coupon_usage('NOPE415');
  ASSERT v_res->>'reason'='coupon_not_found', '415: increment unknown: %', v_res;
  PERFORM set_config('role','authenticated',true);

  -- ── payment rails ─────────────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claim.sub', c1::text, true);
  v_res := public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, 'cash', NULL, NULL, 'm415-cash');
  ASSERT (v_res->>'ok')::boolean, '415: cash order failed: %', v_res;
  v_res := public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, 'instapay', NULL, NULL, 'm415-instapay');
  ASSERT (v_res->>'ok')::boolean, '415: instapay order failed: %', v_res;
  v_res := public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, 'vodafone_cash', NULL, NULL, 'm415-vf');
  ASSERT (v_res->>'ok')::boolean, '415: vodafone_cash order failed: %', v_res;
  v_err:=NULL; BEGIN PERFORM public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, 'wallet', NULL, NULL, 'm415-wallet');
  EXCEPTION WHEN OTHERS THEN v_err:=SQLERRM; END;
  ASSERT v_err LIKE 'WALLET_PAYMENT_NOT_AVAILABLE%', '415: wallet not rejected: %', v_err;
  v_err:=NULL; BEGIN PERFORM public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, 'card', NULL, NULL, 'm415-card');
  EXCEPTION WHEN OTHERS THEN v_err:=SQLERRM; END;
  ASSERT v_err LIKE 'CARD_PAYMENT_NOT_AVAILABLE%', '415: card not rejected: %', v_err;
  v_err:=NULL; BEGIN PERFORM public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, NULL, NULL, NULL, 'm415-null');
  EXCEPTION WHEN OTHERS THEN v_err:=SQLERRM; END;
  ASSERT v_err LIKE 'INVALID_PAYMENT_METHOD%', '415: NULL payment not rejected: %', v_err;
  v_err:=NULL; BEGIN PERFORM public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, 'fawry', NULL, NULL, 'm415-fawry');
  EXCEPTION WHEN OTHERS THEN v_err:=SQLERRM; END;
  ASSERT v_err LIKE 'INVALID_PAYMENT_METHOD%', '415: fawry not rejected: %', v_err;

  -- ── coupon at checkout: min order + rollback of side effects ─────────────
  v_err:=NULL; BEGIN PERFORM public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, 'cash', 'M415MIN500', NULL, 'm415-min');
  EXCEPTION WHEN OTHERS THEN v_err:=SQLERRM; END;
  ASSERT v_err LIKE 'COUPON_MIN_ORDER_NOT_MET%', '415: min-order coupon accepted: %', v_err;
  ASSERT NOT EXISTS (SELECT 1 FROM public.orders WHERE idempotency_key='m415-min'), '415: failed coupon order left a row';
  -- already-redeemed coupon at checkout
  v_err:=NULL; BEGIN PERFORM public.create_order(mer, jsonb_build_array(jsonb_build_object('product_id',pr1,'quantity',1)),
    'addr', 30.0, 31.0, 'cash', 'M415LIM2', NULL, 'm415-dup');
  EXCEPTION WHEN OTHERS THEN v_err:=SQLERRM; END;
  ASSERT v_err LIKE 'COUPON_ALREADY_REDEEMED%', '415: redeemed coupon accepted: %', v_err;
  ASSERT (SELECT used_count FROM public.coupons WHERE id=cpA)=2, '415: failed checkout changed coupon count';
END $$;
SELECT '415 assertions passed; fixtures rolled back' AS result;
ROLLBACK;
