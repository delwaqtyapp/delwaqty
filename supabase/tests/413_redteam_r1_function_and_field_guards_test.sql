-- 413 regression: red team round 1 function authorization + sensitive-field guards.
-- Actual-role fixtures: the staging QA accounts (qa.* / pilot.* villages).
-- Transactional: every write rolls back; no staging state is mutated.
--
-- Roles exercised (real staging rows):
--   owner    qa.lab-owner-1          04f4163a-d06f-4e93-98ec-9f0b980d0492
--   admin    qa.admin-plain-1        b02d03fb-c0d6-4b3d-9e5a-076eaebba0b5
--   customer qa.customer-001         5c242e8a-8bdf-444e-a7d4-fa72f3ad6f2a
--   driver   qa.driver-1             user dd17c3a7-36a1-4a96-8cf5-333f9055b7bc
--                                    driver row 77777777-7777-4777-8777-000000000701
--   merchant qa.merchant-grocery-1   user 39e7c174-3361-4b67-a711-0a9011e44bb7
--                                    merchant 22222222-2222-4222-8222-000000000202
--                                    product  66666666-6666-4666-8666-000000020201
BEGIN;
DO $$
DECLARE
  v_owner    uuid := '04f4163a-d06f-4e93-98ec-9f0b980d0492';
  v_admin    uuid := 'b02d03fb-c0d6-4b3d-9e5a-076eaebba0b5';
  v_customer uuid := '5c242e8a-8bdf-444e-a7d4-fa72f3ad6f2a';
  v_driver_u uuid := 'dd17c3a7-36a1-4a96-8cf5-333f9055b7bc';
  v_driver   uuid := '77777777-7777-4777-8777-000000000701';
  v_merch_u  uuid := '39e7c174-3361-4b67-a711-0a9011e44bb7';
  v_merchant uuid := '22222222-2222-4222-8222-000000000202';
  v_product  uuid := '66666666-6666-4666-8666-000000020201';
  v_region   uuid := '905b0ccc-f2ed-5306-b661-233b49edd400'; -- from user_region_preferences
  v_err  text;
  v_j    jsonb;
  v_new  uuid;
BEGIN
  -- ── (1) admin_effective_permissions authorization ─────────────────────────
  -- customer reading another admin's permissions: blocked
  PERFORM set_config('request.jwt.claim.sub', v_customer::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_err := NULL;
  BEGIN PERFORM public.admin_effective_permissions(v_admin);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL THEN RAISE EXCEPTION 'm413 t1: customer read admin effective permissions'; END IF;
  IF v_err NOT LIKE '%restricted to the subject%' THEN RAISE EXCEPTION 'm413 t1: wrong error: %', v_err; END IF;

  -- admin reading own permissions: allowed
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  v_j := public.admin_effective_permissions(v_admin);
  IF v_j IS NULL OR NOT (v_j ? 'role') THEN RAISE EXCEPTION 'm413 t1: admin self-read broken: %', v_j; END IF;

  -- owner reading an admin's permissions: allowed (is_admin path)
  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  v_j := public.admin_effective_permissions(v_admin);
  IF v_j IS NULL OR NOT (v_j ? 'granted') THEN RAISE EXCEPTION 'm413 t1: owner read broken: %', v_j; END IF;

  -- anon: blocked
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('role', 'anon', true);
  v_err := NULL;
  BEGIN PERFORM public.admin_effective_permissions(v_admin);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL THEN RAISE EXCEPTION 'm413 t1: anon read admin effective permissions'; END IF;

  -- ── (2) anon EXECUTE revoked on is_admin overloads ────────────────────────
  IF has_function_privilege('anon', 'public.is_admin()', 'EXECUTE') THEN
    RAISE EXCEPTION 'm413 t2: anon still has EXECUTE on is_admin()';
  END IF;
  IF has_function_privilege('anon', 'public.is_admin(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'm413 t2: anon still has EXECUTE on is_admin(uuid)';
  END IF;
  v_err := NULL;
  BEGIN PERFORM public.is_admin();
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL THEN RAISE EXCEPTION 'm413 t2: anon called is_admin()'; END IF;

  -- ── (3) merchants.settlement_model guard ──────────────────────────────────
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_merch_u::text, true);
  -- benign merchant self-edit still works
  UPDATE public.merchants SET description = 'm413 probe' WHERE id = v_merchant;
  -- direct settlement_model write: blocked
  v_err := NULL;
  BEGIN UPDATE public.merchants SET settlement_model = 'direct' WHERE id = v_merchant;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL THEN RAISE EXCEPTION 'm413 t3: merchant set own settlement_model directly'; END IF;
  IF v_err NOT LIKE '%settlement_model%' THEN RAISE EXCEPTION 'm413 t3: wrong error: %', v_err; END IF;
  -- merchant self-service RPC (SECURITY DEFINER) still works
  v_j := public.merchant_set_settlement_model('platform');
  IF (v_j->>'ok') <> 'true' THEN RAISE EXCEPTION 'm413 t3: merchant_set_settlement_model RPC broke: %', v_j; END IF;
  -- admin direct write: allowed via is_admin() exemption (admin app flow)
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  UPDATE public.merchants SET settlement_model = 'direct' WHERE id = v_merchant;

  -- ── (4) users account-field guards ────────────────────────────────────────
  PERFORM set_config('request.jwt.claim.sub', v_customer::text, true);
  -- benign profile edit still works
  UPDATE public.users SET full_name = 'm413 probe' WHERE id = v_customer;
  -- each newly guarded column: blocked for direct client writes
  v_err := NULL;
  BEGIN UPDATE public.users SET status = 'suspended' WHERE id = v_customer;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%Status flag%' THEN RAISE EXCEPTION 'm413 t4: status not guarded (%)', v_err; END IF;
  v_err := NULL;
  BEGIN UPDATE public.users SET role_key = 'regional_admin' WHERE id = v_customer;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%Role key%' THEN RAISE EXCEPTION 'm413 t4: role_key not guarded (%)', v_err; END IF;
  v_err := NULL;
  BEGIN UPDATE public.users SET region_id = v_region WHERE id = v_customer;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%Region assignment%' THEN RAISE EXCEPTION 'm413 t4: region_id not guarded (%)', v_err; END IF;
  v_err := NULL;
  BEGIN UPDATE public.users SET email = 'm413@probe.invalid' WHERE id = v_customer;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%Email%' THEN RAISE EXCEPTION 'm413 t4: email not guarded (%)', v_err; END IF;
  v_err := NULL;
  BEGIN UPDATE public.users SET refusal_count = 99 WHERE id = v_customer;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%Refusal count%' THEN RAISE EXCEPTION 'm413 t4: refusal_count not guarded (%)', v_err; END IF;
  v_err := NULL;
  BEGIN UPDATE public.users SET rejection_reason = 'x' WHERE id = v_customer;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%Rejection reason%' THEN RAISE EXCEPTION 'm413 t4: rejection_reason not guarded (%)', v_err; END IF;
  -- customer region preference flow (user_region_preferences) unaffected
  INSERT INTO public.user_region_preferences(user_id, region_id, source)
  VALUES (v_customer, v_region, 'manual')
  ON CONFLICT (user_id) DO UPDATE SET region_id = EXCLUDED.region_id, source = EXCLUDED.source;
  -- direct region_id write stays blocked even for owner (RPC-only field)
  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  v_err := NULL;
  BEGIN UPDATE public.users SET region_id = v_region WHERE id = v_customer;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL THEN RAISE EXCEPTION 'm413 t4: owner direct users.region_id write allowed'; END IF;
  -- SECURITY DEFINER admin RPC path still writes guarded users columns
  PERFORM public.admin_apply_role_template(v_admin, 'regional_admin', 'm413 probe');

  -- ── (5) drivers onboarding/activation guards ──────────────────────────────
  PERFORM set_config('request.jwt.claim.sub', v_driver_u::text, true);
  -- benign driver self-edit still works
  UPDATE public.drivers SET vehicle_color = 'm413-probe' WHERE id = v_driver;
  v_err := NULL;
  BEGIN UPDATE public.drivers SET onboarding_step = 3 WHERE id = v_driver;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%onboarding_step%' THEN RAISE EXCEPTION 'm413 t5: onboarding_step not guarded (%)', v_err; END IF;
  v_err := NULL;
  BEGIN UPDATE public.drivers SET onboarding_completed = true WHERE id = v_driver;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%onboarding_completed%' THEN RAISE EXCEPTION 'm413 t5: onboarding_completed not guarded (%)', v_err; END IF;
  v_err := NULL;
  BEGIN UPDATE public.drivers SET is_active = false WHERE id = v_driver;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err IS NULL OR v_err NOT LIKE '%is_active%' THEN RAISE EXCEPTION 'm413 t5: drivers.is_active not guarded (%)', v_err; END IF;
  -- captain onboarding RPC (SECURITY DEFINER) still writes onboarding_step
  v_j := public.submit_driver_onboarding(v_driver, p_onboarding_step => 2);
  IF (v_j->>'success') <> 'true' THEN RAISE EXCEPTION 'm413 t5: submit_driver_onboarding broke: %', v_j; END IF;
  -- captain online toggle (SECURITY INVOKER, unguarded columns) still works
  v_j := public.driver_set_online(v_driver, true);
  IF (v_j->>'success') <> 'true' THEN RAISE EXCEPTION 'm413 t5: driver_set_online broke: %', v_j; END IF;
  -- admin app direct is_active toggle: allowed via is_admin() exemption
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  UPDATE public.drivers SET is_active = false, is_online = false, status = 'offline' WHERE id = v_driver;

  -- ── (6) products.is_featured: merchant flow intentionally preserved ───────
  PERFORM set_config('request.jwt.claim.sub', v_merch_u::text, true);
  UPDATE public.products SET is_featured = true WHERE id = v_product;

  -- ── (7) signup-style insert unaffected (guards are UPDATE-only) ───────────
  v_new := gen_random_uuid();
  PERFORM set_config('request.jwt.claim.sub', v_new::text, true);
  INSERT INTO public.users(id, email, full_name, language, is_onboarded, role, user_type,
                           verification_status, is_biometric_enabled, account_status, status,
                           chat_calls_enabled, refusal_count)
  VALUES (v_new, 'm413-probe@example.invalid', 'm413 probe', 'ar', false,
          'customer', 'customer', 'approved', false, 'active', 'active', true, 0);
END $$;
SELECT 'm413 assertions passed; fixtures rolled back' AS result;
ROLLBACK;
