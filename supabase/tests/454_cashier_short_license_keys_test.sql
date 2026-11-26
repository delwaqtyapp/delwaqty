-- 454: short numeric cashier license keys. Wrapped, rolled back.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid(); m uuid := gen_random_uuid();
  other uuid := gen_random_uuid(); prober uuid := gen_random_uuid();
  v_r jsonb; v_err text; v_key text; v_code text; v_i int;
  v_legacy text := 'DLWQ1.' || repeat('A', 60) || '.' || repeat('b', 64);
  v_legacy_code text := '999900001111';
  v_lid uuid;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u::text||'@x.i'),(other,other::text||'@x.i'),(prober,prober::text||'@x.i');
  INSERT INTO public.users(id,email,role) VALUES (u,u::text||'@x.i','merchant'),(other,other::text||'@x.i','merchant'),(prober,prober::text||'@x.i','customer')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.merchants(id,owner_user_id,name,type) VALUES (m,u,'454 shop','grocery');

  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u)::text, true);

  -- A. issue: 12 digit grouped key, stored canonical, trial only for owners
  v_r := public.cashier_license_issue(m, 'trial');
  v_key := v_r->>'license_key'; v_code := v_r->>'short_code';
  ASSERT v_key ~ '^[0-9]{4}-[0-9]{4}-[0-9]{4}$', '454 A1: key shape ' || v_key;
  ASSERT v_code ~ '^[0-9]{12}$' AND replace(v_key,'-','') = v_code, '454 A2: code/key mismatch';
  ASSERT (v_r->>'ok')::boolean AND v_r->>'plan' = 'trial', '454 A3: ' || v_r::text;
  BEGIN PERFORM public.cashier_license_issue(m, 'trial'); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err = 'TRIAL_ALREADY_USED', '454 A4: second trial: ' || v_err;
  BEGIN PERFORM public.cashier_license_issue(m, 'core_annual'); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err = 'PAID_PLANS_REQUIRE_ADMIN', '454 A5: paid plan: ' || v_err;

  -- B. lookup normalization: dashed, spaced, Arabic-Indic, Persian digits
  v_r := public.cashier_license_validate(v_key, 'dev-1');
  ASSERT (v_r->>'ok')::boolean, '454 B1: dashed: ' || v_r::text;
  v_r := public.cashier_license_validate('  ' || substr(v_code,1,4) || ' ' || substr(v_code,5,4) || '  ' || substr(v_code,9,4), 'dev-1');
  ASSERT (v_r->>'ok')::boolean, '454 B2: spaced: ' || v_r::text;
  v_r := public.cashier_license_validate(
    translate(v_key, '0123456789', U&'\0660\0661\0662\0663\0664\0665\0666\0667\0668\0669'), 'dev-1');
  ASSERT (v_r->>'ok')::boolean, '454 B3: arabic-indic: ' || v_r::text;
  v_r := public.cashier_license_validate(
    translate(v_code, '0123456789', U&'\06F0\06F1\06F2\06F3\06F4\06F5\06F6\06F7\06F8\06F9'), 'dev-1');
  ASSERT (v_r->>'ok')::boolean, '454 B4: persian: ' || v_r::text;
  v_r := public.cashier_license_validate(v_key, 'dev-2');
  ASSERT v_r->>'reason' = 'BOUND_TO_OTHER_DEVICE', '454 B5: ' || v_r::text;

  -- C. device_link works with the short key
  v_r := public.cashier_device_link(v_key, 'dev-1');
  ASSERT (v_r->>'ok')::boolean AND v_r->'merchant'->>'name' = '454 shop', '454 C1: ' || v_r::text;

  -- D. legacy long key still validates (and so does its short code)
  PERFORM set_config('role','none',true);
  INSERT INTO public.cashier_licenses(merchant_id,license_key,short_code,plan,status,pro)
    VALUES (m, v_legacy, v_legacy_code, 'core_monthly', 'issued', false) RETURNING id INTO v_lid;
  PERFORM set_config('role','authenticated',true);
  v_r := public.cashier_license_validate(v_legacy, 'dev-L');
  ASSERT (v_r->>'ok')::boolean AND v_r->>'plan' = 'core_monthly', '454 D1: legacy: ' || v_r::text;
  v_r := public.cashier_license_validate(v_legacy_code, 'dev-L');
  ASSERT (v_r->>'ok')::boolean, '454 D2: legacy via short code: ' || v_r::text;
  -- a 12 digit run inside a legacy-looking string is NOT treated as a short code
  v_r := public.cashier_license_validate('DLWQ1.x' || v_legacy_code || 'y.z', 'dev-L');
  ASSERT v_r->>'reason' = 'UNKNOWN_KEY', '454 D3: embedded digits matched: ' || v_r::text;
  PERFORM set_config('role','none',true);
  DELETE FROM public._cashier_key_failures;
  PERFORM set_config('role','authenticated',true);

  -- E. another merchant owner cannot use the key
  PERFORM set_config('request.jwt.claims', json_build_object('sub', other)::text, true);
  v_r := public.cashier_license_validate(v_key, 'dev-9');
  ASSERT v_r->>'reason' = 'NOT_AUTHORIZED', '454 E1: ' || v_r::text;
  PERFORM set_config('role','none',true);
  ASSERT (SELECT count(*) FROM public._cashier_key_failures WHERE user_id = other) = 1, '454 E2: failure not logged';
  PERFORM set_config('role','authenticated',true);

  -- F. throttle: 10 failures per user per hour, then even a right key is refused
  PERFORM set_config('request.jwt.claims', json_build_object('sub', prober)::text, true);
  FOR v_i IN 1..10 LOOP
    v_r := public.cashier_license_validate('00000000' || lpad(v_i::text, 4, '0'), 'dev-p');
    ASSERT v_r->>'reason' = 'UNKNOWN_KEY', '454 F1: attempt ' || v_i || ' ' || v_r::text;
  END LOOP;
  v_r := public.cashier_license_validate('000000000099', 'dev-p');
  ASSERT v_r->>'reason' = 'TOO_MANY_ATTEMPTS', '454 F2: not throttled: ' || v_r::text;
  v_r := public.cashier_license_validate(v_key, 'dev-p');
  ASSERT v_r->>'reason' = 'TOO_MANY_ATTEMPTS', '454 F3: correct key not refused while throttled: ' || v_r::text;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  v_r := public.cashier_license_validate(v_key, 'dev-1');
  ASSERT (v_r->>'ok')::boolean, '454 F4: throttle leaked to another user: ' || v_r::text;
  -- failures older than an hour stop counting
  PERFORM set_config('role','none',true);
  UPDATE public._cashier_key_failures SET at = now() - interval '2 hours' WHERE user_id = prober;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', prober)::text, true);
  v_r := public.cashier_license_validate('000000000099', 'dev-p');
  ASSERT v_r->>'reason' = 'UNKNOWN_KEY', '454 F5: old failures still counted: ' || v_r::text;

  -- G. ACL: helpers and the failure log are not reachable by clients
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  BEGIN PERFORM public._cashier_key_fail(u); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '454 G1: key_fail callable: ' || v_err;
  BEGIN PERFORM public._cashier_key_throttled(u); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '454 G2: throttled callable: ' || v_err;
  BEGIN PERFORM public._cashier_normalize_key('1'); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '454 G3: normalize callable: ' || v_err;
  BEGIN PERFORM count(*) FROM public._cashier_key_failures; v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '454 G4: failure log readable: ' || v_err;
  PERFORM set_config('role','anon',true);
  PERFORM set_config('request.jwt.claims', '{}', true);
  BEGIN PERFORM public.cashier_license_validate(v_key, 'x'); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '454 G5: anon can execute validate: ' || v_err;
  BEGIN PERFORM public.cashier_device_link(v_key, 'x'); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '454 G6: anon can execute device_link: ' || v_err;
  BEGIN PERFORM public.cashier_license_issue(m, 'trial'); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%permission denied%', '454 G7: anon can execute issue: ' || v_err;
  PERFORM set_config('role','none',true);

  -- H. schema: format check + unique + NOT NULL
  BEGIN INSERT INTO public.cashier_licenses(merchant_id,license_key,short_code,plan) VALUES (m,'k1','12345','core_monthly'); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%short_code_format%', '454 H1: ' || v_err;
  BEGIN INSERT INTO public.cashier_licenses(merchant_id,license_key,short_code,plan) VALUES (m,'k2',v_legacy_code,'core_monthly'); v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  ASSERT v_err ILIKE '%short_code_key%', '454 H2: ' || v_err;
  -- an insert that omits the short code gets one (existing writers keep working)
  INSERT INTO public.cashier_licenses(merchant_id,license_key,plan) VALUES (m,'k3','core_monthly') RETURNING short_code INTO v_code;
  ASSERT v_code ~ '^[0-9]{12}$', '454 H3: no auto short code: ' || coalesce(v_code, 'NULL');
END $$;
SELECT '454 cashier short license keys passed' AS result;
ROLLBACK;
