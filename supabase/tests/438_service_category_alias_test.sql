-- Run after migration 438. Every fixture and resulting row is rolled back.
-- Covers the electrician/plumber alias fix: the zz-demo shape (existing
-- canonical 'electrical' provider row + approve of an 'electrician'
-- request) attaches to the existing row with no merchant insert and no
-- 23514; a fresh 'electrician'/'plumber' request provisions a canonical
-- 'electrical'/'plumbing' service_providers row; the ordinary merchant
-- path is unchanged. All nullable comparisons use IS DISTINCT FROM.
BEGIN;
DO $$
DECLARE
  u_existing uuid := gen_random_uuid();  -- provider already approved as 'electrical'
  u_fresh uuid := gen_random_uuid();     -- provider with no rows yet
  u_merch uuid := gen_random_uuid();     -- ordinary merchant category
  sp_existing uuid;
  sp_new uuid;
  sp_count int;
  r jsonb;
BEGIN
  -- Fixtures.
  INSERT INTO auth.users(id, email) VALUES
    (u_existing, u_existing::text || '@example.invalid'),
    (u_fresh, u_fresh::text || '@example.invalid'),
    (u_merch, u_merch::text || '@example.invalid');
  UPDATE public.users SET role = 'provider' WHERE id IN (u_existing, u_fresh);

  INSERT INTO public.service_providers (
    user_id, name, category_type, description, rating, rating_count,
    is_verified, is_available, hourly_rate
  ) VALUES (
    u_existing, 'Demo Electrician', 'electrical', '', 5.0, 0, true, true, NULL
  ) RETURNING id INTO sp_existing;

  -- Vocabulary: occupation spellings are home services.
  IF NOT public._is_home_service_category('electrician')
     OR NOT public._is_home_service_category('plumber')
     OR public._is_home_service_category('restaurant') THEN
    RAISE EXCEPTION '438 test: _is_home_service_category vocabulary wrong';
  END IF;

  -- 1. zz-demo shape: approve of 'electrician' for a user whose existing
  --    row is stored under the canonical 'electrical' must attach to that
  --    row, insert nothing, and never touch merchants.
  r := public._provision_business_target(u_existing, 'electrician', 'Demo Electrician');
  IF (r->>'service_provider_id')::uuid IS DISTINCT FROM sp_existing
     OR r->>'merchant_id' IS NOT NULL THEN
    RAISE EXCEPTION '438 test: existing-row attach failed: %', r;
  END IF;
  SELECT count(*) INTO sp_count FROM public.service_providers WHERE user_id = u_existing;
  IF sp_count <> 1 THEN
    RAISE EXCEPTION '438 test: duplicate service_providers row created';
  END IF;
  IF EXISTS (SELECT 1 FROM public.merchants WHERE owner_user_id = u_existing) THEN
    RAISE EXCEPTION '438 test: merchant row created for a home-service category';
  END IF;

  -- 2. Fresh 'electrician' provisions one canonical 'electrical' row.
  r := public._provision_business_target(u_fresh, 'electrician', 'Fresh Electrician');
  sp_new := (r->>'service_provider_id')::uuid;
  IF sp_new IS NULL OR r->>'merchant_id' IS NOT NULL THEN
    RAISE EXCEPTION '438 test: fresh provisioning failed: %', r;
  END IF;
  IF (SELECT category_type FROM public.service_providers WHERE id = sp_new)
     IS DISTINCT FROM 'electrical' THEN
    RAISE EXCEPTION '438 test: fresh row not canonical (got %)',
      (SELECT category_type FROM public.service_providers WHERE id = sp_new);
  END IF;

  -- 3. 'plumber' canonicalises to 'plumbing'.
  r := public._provision_business_target(u_fresh, 'plumber', 'Fresh Plumber');
  IF (SELECT category_type FROM public.service_providers
       WHERE id = (r->>'service_provider_id')::uuid) IS DISTINCT FROM 'plumbing' THEN
    RAISE EXCEPTION '438 test: plumber not canonicalised: %', r;
  END IF;

  -- 4. Ordinary merchant category unchanged.
  r := public._provision_business_target(u_merch, 'restaurant', 'Demo Restaurant');
  IF r->>'merchant_id' IS NULL OR r->>'service_provider_id' IS NOT NULL THEN
    RAISE EXCEPTION '438 test: merchant path changed: %', r;
  END IF;
  IF (SELECT type FROM public.merchants WHERE id = (r->>'merchant_id')::uuid)
     IS DISTINCT FROM 'restaurant' THEN
    RAISE EXCEPTION '438 test: merchant type changed';
  END IF;
END $$;

-- 5. Authenticated admin approval through the real RPC (code reviewer ask):
--    the zz-demo shape driven through decide_provider_profile_request, plus
--    request status, link, notification and unauthorized denial.
CREATE TEMP TABLE t438_e2e(u uuid, sp uuid, req uuid, adm uuid, intruder uuid);
DO $$
DECLARE
  u uuid := gen_random_uuid();
  sp uuid;
  req uuid;
  adm uuid := gen_random_uuid();
  intruder uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users(id, email) VALUES
    (u, u::text || '@example.invalid'),
    (adm, adm::text || '@example.invalid'),
    (intruder, intruder::text || '@example.invalid');
  UPDATE public.users SET role = 'provider' WHERE id = u;
  UPDATE public.users SET role = 'owner' WHERE id = adm;

  INSERT INTO public.service_providers (
    user_id, name, category_type, description, rating, rating_count,
    is_verified, is_available, hourly_rate
  ) VALUES (
    u, 'Demo Electrician', 'electrical', '', 5.0, 0, true, true, NULL
  ) RETURNING id INTO sp;

  INSERT INTO public.provider_business_profiles (user_id, category_type, display_name)
  VALUES (u, 'electrician', 'Demo Electrician')
  RETURNING id INTO req;

  INSERT INTO t438_e2e VALUES (u, sp, req, adm, intruder);
END $$;

-- Approve as the owner over the authenticated role. Temp tables are not
-- visible under SET ROLE, so carry the ids in transaction-local GUCs.
SELECT set_config('request.jwt.claims',
  (SELECT json_build_object('sub', adm)::text FROM t438_e2e), true);
SELECT set_config('t438.req', (SELECT req::text FROM t438_e2e), true);
SET LOCAL ROLE authenticated;
SELECT public.decide_provider_profile_request(
  current_setting('t438.req')::uuid, 'approved') AS decide_result;
RESET ROLE;

DO $$
DECLARE
  v record;
BEGIN
  SELECT * INTO v FROM t438_e2e;
  -- Request approved and linked to the EXISTING canonical row.
  IF (SELECT status FROM public.provider_business_profiles WHERE id = v.req)
     IS DISTINCT FROM 'approved'
     OR (SELECT service_provider_id FROM public.provider_business_profiles WHERE id = v.req)
        IS DISTINCT FROM v.sp THEN
    RAISE EXCEPTION '438 test: RPC approval did not attach the existing row';
  END IF;
  -- No duplicate provider, no merchant.
  IF (SELECT count(*) FROM public.service_providers WHERE user_id = v.u) <> 1
     OR EXISTS (SELECT 1 FROM public.merchants WHERE owner_user_id = v.u) THEN
    RAISE EXCEPTION '438 test: RPC approval duplicated or merchant-provisioned';
  END IF;
  -- Notification recorded.
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications
     WHERE user_id = v.u AND type = 'provider_profile'
  ) THEN
    RAISE EXCEPTION '438 test: approval notification missing';
  END IF;
END $$;

-- A non-admin authenticated caller is denied.
SELECT set_config('request.jwt.claims',
  (SELECT json_build_object('sub', intruder)::text FROM t438_e2e), true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  BEGIN
    PERFORM public.decide_provider_profile_request(
      current_setting('t438.req')::uuid, 'approved');
    RAISE EXCEPTION '438 test: unauthorized call succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT ILIKE '%Not authorized%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

ROLLBACK;
