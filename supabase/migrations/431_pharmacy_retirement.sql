-- 431: pharmacy RETIREMENT - non-destructive, separately committed.
--
-- Owner decision 2026-11-24: pharmacy removed everywhere ahead of the
-- Play launch. This is the FIRST of two pharmacy migrations and the only
-- one that must land before the destructive one:
--   431 (this)  - server-side retirement: merchants suspended, categories
--                 and offers deactivated, open pharmacy_delivery offers
--                 expired/cancelled, driver capability refuses pharmacy,
--                 owner workspace stops provisioning a pharmacy business.
--                 No DELETE, no DROP: if the destructive migration later
--                 aborts on a guard, this retirement stays committed and
--                 the platform is still dark to clients (code review #161).
--   433         - cashier drug_catalog drop (cashier worker).
--   434         - whatsapp_otp (other workstream).
--   435         - destructive pharmacy purge (gated, backup-first).
-- Apply order: 431 -> 433 -> 434 -> 435. Never run 435 before 431.
--
-- Everything below is idempotent: UPDATE/CREATE OR REPLACE only, safe to
-- re-run; a second run changes nothing.

BEGIN;

-- ─── Phase A0: pre-image guards (code review #164) ────────────────────
-- Every function this migration replaces must match EITHER the live prod
-- pre-image OR this migration's own post-image (second run). Pre-image
-- md5s: security reviewer, live prod, 2026-11-24 02:34. Post-image md5s:
-- md5 of the exact bodies written below. Both states get the SAME owner,
-- secdef, volatility, proconfig and EXECUTE-grantee checks. Selection is
-- by full regprocedure identity; overloads or missing functions abort.
-- Anything else is drift and aborts BEFORE any replacement.
DO $g$
DECLARE
  r record;
  a_md5 text;
  a_secdef boolean;
  a_vol "char";
  a_cfg text;
  a_owner text;
  a_grantees text[];
  e_grantees text[];
  v_oid oid;
  v_overload int;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('get_my_provider_profiles()',                          '9f45176caf5e91da1fc624606bc5e1aa', '0f5a1c5eb6f13677ed7c9f77cf6c95eb', true,  'v', 'search_path=public, pg_temp', ARRAY['authenticated','postgres','service_role']::text[]),
      ('complete_driver_onboarding(uuid)',                    'd43a563b39a380d965010570148cc468', '7c8dd90a0aa2ed8396e8100d8b499888', true,  'v', 'search_path=public, pg_temp', ARRAY['authenticated','postgres','service_role']::text[]),
      ('update_driver_capabilities(uuid,text[],boolean,numeric,numeric)', 'fbfec66a1f65dbb56fbb543ea4ebea6d', '0227ce83f9b08dc744d2e75f50de8566', true, 'v', 'search_path=public, pg_temp', ARRAY['authenticated','postgres','service_role']::text[]),
      ('driver_capability_bounds_guard()',                    'd56159075af9ef0e54a2cfd737a887b4', 'b0592984b89143247f787ba91c4051c0', false, 'v', 'search_path=public, pg_temp', ARRAY['postgres','service_role']::text[]),
      ('search_intent_category(text)',                        '5c2a0cc400839a21171c501a1677a36f', '05e8d790f1466cb6b8ae9a7f6c3e47f6', false, 'i', '',                          ARRAY['anon','authenticated','postgres','service_role']::text[]),
      ('request_additional_provider_profile(text,text)',      '6a2765e31eab9b3824a08253b43db94f', '9a872ff9f1a33289602890135479614e', true,  'v', 'search_path=public, pg_temp', ARRAY['authenticated','postgres','service_role']::text[]),
      ('switch_active_provider_profile(text)',                '0d74c205b2d06ff31d54d71194a7bea6', 'db574dfddd424c2ec132099e82f67e4c', true,  'v', 'search_path=public, pg_temp', ARRAY['authenticated','postgres','service_role']::text[])
    ) AS t(sig, md5_pre, md5_post, secdef, vol, cfg, grantees)
  LOOP
    -- full identity selection; reject missing or overloaded
    v_oid := ('public.' || r.sig)::regprocedure;
    SELECT count(*) INTO v_overload
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = substring(r.sig from '^[^(]+');
    IF v_overload <> 1 THEN
      RAISE EXCEPTION '431: % has % overloads - drift, aborting', r.sig, v_overload;
    END IF;

    SELECT md5(p.prosrc), p.prosecdef, p.provolatile,
           coalesce(array_to_string(p.proconfig, ','), ''),
           (SELECT rolname FROM pg_roles WHERE oid = p.proowner)
      INTO a_md5, a_secdef, a_vol, a_cfg, a_owner
      FROM pg_proc p WHERE p.oid = v_oid;

    IF a_md5 <> r.md5_pre AND a_md5 <> r.md5_post THEN
      RAISE EXCEPTION '431: % prosrc md5 % matches neither the known pre-image nor the post-image - drift, aborting', r.sig, a_md5;
    END IF;
    IF a_md5 = r.md5_post THEN
      RAISE NOTICE '431: % already at post-image (second run)', r.sig;
    END IF;

    -- the SAME shape checks regardless of pre/post state
    IF a_owner <> 'postgres' THEN
      RAISE EXCEPTION '431: % owner drift (% vs postgres) - aborting', r.sig, a_owner;
    END IF;
    IF a_secdef IS DISTINCT FROM r.secdef OR a_vol <> r.vol THEN
      RAISE EXCEPTION '431: % secdef/volatility drift - aborting', r.sig;
    END IF;
    IF a_cfg <> r.cfg THEN
      RAISE EXCEPTION '431: % proconfig drift (% vs %) - aborting', r.sig, a_cfg, r.cfg;
    END IF;

    SELECT array_agg(g ORDER BY g) INTO a_grantees
      FROM (SELECT DISTINCT CASE WHEN x.grantee = 0 THEN 'PUBLIC'
                                 ELSE (SELECT rolname FROM pg_roles WHERE oid = x.grantee) END AS g
              FROM pg_proc p,
                   aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) x
             WHERE p.oid = v_oid
               AND x.privilege_type = 'EXECUTE') d;
    e_grantees := (SELECT array_agg(g ORDER BY g) FROM unnest(r.grantees) g);
    IF a_grantees IS DISTINCT FROM e_grantees THEN
      RAISE EXCEPTION '431: % EXECUTE grantees drift (% vs %) - aborting', r.sig, a_grantees, e_grantees;
    END IF;
  END LOOP;
END $g$;

-- Trigger shape: driver_capability_bounds on public.drivers must point at
-- driver_capability_bounds_guard, be enabled, BEFORE INSERT OR UPDATE,
-- FOR EACH ROW, on the four capability columns.
DO $g$
DECLARE
  v_t record;
  v_expected_cols int2[];
BEGIN
  SELECT t.tgenabled, t.tgtype, t.tgattr,
         (SELECT p.proname FROM pg_proc p WHERE p.oid = t.tgfoid) AS fn
    INTO v_t
    FROM pg_trigger t
   WHERE t.tgrelid = 'public.drivers'::regclass
     AND t.tgname = 'driver_capability_bounds'
     AND NOT t.tgisinternal;
  IF NOT FOUND THEN
    RAISE EXCEPTION '431: driver_capability_bounds trigger missing on public.drivers - drift, aborting';
  END IF;
  SELECT array_agg(a.attnum ORDER BY a.attnum)::int2[] INTO v_expected_cols
    FROM pg_attribute a
   WHERE a.attrelid = 'public.drivers'::regclass
     AND a.attname IN ('service_types','accepts_deliveries','max_delivery_distance_km','max_weight_kg');
  -- ROW(1) + BEFORE(2) + INSERT(4) + UPDATE(16) = 23
  IF v_t.fn <> 'driver_capability_bounds_guard'
     OR v_t.tgenabled <> 'O'
     OR v_t.tgtype <> 23
     OR v_t.tgattr::text <> array_to_string(v_expected_cols, ' ') THEN
    RAISE EXCEPTION '431: driver_capability_bounds trigger shape drift (fn=%, enabled=%, type=%, cols=%) - aborting',
      v_t.fn, v_t.tgenabled, v_t.tgtype, v_t.tgattr;
  END IF;
END $g$;

-- Column default: exactly the 4-value pre array WITH pharmacy or the
-- 3-value post array; anything else is drift.
DO $g$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_expr(a.adbin, a.adrelid) INTO v_def
    FROM pg_attrdef a
   WHERE a.adrelid = 'public.drivers'::regclass
     AND a.adnum = (SELECT attnum FROM pg_attribute
                     WHERE attrelid = 'public.drivers'::regclass AND attname = 'service_types');
  IF v_def = 'ARRAY[''food''::text, ''grocery''::text, ''pharmacy''::text, ''parcel''::text]' THEN
    NULL;  -- exact pre-image, proceed
  ELSIF v_def = 'ARRAY[''food''::text, ''grocery''::text, ''parcel''::text]' THEN
    RAISE NOTICE '431: drivers.service_types default already at post-image';
  ELSE
    RAISE EXCEPTION '431: drivers.service_types default drift (%) - aborting', v_def;
  END IF;
END $g$;

-- ─── Phase A1: driver delivery capability without pharmacy ─────────────
-- Canonical full delivery set becomes {food, grocery, parcel}.
-- Recreates the 416 trio + the 427 column default.

CREATE OR REPLACE FUNCTION public.complete_driver_onboarding(p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d public.drivers%ROWTYPE;
BEGIN
 SELECT * INTO d FROM public.drivers WHERE id=p_driver_id FOR UPDATE;
 IF auth.uid() IS NULL OR d.user_id IS DISTINCT FROM auth.uid() THEN
  RETURN jsonb_build_object('success',false,'reason','FORBIDDEN');
 END IF;
 IF NOT public.driver_application_documents_ready(p_driver_id) THEN
  RETURN jsonb_build_object('success',false,'reason','REQUIRED_DOCUMENTS_MISSING');
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.vehicles WHERE driver_id=p_driver_id AND is_active=true) THEN
  RETURN jsonb_build_object('success',false,'reason','ACTIVE_VEHICLE_REQUIRED');
 END IF;
 UPDATE public.drivers SET onboarding_completed=true,onboarding_step=5,
   service_types=CASE WHEN NOT coalesce(d.onboarding_completed,false) AND coalesce(cardinality(service_types),0)=0 THEN ARRAY['food','grocery','parcel']::text[] ELSE service_types END,
   accepts_deliveries=CASE WHEN NOT coalesce(d.onboarding_completed,false) THEN true ELSE accepts_deliveries END,
   verification_status=CASE WHEN is_verified THEN verification_status ELSE 'pending' END,
   updated_at=now() WHERE id=p_driver_id;
 RETURN jsonb_build_object('success',true);
END; $function$
;

CREATE OR REPLACE FUNCTION public.update_driver_capabilities(p_driver_id uuid, p_service_types text[], p_accepts_deliveries boolean, p_max_delivery_distance numeric, p_max_weight numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  IF p_service_types IS NULL OR NOT p_service_types <@ ARRAY['food','grocery','parcel']::text[]
     OR (p_accepts_deliveries AND cardinality(p_service_types)=0)
     OR p_accepts_deliveries IS NULL
     OR p_max_delivery_distance IS NULL OR p_max_delivery_distance<=0 OR p_max_delivery_distance>200
     OR p_max_weight IS NULL OR p_max_weight<=0 OR p_max_weight>1000 THEN
    RETURN jsonb_build_object('success',false,'reason','INVALID_CAPABILITIES');
  END IF;
  UPDATE drivers SET
    service_types = p_service_types,
    accepts_deliveries = p_accepts_deliveries,
    max_delivery_distance_km = p_max_delivery_distance,
    max_weight_kg = p_max_weight,
    updated_at = NOW()
  WHERE id = p_driver_id;
  RETURN jsonb_build_object('success', true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.driver_capability_bounds_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO public,pg_temp AS $$
BEGIN
 IF NEW.accepts_deliveries IS NULL OR NEW.service_types IS NULL OR NOT NEW.service_types <@ ARRAY['food','grocery','parcel']::text[]
    OR (NEW.accepts_deliveries AND cardinality(NEW.service_types)=0)
    OR NEW.max_delivery_distance_km IS NULL OR NEW.max_delivery_distance_km<=0 OR NEW.max_delivery_distance_km>200
    OR NEW.max_weight_kg IS NULL OR NEW.max_weight_kg<=0 OR NEW.max_weight_kg>1000 THEN
   RAISE EXCEPTION 'INVALID_CAPABILITIES' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;

ALTER TABLE public.drivers ALTER COLUMN service_types
  SET DEFAULT ARRAY['food','grocery','parcel']::text[];

-- Existing rows: strip only the retired element. A driver who listed ONLY
-- pharmacy deliveries keeps an EMPTY capability array and is flipped to
-- accepts_deliveries=false (ride-hail only) - never broadened silently.
UPDATE public.drivers
   SET service_types = array_remove(service_types, 'pharmacy'),
       accepts_deliveries = CASE
         WHEN cardinality(array_remove(service_types, 'pharmacy')) = 0 THEN false
         ELSE accepts_deliveries
       END,
       updated_at = now()
 WHERE service_types @> ARRAY['pharmacy']::text[];

-- ─── Phase A2: search intent without the drug branch ────────────────────
CREATE OR REPLACE FUNCTION public.search_intent_category(p_query text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    WHEN lower(coalesce(p_query,'')) ~ E'(\\mطع|حمار|اكل|اكلات|مقلى|براستد|شاورما|بيتزا|برجر|كشري|فول|طعميه)'  THEN 'food'
    WHEN lower(coalesce(p_query,'')) ~ E'(\\mخضار|فاكهه|بقاله|سوبر|ماركت|زيت|ارز|سكر|شاي)'               THEN 'grocery'
    WHEN lower(coalesce(p_query,'')) ~ E'(\\mعايز|ابعت|يوصل|توصيل|هيصلك|مندوب|شحنه|وصل|ابعت طلب|حد يوصل)' THEN 'delivery'
    WHEN lower(coalesce(p_query,'')) ~ E'(\\mسباك|كهربا|تكييف|صيانه|عامل|نجار|دهان|نظافه|خدمه)'           THEN 'service'
    ELSE 'general'
  END;
$function$
;

-- ─── Phase A3: owner workspace provisioning without pharmacy ────────────
CREATE OR REPLACE FUNCTION public.get_my_provider_profiles()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_is_owner boolean;
  v_active text;
  v_cat text;
  v_target jsonb;
  v_m record;
  v_sp record;
  v_owner_cats text[] := ARRAY[
    'restaurant', 'grocery', 'bakery', 'home_services', 'electronics', 'fashion'
  ];
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  v_is_owner := public._is_owner_uid(v_uid);
  SELECT active_provider_category INTO v_active FROM public.users WHERE id = v_uid;

  IF v_is_owner THEN
    FOREACH v_cat IN ARRAY v_owner_cats LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.provider_business_profiles
         WHERE user_id = v_uid AND category_type = v_cat
      ) THEN
        v_target := public._provision_business_target(v_uid, v_cat, 'Delwaqty ' || initcap(replace(v_cat, '_', ' ')));
        INSERT INTO public.provider_business_profiles (
          user_id, category_type, display_name, status,
          merchant_id, service_provider_id, reviewed_by, reviewed_at
        )
        VALUES (
          v_uid,
          v_cat,
          'Delwaqty ' || initcap(replace(v_cat, '_', ' ')),
          'approved',
          (v_target->>'merchant_id')::uuid,
          (v_target->>'service_provider_id')::uuid,
          v_uid,
          now()
        )
        ON CONFLICT (user_id, category_type) DO UPDATE
          SET status = 'approved',
              merchant_id = COALESCE(public.provider_business_profiles.merchant_id, EXCLUDED.merchant_id),
              service_provider_id = COALESCE(public.provider_business_profiles.service_provider_id, EXCLUDED.service_provider_id);
      END IF;
    END LOOP;
    IF v_active IS NULL OR btrim(v_active) = '' THEN
      v_active := 'restaurant';
      UPDATE public.users SET active_provider_category = v_active WHERE id = v_uid;
    END IF;
  ELSE
    FOR v_m IN
      SELECT id, name, type FROM public.merchants
       WHERE owner_user_id = v_uid
         AND type <> 'pharmacy'
         AND status = 'active'
       ORDER BY created_at ASC
    LOOP
      INSERT INTO public.provider_business_profiles (
        user_id, category_type, display_name, status, merchant_id
      )
      VALUES (
        v_uid, COALESCE(NULLIF(v_m.type, ''), 'restaurant'), COALESCE(NULLIF(v_m.name, ''), 'My Store'), 'approved', v_m.id
      )
      ON CONFLICT (user_id, category_type) DO NOTHING;
    END LOOP;

    FOR v_sp IN
      SELECT id, name, category_type FROM public.service_providers WHERE user_id = v_uid ORDER BY created_at ASC
    LOOP
      INSERT INTO public.provider_business_profiles (
        user_id, category_type, display_name, status, service_provider_id
      )
      VALUES (
        v_uid, 'home_services', COALESCE(NULLIF(v_sp.name, ''), 'My Service'), 'approved', v_sp.id
      )
      ON CONFLICT (user_id, category_type) DO NOTHING;
    END LOOP;

    IF v_active IS NULL OR btrim(v_active) = '' THEN
      SELECT category_type INTO v_active
        FROM public.provider_business_profiles
       WHERE user_id = v_uid AND status = 'approved'
         AND category_type <> 'pharmacy'
       ORDER BY created_at ASC
       LIMIT 1;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'is_owner', v_is_owner,
    'active_category', COALESCE(v_active, 'restaurant'),
    'profiles', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'category_type', category_type,
          'display_name', display_name,
          'status', status,
          'merchant_id', merchant_id,
          'service_provider_id', service_provider_id,
          'rejection_reason', rejection_reason,
          'created_at', created_at
        )
        ORDER BY (status = 'approved') DESC, created_at ASC
      )
      FROM public.provider_business_profiles
      WHERE user_id = v_uid
        AND category_type <> 'pharmacy'
    ), '[]'::jsonb)
  );
END;
$function$
;


-- ─── Phase A4: retired-category denial at every entry boundary ────────
-- #163 broader: request/switch/provision must refuse 'pharmacy' even for
-- owner accounts. Pre-image guarded in Phase A0. Same secdef flag and
-- search_path as prod.

CREATE OR REPLACE FUNCTION public.request_additional_provider_profile(p_category_type text, p_display_name text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_cat text := lower(btrim(COALESCE(p_category_type, '')));
  v_is_owner boolean;
  v_name text := btrim(COALESCE(p_display_name, ''));
  v_target jsonb;
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_cat = '' THEN
    RAISE EXCEPTION 'Category is required';
  END IF;
  IF v_cat = 'pharmacy' THEN
    RAISE EXCEPTION 'This category is retired';
  END IF;

  v_is_owner := public._is_owner_uid(v_uid);
  IF v_name = '' THEN
    SELECT COALESCE(NULLIF(btrim(full_name), ''), 'Delwaqty ' || initcap(v_cat))
      INTO v_name
      FROM public.users
     WHERE id = v_uid;
  END IF;

  IF v_is_owner THEN
    v_target := public._provision_business_target(v_uid, v_cat, v_name);
    INSERT INTO public.provider_business_profiles (
      user_id, category_type, display_name, status,
      merchant_id, service_provider_id, reviewed_by, reviewed_at
    )
    VALUES (
      v_uid, v_cat, v_name, 'approved',
      (v_target->>'merchant_id')::uuid,
      (v_target->>'service_provider_id')::uuid,
      v_uid, now()
    )
    ON CONFLICT (user_id, category_type) DO UPDATE
      SET status = 'approved',
          display_name = EXCLUDED.display_name,
          updated_at = now()
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('ok', true, 'id', v_id, 'status', 'approved');
  END IF;

  INSERT INTO public.provider_business_profiles (
    user_id, category_type, display_name, status
  )
  VALUES (v_uid, v_cat, v_name, 'pending')
  ON CONFLICT (user_id, category_type) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        status = CASE
          WHEN public.provider_business_profiles.status = 'approved' THEN 'approved'
          ELSE 'pending'
        END,
        rejection_reason = NULL,
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'status', 'pending');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.switch_active_provider_profile(p_category_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_cat text := lower(btrim(COALESCE(p_category_type, '')));
  v_is_owner boolean;
  v_profile public.provider_business_profiles%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_cat = '' THEN
    RAISE EXCEPTION 'Category is required';
  END IF;
  IF v_cat = 'pharmacy' THEN
    RAISE EXCEPTION 'This category is retired';
  END IF;

  v_is_owner := public._is_owner_uid(v_uid);

  SELECT * INTO v_profile
    FROM public.provider_business_profiles
   WHERE user_id = v_uid AND category_type = v_cat;

  IF NOT v_is_owner THEN
    IF NOT FOUND OR v_profile.status <> 'approved' THEN
      RAISE EXCEPTION 'This service profile is not approved for your account yet';
    END IF;
  END IF;

  UPDATE public.users
     SET active_provider_category = v_cat,
         updated_at = now()
   WHERE id = v_uid;

  RETURN jsonb_build_object(
    'ok', true,
    'active_category', v_cat,
    'merchant_id', v_profile.merchant_id,
    'service_provider_id', v_profile.service_provider_id
  );
END;
$function$
;

-- ─── Phase B0: server-side deactivation (enforcement net) ─────────────
-- The four apps no longer show pharmacy anything, but filters alone are
-- client-side. This phase makes the server stop serving legacy pharmacy
-- rows the moment this migration lands: the merchant is suspended and
-- closed, its categories and offers go inactive, and open driver offers
-- on pharmacy_delivery rides expire so no captain can accept one.
-- Idempotent; runs before the guarded deletes so even a row whose
-- dependents block Phase B is already dark to every client.

-- Legacy pharmacy merchant(s): suspended + marked closed.
UPDATE public.merchants
   SET status = 'suspended', is_open = false, updated_at = now()
 WHERE type = 'pharmacy'
   AND (status <> 'suspended' OR is_open);

-- Pharmacy category rows (prod-seeded, not created by any migration).
UPDATE public.categories
   SET is_active = false
 WHERE is_active
   AND (lower(coalesce(name,'')) LIKE '%pharm%'
     OR lower(coalesce(name_en,'')) LIKE '%pharm%'
     OR coalesce(name_ar,'') LIKE '%صيدل%');

UPDATE public.catalog_categories
   SET is_active = false
 WHERE is_active AND merchant_type = 'pharmacy';

-- Offers attached to a pharmacy merchant or to the pharmacy category.
UPDATE public.offers
   SET is_active = false
 WHERE is_active
   AND (merchant_id IN (SELECT id FROM public.merchants WHERE type = 'pharmacy')
     OR category_id IN (SELECT id FROM public.catalog_categories
                         WHERE merchant_type = 'pharmacy'));

-- Open driver offers on pharmacy_delivery rides: expire them, and cancel
-- rides still searching so no new offer goes out.
UPDATE public.ride_requests
   SET status = 'expired', responded_at = now()
 WHERE status = 'offered'
   AND ride_id IN (SELECT id FROM public.rides WHERE service_type = 'pharmacy_delivery');

UPDATE public.rides
   SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'system',
       cancellation_reason = 'pharmacy delivery discontinued'
 WHERE service_type = 'pharmacy_delivery'
   AND status = 'searching';

-- Pharmacy delivery pricing: stop quoting it.
UPDATE public.delivery_pricing
   SET is_active = false, updated_at = now()
 WHERE service_type = 'pharmacy_delivery' AND is_active;

-- ─── Phase R5: refuse pharmacy RPCs server-side NOW (code review #171) ─
-- The import + inter-pharmacy network RPCs only DROP in 435, and 435 can
-- block on guards. Until then they must refuse to execute. Live ACLs are
-- postgres/authenticated/service_role; revoke the client-facing grants.
-- Existence-aware: a second run is a no-op.
DO $r$
DECLARE
  v_fn text;
  v_sigs text[] := ARRAY[
    'pharmacy_import_drug(uuid,uuid,numeric,integer)',
    'pharmacy_directory(uuid)',
    'pharmacy_link_create(uuid,uuid)',
    'pharmacy_transfer_request(uuid,text,numeric,uuid,text)',
    'pharmacy_transfer_respond(uuid,boolean,numeric)',
    'pharmacy_transfer_handover(uuid,numeric)',
    'pharmacy_transfer_settle(uuid,text,numeric,text)',
    'pharmacy_transfer_settle_confirm(uuid,boolean)',
    'pharmacy_message_send(uuid,text,uuid)'
  ];
BEGIN
  FOREACH v_fn IN ARRAY v_sigs LOOP
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'public'
                  AND p.proname = split_part(v_fn, '(', 1)) THEN
      EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', v_fn);
    END IF;
  END LOOP;
END $r$;

-- ─── Phase R6: retire pharmacy workspaces + active selections ─────────
-- Live prod (security review, 2026-11-24): 2 approved
-- provider_business_profiles with category_type='pharmacy', 1 user with
-- active_provider_category='pharmacy'. The merchant FK is ON DELETE SET
-- NULL, so without this the workspace would orphan and keep surfacing.

DELETE FROM public.provider_business_profiles
 WHERE category_type = 'pharmacy';

UPDATE public.users
   SET active_provider_category = NULL, updated_at = now()
 WHERE active_provider_category = 'pharmacy';

-- ─── Retirement post-check: server is dark even before the purge ──────
DO $g$
BEGIN
  IF EXISTS (SELECT 1 FROM public.merchants WHERE type = 'pharmacy' AND (status <> 'suspended' OR is_open))
     OR EXISTS (SELECT 1 FROM public.categories WHERE is_active AND (lower(coalesce(name,'')) LIKE '%pharm%' OR lower(coalesce(name_en,'')) LIKE '%pharm%' OR coalesce(name_ar,'') LIKE '%صيدل%'))
     OR EXISTS (SELECT 1 FROM public.catalog_categories WHERE is_active AND merchant_type = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.offers o JOIN public.merchants m ON m.id = o.merchant_id WHERE m.type = 'pharmacy' AND o.is_active)
     OR EXISTS (SELECT 1 FROM public.offers o JOIN public.catalog_categories cc ON cc.id = o.category_id WHERE cc.merchant_type = 'pharmacy' AND o.is_active)
     OR EXISTS (SELECT 1 FROM public.ride_requests rq JOIN public.rides r ON r.id = rq.ride_id WHERE r.service_type = 'pharmacy_delivery' AND rq.status = 'offered')
     OR EXISTS (SELECT 1 FROM public.rides WHERE service_type = 'pharmacy_delivery' AND status = 'searching')
     OR EXISTS (SELECT 1 FROM public.delivery_pricing WHERE service_type = 'pharmacy_delivery' AND is_active)
     OR EXISTS (SELECT 1 FROM public.provider_business_profiles WHERE category_type = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.users WHERE active_provider_category = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.drivers WHERE service_types @> ARRAY['pharmacy']::text[])
     OR EXISTS (SELECT 1
                  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
                       aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
                 WHERE n.nspname = 'public'
                   AND p.proname IN ('pharmacy_import_drug','pharmacy_directory','pharmacy_link_create',
                                     'pharmacy_transfer_request','pharmacy_transfer_respond','pharmacy_transfer_handover',
                                     'pharmacy_transfer_settle','pharmacy_transfer_settle_confirm','pharmacy_message_send')
                   AND a.privilege_type = 'EXECUTE'
                   AND (a.grantee = 0
                     OR a.grantee IN ('authenticated'::regrole, 'anon'::regrole)))
  THEN
    RAISE EXCEPTION '431: pharmacy retirement incomplete - aborting';
  END IF;
END $g$;

COMMIT;
