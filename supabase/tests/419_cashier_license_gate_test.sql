-- 419: server-side cashier license gate (review #119). Transaction-wrapped.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid(); m uuid := gen_random_uuid();
  v_r jsonb; v_err text;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u::text||'@x.i');
  INSERT INTO public.users(id,email,role) VALUES (u,u::text||'@x.i','merchant') ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.merchants(id,owner_user_id,name,type) VALUES (m,u,'419','grocery');
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', u::text, true);

  BEGIN v_r := public.cashier_sync_push(m, '[]'::jsonb); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err = 'LICENSE_REQUIRED', '419: no license not refused: ' || v_err;

  PERFORM set_config('role','none',true);
  INSERT INTO public.cashier_licenses(merchant_id, license_key, plan, status, grace_days)
  VALUES (m,'419-K1','trial','suspended',7);
  PERFORM set_config('role','authenticated',true);
  BEGIN v_r := public.cashier_sync_push(m, '[]'::jsonb); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err = 'LICENSE_SUSPENDED', '419: suspended not refused: ' || v_err;
  BEGIN v_r := public.cashier_daily_close(m, gen_random_uuid(), 0); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err = 'LICENSE_SUSPENDED', '419: daily_close not gated: ' || v_err;

  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET status='expired', expires_at=now()-interval '30 days', grace_days=7 WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  BEGIN v_r := public.cashier_sync_push(m, '[]'::jsonb); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err = 'LICENSE_EXPIRED', '419: past-grace expiry not refused: ' || v_err;

  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET expires_at=now()-interval '2 days', grace_days=7 WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, '[]'::jsonb);
  ASSERT (v_r->>'ok')::boolean, '419: in-grace license refused';

  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET status='issued', expires_at=now()+interval '30 days' WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, '[]'::jsonb);
  ASSERT (v_r->>'ok')::boolean, '419: issued license refused';

  PERFORM set_config('role','none',true);
  UPDATE public.cashier_licenses SET status='active' WHERE merchant_id=m;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, '[]'::jsonb);
  ASSERT (v_r->>'ok')::boolean, '419: active license refused';

  -- daily_close with a valid license reaches the shift check
  v_r := public.cashier_daily_close(m, gen_random_uuid(), 0);
  ASSERT v_r->>'reason' = 'SHIFT_NOT_OPEN', '419: daily_close valid-license path broke: ' || v_r::text;

  -- best license wins: an added suspended row does not block a valid active one
  PERFORM set_config('role','none',true);
  INSERT INTO public.cashier_licenses(merchant_id, license_key, plan, status, grace_days)
  VALUES (m,'419-K2','core_monthly','suspended',7);
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_sync_push(m, '[]'::jsonb);
  ASSERT (v_r->>'ok')::boolean, '419: valid license overridden by suspended sibling';

  PERFORM set_config('role','none',true);
END $$;
SELECT '419 license gate matrix passed' AS result;
ROLLBACK;
