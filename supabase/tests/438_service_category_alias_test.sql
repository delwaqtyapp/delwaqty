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
ROLLBACK;
