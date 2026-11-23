-- Staging rollback-only. Requires 407 and 409. Synthetic fixtures, no messages.
BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
('fb070000-0000-4000-8000-000000000001','zz407-owner@example.invalid','{"user_type":"customer"}'),
('fb070000-0000-4000-8000-000000000002','zz407-customer@example.invalid','{"user_type":"customer"}'),
('fb070000-0000-4000-8000-000000000003','zz407-provider@example.invalid','{"user_type":"provider"}');
UPDATE public.users SET role='owner',user_type='owner',verification_status='approved'
WHERE id='fb070000-0000-4000-8000-000000000001';
INSERT INTO public.provider_business_profiles(id,user_id,category_type,display_name,status)
VALUES ('fb070000-0000-4000-8000-000000000004','fb070000-0000-4000-8000-000000000003','plumbing','zz407-approved-provider','pending');

DO $test$
BEGIN
  ASSERT NOT EXISTS(SELECT 1 FROM public.service_providers WHERE user_id='fb070000-0000-4000-8000-000000000003'), 'signup must await category approval';
  ASSERT NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='service_providers' AND policyname='service_providers_manage_own'), 'FOR ALL self policy removed';
  ASSERT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='service_providers' AND policyname='providers can update own' AND cmd='UPDATE'), 'self UPDATE retained';
END;
$test$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','fb070000-0000-4000-8000-000000000002',true);
DO $test$
BEGIN
  ASSERT NOT has_table_privilege('authenticated','public.service_providers','INSERT'), 'authenticated INSERT revoked';
  ASSERT NOT has_table_privilege('anon','public.service_providers','INSERT'), 'anon INSERT revoked';
  ASSERT NOT has_function_privilege('authenticated','public._provision_business_target(uuid,text,text)','EXECUTE'), 'provision helper private';
  BEGIN
    INSERT INTO public.service_providers(user_id,name,category_type,is_verified,is_available,rating,rating_count,hourly_rate,fixed_price_min,fixed_price_max)
    VALUES(auth.uid(),'zz407-forged','plumbing',true,true,5,999,1,1,1);
    RAISE EXCEPTION 'forged customer INSERT succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public._provision_business_target(auth.uid(),'plumbing','zz407-forged');
    RAISE EXCEPTION 'direct helper call succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$test$;

-- Real entry point, under an actual authenticated owner JWT, not postgres.
SELECT set_config('request.jwt.claim.sub','fb070000-0000-4000-8000-000000000001',true);
SELECT public.decide_provider_profile_request('fb070000-0000-4000-8000-000000000004','approved');
RESET ROLE;
DO $test$
BEGIN
  ASSERT EXISTS(SELECT 1 FROM public.provider_business_profiles bp JOIN public.service_providers sp ON sp.id=bp.service_provider_id
    WHERE bp.id='fb070000-0000-4000-8000-000000000004' AND bp.status='approved'
      AND sp.user_id='fb070000-0000-4000-8000-000000000003' AND sp.category_type='plumbing'
      AND sp.is_verified AND sp.is_available AND sp.hourly_rate IS NULL
      AND sp.fixed_price_min IS NULL AND sp.fixed_price_max IS NULL), 'admin approval still provisions inherited-price provider';
END;
$test$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','fb070000-0000-4000-8000-000000000003',true);
DO $test$
DECLARE n integer;
BEGIN
  ASSERT EXISTS(SELECT 1 FROM public.service_providers WHERE user_id=auth.uid()), 'self SELECT retained';
  UPDATE public.service_providers SET description='zz407-profile-edit' WHERE user_id=auth.uid();
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n=1, 'legit self profile UPDATE retained';
  DELETE FROM public.service_providers WHERE user_id=auth.uid();
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n=0, 'self DELETE must not remove provisioned row';
  BEGIN
    INSERT INTO public.service_providers(user_id,name,category_type,is_verified,is_available,rating,rating_count,hourly_rate)
    VALUES(auth.uid(),'zz407-reinsert','plumbing',true,true,5,999,1);
    RAISE EXCEPTION 'delete/reinsert bypass succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE public.service_providers SET category_type='doctor' WHERE user_id=auth.uid();
    RAISE EXCEPTION 'category identity bypass succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE public.service_providers SET hourly_rate=1 WHERE user_id=auth.uid();
    RAISE EXCEPTION 'self pricing UPDATE succeeded';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM='self pricing UPDATE succeeded' THEN RAISE; END IF;
    ASSERT SQLERRM='hourly_rate is managed by the admin RPCs', 'expected sensitive-fields pricing guard';
  END;
END;
$test$;
RESET ROLE;
DO $test$
BEGIN
  ASSERT (SELECT count(*) FROM public.service_providers WHERE user_id='fb070000-0000-4000-8000-000000000003')=1, 'original provider preserved exactly once';
  ASSERT NOT EXISTS(SELECT 1 FROM public.service_providers WHERE user_id='fb070000-0000-4000-8000-000000000002'), 'no customer provider created';
END;
$test$;
SELECT 'PASS409: client INSERT denied, helper private, real approval provisions, self read/edit retained, delete-reinsert denied, pricing guard retained' AS result;
ROLLBACK;
