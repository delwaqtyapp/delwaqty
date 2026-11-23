-- 431 pharmacy retirement verification (transaction-wrapped, rolled back).
-- Runs against the database with 431 applied: every pharmacy row is dark
-- to clients but not yet deleted; driver capability refuses pharmacy;
-- owner workspace has no pharmacy business.
BEGIN;

-- Merchants: pharmacy rows suspended and closed, not deleted
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.merchants WHERE type = 'pharmacy' AND (status <> 'suspended' OR is_open)),
    '431: pharmacy merchant not suspended/closed';
END $$;

-- Categories / catalog categories / offers / pricing: inactive
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.categories WHERE is_active AND (lower(coalesce(name,'')) LIKE '%pharm%' OR lower(coalesce(name_en,'')) LIKE '%pharm%' OR coalesce(name_ar,'') LIKE '%صيدل%')),
    '431: active pharmacy category remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.catalog_categories WHERE is_active AND merchant_type = 'pharmacy'),
    '431: active pharmacy catalog category remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.offers o JOIN public.merchants m ON m.id = o.merchant_id WHERE m.type = 'pharmacy' AND o.is_active),
    '431: active pharmacy offer remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.delivery_pricing WHERE service_type = 'pharmacy_delivery' AND is_active),
    '431: pharmacy_delivery pricing still active';
END $$;

-- Offers fixtures: merchant path AND catalog_categories path (#172)
DO $$
DECLARE
  v_m uuid := gen_random_uuid();
  v_cc uuid := gen_random_uuid();
  v_o1 uuid := gen_random_uuid();
  v_o2 uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.merchants (id, name, type, status, is_open)
  VALUES (v_m, '431 fixture pharmacy', 'pharmacy', 'suspended', false);
  INSERT INTO public.catalog_categories (id, name, merchant_type, is_active)
  VALUES (v_cc, '431 fixture cat', 'pharmacy', true);
  INSERT INTO public.offers (id, merchant_id, title, discount_value, is_active)
  VALUES (v_o1, v_m, '431 fixture offer-m', 10, true);
  INSERT INTO public.offers (id, merchant_id, title, discount_value, category_id, is_active)
  VALUES (v_o2, NULL, '431 fixture offer-c', 10, v_cc, true);

  -- re-run the 431 deactivation predicates against the fixtures
  UPDATE public.offers SET is_active = false
   WHERE is_active
     AND (merchant_id IN (SELECT id FROM public.merchants WHERE type = 'pharmacy')
       OR category_id IN (SELECT id FROM public.catalog_categories WHERE merchant_type = 'pharmacy'));
  UPDATE public.catalog_categories SET is_active = false WHERE is_active AND merchant_type = 'pharmacy';

  ASSERT NOT EXISTS (SELECT 1 FROM public.offers WHERE id IN (v_o1, v_o2) AND is_active),
    '431: offers deactivation missed merchant or category path';
  ASSERT NOT EXISTS (SELECT 1 FROM public.catalog_categories WHERE id = v_cc AND is_active),
    '431: catalog category deactivation missed';
END $$;

-- Rides: nothing searching, nothing offered
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.rides WHERE service_type = 'pharmacy_delivery' AND status = 'searching'),
    '431: pharmacy_delivery ride still searching';
  ASSERT NOT EXISTS (SELECT 1 FROM public.ride_requests rq JOIN public.rides r ON r.id = rq.ride_id WHERE r.service_type = 'pharmacy_delivery' AND rq.status = 'offered'),
    '431: open pharmacy_delivery ride offer remains';
END $$;

-- Workspaces: no pharmacy profile, no pharmacy active selection (owner
-- and non-owner paths both flow through provider_business_profiles /
-- users.active_provider_category, and an orphan SET NULL merchant FK can
-- no longer resurrect a workspace because the profile row itself is gone)
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.provider_business_profiles WHERE category_type = 'pharmacy'),
    '431: pharmacy provider_business_profile remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.users WHERE active_provider_category = 'pharmacy'),
    '431: users.active_provider_category still pharmacy';
END $$;

-- Drivers: retired element stripped; pharmacy-only drivers are
-- ride-hail-only (empty array + accepts_deliveries=false), never
-- broadened to the full delivery set
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.drivers WHERE service_types @> ARRAY['pharmacy']::text[]),
    '431: pharmacy driver capability remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.drivers WHERE accepts_deliveries AND cardinality(service_types) = 0),
    '431: driver with empty capabilities still accepts deliveries';
END $$;

-- Call-as-user RPC check (post-431, code/security #163): a non-owner
-- whose only merchant is a retired pharmacy must NOT get an approved
-- pharmacy workspace back from get_my_provider_profiles().
-- (SET ROLE is not allowed inside a DO block, so the call happens at
-- top level inside the test transaction.)
INSERT INTO auth.users (id, email)
VALUES ('43100000-0000-4000-8000-0000000000a1', 'zz431-rpc-fixture@example.invalid');
-- the auth.users trigger already created public.users; update it
INSERT INTO public.users (id, email, role, user_type, verification_status)
VALUES ('43100000-0000-4000-8000-0000000000a1', 'zz431-rpc-fixture@example.invalid', 'merchant', 'merchant', 'approved')
ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role, user_type = EXCLUDED.user_type, verification_status = EXCLUDED.verification_status;
INSERT INTO public.merchants (id, owner_user_id, name, type, status, is_open)
VALUES ('43100000-0000-4000-8000-0000000000a2', '43100000-0000-4000-8000-0000000000a1', '431 RPC fixture', 'pharmacy', 'suspended', false);

CREATE TEMP TABLE _431_rpc (r jsonb);
GRANT INSERT ON _431_rpc TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '43100000-0000-4000-8000-0000000000a1', true);
INSERT INTO _431_rpc SELECT public.get_my_provider_profiles();
RESET ROLE;

DO $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT r INTO v_result FROM _431_rpc;
  ASSERT v_result IS NULL
     OR NOT (v_result->'profiles' @> jsonb_build_array(jsonb_build_object('category_type', 'pharmacy'))),
    '431: get_my_provider_profiles resurrected an approved pharmacy workspace: ' || coalesce(v_result::text, 'NULL');
END $$;
DROP TABLE _431_rpc;

-- Owner workspace provisioning: pharmacy category no longer provisioned
DO $$
DECLARE
  v_body text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_body
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'get_my_provider_profiles';
  -- the owner provisioning array must not contain pharmacy, and the
  -- non-owner loop / aggregation must carry the pharmacy denial
  ASSERT v_body LIKE '%type <> ''pharmacy''%', '431: non-owner loop missing pharmacy filter';
  ASSERT v_body LIKE '%category_type <> ''pharmacy''%', '431: aggregation missing pharmacy filter';
END $$;

-- Owner provisioning array: pharmacy excluded (body-hash form, no
-- substring/position asserts). The migrated body must hash to the known
-- 431 post-image; the runtime outcome is covered by the call-as-user
-- step above.
DO $$
DECLARE
  v_md5 text;
BEGIN
  SELECT md5(p.prosrc) INTO v_md5
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'get_my_provider_profiles';
  ASSERT v_md5 = '0f5a1c5eb6f13677ed7c9f77cf6c95eb',
    '431: get_my_provider_profiles body drifted from the reviewed post-image: ' || coalesce(v_md5, 'NULL');
END $$;

-- Denial boundaries under real roles: request/switch refuse pharmacy
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '43100000-0000-4000-8000-0000000000a1', true);
DO $$
DECLARE
  v_ok boolean;
BEGIN
  v_ok := false;
  BEGIN
    PERFORM public.request_additional_provider_profile('pharmacy', 'probe');
  EXCEPTION WHEN raise_exception THEN
    v_ok := (SQLERRM = 'This category is retired');
  END;
  ASSERT v_ok, '431: request_additional_provider_profile did not refuse pharmacy';

  v_ok := false;
  BEGIN
    PERFORM public.switch_active_provider_profile('pharmacy');
  EXCEPTION WHEN raise_exception THEN
    v_ok := (SQLERRM = 'This category is retired');
  END;
  ASSERT v_ok, '431: switch_active_provider_profile did not refuse pharmacy';
END $$;
RESET ROLE;

-- Denial boundaries, owner case: an owner JWT gets the same refusal
INSERT INTO auth.users (id, email)
VALUES ('43100000-0000-4000-8000-0000000000b1', 'zz431-owner-fixture@example.invalid');
INSERT INTO public.users (id, email, role, user_type, verification_status)
VALUES ('43100000-0000-4000-8000-0000000000b1', 'zz431-owner-fixture@example.invalid', 'owner', 'customer', 'approved')
ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '43100000-0000-4000-8000-0000000000b1', true);
DO $$
DECLARE
  v_ok boolean;
BEGIN
  v_ok := false;
  BEGIN
    PERFORM public.request_additional_provider_profile('pharmacy', 'probe');
  EXCEPTION WHEN raise_exception THEN
    v_ok := (SQLERRM = 'This category is retired');
  END;
  ASSERT v_ok, '431: owner request_additional_provider_profile did not refuse pharmacy';

  v_ok := false;
  BEGIN
    PERFORM public.switch_active_provider_profile('pharmacy');
  EXCEPTION WHEN raise_exception THEN
    v_ok := (SQLERRM = 'This category is retired');
  END;
  ASSERT v_ok, '431: owner switch_active_provider_profile did not refuse pharmacy';
END $$;
RESET ROLE;

-- Rerun/drift harness: the A0 classifier must accept the post-image
-- (second run) for every replaced function
DO $$
DECLARE
  r record;
  v_md5 text;
  v_bad text;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('get_my_provider_profiles', '0f5a1c5eb6f13677ed7c9f77cf6c95eb'),
      ('complete_driver_onboarding', '7c8dd90a0aa2ed8396e8100d8b499888'),
      ('update_driver_capabilities', '0227ce83f9b08dc744d2e75f50de8566'),
      ('driver_capability_bounds_guard', 'b0592984b89143247f787ba91c4051c0'),
      ('search_intent_category', '05e8d790f1466cb6b8ae9a7f6c3e47f6'),
      ('request_additional_provider_profile', '9a872ff9f1a33289602890135479614e'),
      ('switch_active_provider_profile', 'db574dfddd424c2ec132099e82f67e4c')
    ) AS t(fn, md5_post)
  LOOP
    SELECT md5(p.prosrc) INTO v_md5
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = r.fn;
    IF v_md5 IS DISTINCT FROM r.md5_post THEN
      v_bad := coalesce(v_bad || ', ', '') || r.fn;
    END IF;
  END LOOP;
  ASSERT v_bad IS NULL, '431: post-image md5 mismatch (second run would abort): ' || v_bad;
END $$;

-- Capability guard: pharmacy no longer an accepted service type
DO $$
DECLARE
  v_body text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_body
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'driver_capability_bounds_guard';
  ASSERT v_body NOT LIKE '%pharmacy%',
    '431: driver_capability_bounds_guard still accepts pharmacy';
END $$;

-- RPC refusal: no client-facing EXECUTE left on the 9 pharmacy RPCs
DO $$
BEGIN
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
         aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a_pub
     WHERE n.nspname = 'public'
       AND p.proname IN ('pharmacy_import_drug','pharmacy_directory','pharmacy_link_create',
                         'pharmacy_transfer_request','pharmacy_transfer_respond','pharmacy_transfer_handover',
                         'pharmacy_transfer_settle','pharmacy_transfer_settle_confirm','pharmacy_message_send')
       AND a_pub.privilege_type = 'EXECUTE'
       AND (a_pub.grantee IN ('authenticated'::regrole, 'anon'::regrole)
         OR a_pub.grantee = 0)),
    '431: pharmacy RPC still executable by a client role';
END $$;

-- Durability: re-running the retirement UPDATEs is a no-op
DO $$
DECLARE
  v_before int;
  v_after int;
BEGIN
  SELECT count(*) INTO v_before FROM public.merchants WHERE type = 'pharmacy' AND status = 'suspended' AND NOT is_open;
  UPDATE public.merchants SET status = 'suspended', is_open = false, updated_at = now()
   WHERE type = 'pharmacy' AND (status <> 'suspended' OR is_open);
  SELECT count(*) INTO v_after FROM public.merchants WHERE type = 'pharmacy' AND status = 'suspended' AND NOT is_open;
  ASSERT v_before = v_after, '431: retirement re-run changed state (not idempotent)';
END $$;

ROLLBACK;
