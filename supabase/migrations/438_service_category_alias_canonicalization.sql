-- 438: approve of a home-service request whose category uses an occupation
-- spelling ('electrician', 'plumber') must land on the canonical service
-- category ('electrical', 'plumbing').
--
-- Live defect: the demo request for category_type='electrician' fails at
-- admin approve with SQLSTATE 23514 and the admin app shows its conflict
-- error. Root cause chain:
--   1. _is_home_service_category lists 'electrical' but not the occupation
--      spelling 'electrician' (399 documents this vocabulary split), so the
--      test returns false.
--   2. _provision_business_target then takes the merchant branch and INSERTs
--      merchants(type='electrician'), which violates merchants_type_check.
-- Even if the insert were allowed, the provider would end up as a merchant
-- instead of a service provider, and a second request for the canonical
-- spelling would duplicate them.
--
-- Fix:
--   * _is_home_service_category recognises the occupation spellings
--     'electrician' and 'plumber' (they are home services everywhere this
--     function is consulted, including resolve_my_merchant, so adding them
--     is strictly a correction).
--   * _provision_business_target canonicalises those spellings up front, so
--     the service_categories lookup resolves the real row and the
--     existing-provider lookup matches rows already stored under the
--     canonical type (the exact zz-demo case: an approved 'electrical'
--     profile plus a pending 'electrician' request now attaches to the
--     existing row instead of erroring).
--
-- Scope discipline:
--   * ONLY these two helpers change. decide_provider_profile_request and
--     the other callers are untouched; they simply stop hitting the bad
--     branch.
--   * No table, constraint, grant or policy changes.
--
-- Preimage guards pin the live 399/403 bodies by full md5 under the exact
-- regprocedure signature; any drift aborts the migration before anything
-- changes.

BEGIN;

-- ── _is_home_service_category ─────────────────────────────────────────
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE p.oid = 'public._is_home_service_category(text)'::regprocedure);
BEGIN
  IF v_md5 IS DISTINCT FROM 'bfad300ccd8e9990e0300a0d8525e2a1' THEN
    RAISE EXCEPTION '438: _is_home_service_category drifted (md5 %), aborting', v_md5;
  END IF;
END $g$;

CREATE OR REPLACE FUNCTION public._is_home_service_category(p_cat text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT lower(btrim(COALESCE(p_cat, ''))) IN (
    'service', 'home_services', 'homeservices', 'plumbing', 'electrical',
    'cleaning', 'handyman', 'carpentry', 'ac_maintenance', 'acmaintenance',
    'painting', 'pest_control', 'pestcontrol', 'appliance_repair',
    'appliancerepair', 'doctor', 'clinic',
    -- added in 399
    'teacher', 'teachers', 'tutor', 'nurse', 'barber', 'other',
    'pipe_change', 'pipechange', 'plastering',
    'carpet_cleaning', 'carpetcleaning', 'dish_repair', 'dishrepair',
    -- added in 438: occupation spellings of categories already listed
    'electrician', 'plumber'
  );
$function$;

-- ── _provision_business_target ────────────────────────────────────────
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE p.oid = 'public._provision_business_target(uuid,text,text)'::regprocedure);
BEGIN
  IF v_md5 IS DISTINCT FROM '6a5c26fe8d1769ef5e924a7993b0ae96' THEN
    RAISE EXCEPTION '438: _provision_business_target drifted (md5 %), aborting', v_md5;
  END IF;
END $g$;

CREATE OR REPLACE FUNCTION public._provision_business_target(p_user_id uuid, p_category_type text, p_display_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user record;
  v_cat text := lower(btrim(COALESCE(p_category_type, 'restaurant')));
  v_name text;
  v_merchant_id uuid;
  v_sp_id uuid;
  v_sp_cat text;
BEGIN
  -- 438: occupation spellings map onto the canonical category (399
  -- vocabulary). Without this, 'electrician' missed the home-service test,
  -- fell into the merchant branch and violated merchants_type_check
  -- (23514 -> admin app conflict error), or would have duplicated a
  -- provider already stored under the canonical spelling.
  v_cat := CASE v_cat
    WHEN 'electrician' THEN 'electrical'
    WHEN 'plumber' THEN 'plumbing'
    ELSE v_cat
  END;

  SELECT id, full_name, email, phone, avatar_url, profile_photo_url
    INTO v_user
    FROM public.users
   WHERE id = p_user_id;

  v_name := COALESCE(
    NULLIF(btrim(p_display_name), ''),
    NULLIF(btrim(v_user.full_name), ''),
    'Delwaqty ' || initcap(v_cat)
  );

  IF public._is_home_service_category(v_cat) THEN
    -- Canonical service_categories.type spelling (camelCase for multi-word
    -- types such as acMaintenance), so customer-app category matching works.
    IF v_cat IN ('service', 'home_services', 'homeservices') THEN
      v_sp_cat := 'plumbing';
    ELSE
      SELECT type INTO v_sp_cat
        FROM public.service_categories
       WHERE lower(replace(type, '_', '')) = replace(v_cat, '_', '')
       ORDER BY is_active DESC, created_at ASC
       LIMIT 1;
      v_sp_cat := COALESCE(v_sp_cat, v_cat);
    END IF;
    SELECT id INTO v_sp_id
      FROM public.service_providers
     WHERE user_id = p_user_id
       AND lower(replace(category_type, '_', '')) = lower(replace(v_sp_cat, '_', ''))
     LIMIT 1;

    -- No fallback to the user's first service row: a second category must get
    -- its own service_providers row, never share the first one.

    IF v_sp_id IS NULL THEN
      INSERT INTO public.service_providers (
        user_id, name, category_type, description, profile_image_url,
        rating, rating_count, is_verified, is_available, hourly_rate
      )
      VALUES (
        p_user_id,
        v_name,
        v_sp_cat,
        '',
        COALESCE(v_user.profile_photo_url, v_user.avatar_url),
        5.0,
        0,
        true,
        true,
        NULL -- use live category defaults, preserve provider override semantics (397)
      )
      RETURNING id INTO v_sp_id;
    END IF;
  ELSE
    SELECT id INTO v_merchant_id
      FROM public.merchants
     WHERE owner_user_id = p_user_id AND lower(type) = v_cat
     ORDER BY created_at ASC
     LIMIT 1;

    IF v_merchant_id IS NULL THEN
      INSERT INTO public.merchants (
        owner_user_id, name, email, phone, type, status, is_open,
        delivery_fee, min_order, delivery_time_min, rating
      )
      VALUES (
        p_user_id,
        v_name,
        COALESCE(v_user.email, ''),
        v_user.phone,
        v_cat,
        'active',
        true,
        15,
        0,
        30,
        5.0
      )
      RETURNING id INTO v_merchant_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'merchant_id', v_merchant_id,
    'service_provider_id', v_sp_id
  );
END;
$function$;

-- ── Postchecks ────────────────────────────────────────────────────────
DO $$
BEGIN
  -- Properties preserved.
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
     WHERE p.oid = 'public._is_home_service_category(text)'::regprocedure
       AND p.provolatile = 'i'
       AND NOT p.prosecdef
       AND p.proconfig = ARRAY['search_path=public, pg_temp']
  ) THEN
    RAISE EXCEPTION '438: _is_home_service_category properties changed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
     WHERE p.oid = 'public._provision_business_target(uuid,text,text)'::regprocedure
       AND p.prosecdef
       AND p.proconfig = ARRAY['search_path=public, pg_temp']
  ) THEN
    RAISE EXCEPTION '438: _provision_business_target properties changed';
  END IF;

  -- Behaviour: occupation spellings are home services and canonicalise.
  IF NOT public._is_home_service_category('electrician')
     OR NOT public._is_home_service_category('plumber') THEN
    RAISE EXCEPTION '438: occupation spellings not recognised';
  END IF;
END $$;

COMMIT;
