-- 418 regression: products.is_featured admin-only gate (trigger + scoped RPC)
-- plus the 413 red team round 1 function/field guard assertions.
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
  v_admin_village uuid := 'c3b38bed-3010-4bd5-9fb1-0ffddfe87a81'; -- qa.admin-village-1 (region self + MERCHANT_EDIT)
  v_admin_plain   uuid := 'b02d03fb-c0d6-4b3d-9e5a-076eaebba0b5'; -- qa.admin-plain-1 (no region assignment)
  v_admin_susp    uuid := '60fac5b0-bc70-47f9-84d2-dbf302841a6d'; -- qa.admin-suspended-1 (admin_management inactive)
  v_admin_cairo   uuid := 'bceec1f3-ba83-40f3-bf2e-862540a69915'; -- qa.lab-member-outside, promoted in-tx
  v_cairo    uuid := '00000000-0000-0000-0000-000000000107';
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

  -- (2) anon caller predicate retained for RLS, supplied-id predicate revoked.
  ASSERT has_function_privilege('anon','public.is_admin()','EXECUTE'),'anon RLS caller predicate required';
  ASSERT NOT has_function_privilege('anon','public.is_admin(uuid)','EXECUTE'),'anon supplied-id predicate exposed';
  PERFORM set_config('role','anon',true);
  PERFORM set_config('request.jwt.claim.sub','',true);
  ASSERT NOT coalesce(public.is_admin(),false),'anon admin predicate must be false';
  PERFORM 1 FROM public.categories LIMIT 1;
  PERFORM 1 FROM public.products LIMIT 1;
  PERFORM 1 FROM public.service_providers LIMIT 1;
  PERFORM set_config('role','authenticated',true);
  -- ── 418 part 1: direct client feature writes denied (featured=false state) ─
  PERFORM set_config('role','none',true);
  INSERT INTO public.products(id,merchant_id,name,price,is_featured) VALUES(v_product,v_merchant,'zz418-fixture',1,false) ON CONFLICT(id) DO NOTHING;
  UPDATE public.products SET is_featured=false WHERE id=v_product;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', v_merch_u::text,true);
  v_err:=NULL;
  BEGIN UPDATE public.products SET is_featured=true WHERE id=v_product;
  EXCEPTION WHEN insufficient_privilege THEN v_err:=SQLERRM; END;
  ASSERT v_err IS NOT NULL,'418: merchant self-feature update accepted';
  v_err:=NULL;
  BEGIN INSERT INTO public.products(merchant_id,name,price,is_featured) VALUES(v_merchant,'zz418-forged',1,true);
  EXCEPTION WHEN insufficient_privilege THEN v_err:=SQLERRM; END;
  ASSERT v_err IS NOT NULL,'418: merchant self-feature insert accepted';
  -- default-false insert and a normal price edit stay allowed
  INSERT INTO public.products(merchant_id,name,price,is_featured) VALUES(v_merchant,'zz418-plain',1,false);
  UPDATE public.products SET price=2 WHERE id=v_product;
  -- customer direct write: RLS hides the row (0 rows) or the trigger rejects;
  -- either way the column must stay false
  PERFORM set_config('request.jwt.claim.sub', v_customer::text,true);
  UPDATE public.products SET is_featured=true WHERE id=v_product;
  PERFORM set_config('role','none',true);
  ASSERT NOT (SELECT is_featured FROM public.products WHERE id=v_product),'418: customer feature update landed';
  -- anon direct write: same guarantee
  PERFORM set_config('role','anon',true);
  PERFORM set_config('request.jwt.claim.sub','',true);
  UPDATE public.products SET is_featured=true WHERE id=v_product;
  PERFORM set_config('role','none',true);
  ASSERT NOT (SELECT is_featured FROM public.products WHERE id=v_product),'418: anon feature update landed';
  PERFORM set_config('role','anon',true);
  -- anon cannot execute the admin RPC at all (EXECUTE revoked)
  v_err:=NULL;
  BEGIN PERFORM public.admin_set_product_featured(v_product,true);
  EXCEPTION WHEN OTHERS THEN v_err:=SQLERRM; END;
  ASSERT v_err IS NOT NULL,'418: anon executed admin RPC';
  PERFORM set_config('role','authenticated',true);
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

  -- ── 418 part 2: scoped RPC matrix + dual-role direct write ────────────────
  -- dual-role admin+merchant fixture (in-transaction, rolls back)
  PERFORM set_config('role','none',true);
  UPDATE public.users SET role='admin' WHERE id=v_merch_u;
  INSERT INTO public.admin_management(admin_id,supervisor_id,is_active,created_by) VALUES(v_merch_u,v_owner,true,v_owner);
  INSERT INTO public.admin_region_assignments(admin_id,region_id,scope,created_by) VALUES(v_merch_u,v_region,'self',v_owner);
  INSERT INTO public.admin_permission_grants(admin_id,permission,granted_by) VALUES(v_merch_u,'MERCHANT_EDIT',v_owner);
  -- out-of-region admin fixture (Cairo governorate scope + grant)
  UPDATE public.users SET role='admin' WHERE id=v_admin_cairo;
  INSERT INTO public.admin_management(admin_id,supervisor_id,is_active,created_by) VALUES(v_admin_cairo,v_owner,true,v_owner);
  INSERT INTO public.admin_region_assignments(admin_id,region_id,scope,created_by) VALUES(v_admin_cairo,v_cairo,'descendants',v_owner);
  INSERT INTO public.admin_permission_grants(admin_id,permission,granted_by) VALUES(v_admin_cairo,'MERCHANT_EDIT',v_owner);
  PERFORM set_config('role','authenticated',true);
  -- dual-role direct client PATCH still denied: admins must use the RPC
  PERFORM set_config('request.jwt.claim.sub', v_merch_u::text,true);
  v_err:=NULL;
  BEGIN UPDATE public.products SET is_featured=true WHERE id=v_product;
  EXCEPTION WHEN insufficient_privilege THEN v_err:=SQLERRM; END;
  ASSERT v_err IS NOT NULL,'418: dual-role admin+merchant direct feature update accepted';
  -- owner RPC: success, featured true
  PERFORM set_config('request.jwt.claim.sub',v_owner::text,true);
  v_j:=public.admin_set_product_featured(v_product,true);
  ASSERT v_j->>'ok'='true','418: owner RPC denied';
  PERFORM set_config('role','none',true);
  ASSERT (SELECT is_featured FROM public.products WHERE id=v_product),'418: owner RPC did not set featured';
  PERFORM set_config('role','authenticated',true);
  -- with featured now true: merchant direct changes still denied, false insert ok
  PERFORM set_config('request.jwt.claim.sub', v_merch_u::text,true);
  v_err:=NULL;
  BEGIN UPDATE public.products SET is_featured=false WHERE id=v_product;
  EXCEPTION WHEN insufficient_privilege THEN v_err:=SQLERRM; END;
  ASSERT v_err IS NOT NULL,'418: merchant unfeature update accepted';
  INSERT INTO public.products(merchant_id,name,price,is_featured) VALUES(v_merchant,'zz418-plain2',1,false);
  -- scoped non-owner admin (village self scope + MERCHANT_EDIT): success
  PERFORM set_config('request.jwt.claim.sub', v_admin_village::text,true);
  v_j:=public.admin_set_product_featured(v_product,false);
  ASSERT v_j->>'ok'='true','418: scoped admin RPC denied: %',v_j;
  PERFORM set_config('role','none',true);
  ASSERT NOT (SELECT is_featured FROM public.products WHERE id=v_product),'418: scoped admin RPC did not unset featured';
  -- same admin with the MERCHANT_EDIT grant removed: denied
  DELETE FROM public.admin_permission_grants WHERE admin_id=v_admin_village AND permission='MERCHANT_EDIT';
  PERFORM set_config('role','authenticated',true);
  v_j:=public.admin_set_product_featured(v_product,true);
  ASSERT v_j->>'ok'='false' AND v_j->>'code'='FORBIDDEN','418: permissionless admin RPC allowed: %',v_j;
  -- unassigned admin: denied
  PERFORM set_config('request.jwt.claim.sub', v_admin_plain::text,true);
  v_j:=public.admin_set_product_featured(v_product,true);
  ASSERT v_j->>'ok'='false' AND v_j->>'code'='FORBIDDEN','418: unassigned admin RPC allowed: %',v_j;
  -- suspended admin: denied
  PERFORM set_config('request.jwt.claim.sub', v_admin_susp::text,true);
  v_j:=public.admin_set_product_featured(v_product,true);
  ASSERT v_j->>'ok'='false' AND v_j->>'code'='FORBIDDEN','418: suspended admin RPC allowed: %',v_j;
  -- out-of-region admin (Cairo scope + grant): denied
  PERFORM set_config('request.jwt.claim.sub', v_admin_cairo::text,true);
  v_j:=public.admin_set_product_featured(v_product,true);
  ASSERT v_j->>'ok'='false' AND v_j->>'code'='FORBIDDEN','418: out-of-region admin RPC allowed: %',v_j;
  -- null value and unknown product: rejected
  PERFORM set_config('request.jwt.claim.sub',v_owner::text,true);
  v_j:=public.admin_set_product_featured(v_product,NULL);
  ASSERT v_j->>'ok'='false' AND v_j->>'code'='INVALID_VALUE','418: NULL featured accepted: %',v_j;
  v_j:=public.admin_set_product_featured(gen_random_uuid(),true);
  ASSERT v_j->>'ok'='false' AND v_j->>'code'='NOT_FOUND','418: unknown product accepted: %',v_j;

  -- ── (7) signup-style insert unaffected (guards are UPDATE-only) ───────────
  v_new := gen_random_uuid();
  PERFORM set_config('request.jwt.claim.sub', v_new::text, true);
  INSERT INTO public.users(id, email, full_name, language, is_onboarded, role, user_type,
                           verification_status, is_biometric_enabled, account_status, status,
                           chat_calls_enabled, refusal_count)
  VALUES (v_new, 'm413-probe@example.invalid', 'm413 probe', 'ar', false,
          'customer', 'customer', 'approved', false, 'active', 'active', true, 0);
END $$;
SELECT '418+413 assertions passed; fixtures rolled back' AS result;
ROLLBACK;
