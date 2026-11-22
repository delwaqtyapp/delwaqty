-- 397_admin_provider_pricing.sql
-- Admin-managed home-service provider pricing, INHERITED model.
--
-- Model (review #91/#93): provider columns are overrides only. NULL means
-- "follow the category default live"; when neither provider nor category
-- sets a value the platform default of 150 EGP/hour applies. Hourly
-- inherits independently. The fixed min/max pair is ONE override: both
-- provider values set = provider pair, otherwise the whole pair follows
-- the category. One resolver, service_provider_effective_pricing(), is
-- used by every price read (admin/provider RPCs and the booking
-- normalizer) so the displayed price is the booking truth.
--
--   1. public.service_category_pricing - per-category default rates
--      (platform-wide; owner / country-level admins only).
--   2. admin_set_provider_pricing - set provider overrides under the same
--      scope rule as the "Admins can manage providers" table policy.
--   3. admin_set_category_pricing - upsert a category default
--      (owner / country-level only, row locked so the audit logs the true
--      old value).
--   4. admin_list_provider_pricing / admin_list_category_pricing - scoped
--      read paths backing the admin editor.
--   5. provider_get_my_pricing - read-only self view (used by the
--      provider app's pricing page).
--   6. Table-level guard: a BEFORE UPDATE trigger on service_providers
--      validates pricing ranges and audits every pricing change,
--      including direct admin table writes outside the RPC.
--   7. service_bookings_normalize_insert resolves the estimate floor via
--      the shared resolver.
--   8. _provision_business_target leaves hourly_rate NULL so new
--      providers inherit live (one-token delta; 399 composes on top).
--
-- Seeding (step 1) deliberately writes no audit rows: it records the
-- pre-existing 150 EGP platform default, not a human decision. Every
-- change after that is audited by the RPC or the table trigger.

BEGIN;

-- ---------- 1. category default pricing table ----------
CREATE TABLE IF NOT EXISTS public.service_category_pricing (
  category_type text PRIMARY KEY,
  hourly_rate numeric(10,2),
  fixed_price_min numeric(10,2),
  fixed_price_max numeric(10,2),
  currency text NOT NULL DEFAULT 'EGP',
  updated_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT service_category_pricing_ranges_chk CHECK (
    (hourly_rate IS NULL OR (hourly_rate >= 0 AND hourly_rate <= 10000))
    AND (fixed_price_min IS NULL OR (fixed_price_min >= 0 AND fixed_price_min <= 100000))
    AND (fixed_price_max IS NULL OR (fixed_price_max >= 0 AND fixed_price_max <= 100000))
    AND (fixed_price_min IS NULL OR fixed_price_max IS NULL
         OR fixed_price_min <= fixed_price_max)
  )
);

ALTER TABLE public.service_category_pricing ENABLE ROW LEVEL SECURITY;

-- Read-only for signed-in users (category defaults are public price
-- information). No write policies: all writes go through the SECURITY
-- DEFINER admin RPC below.
DROP POLICY IF EXISTS "service_category_pricing read" ON public.service_category_pricing;
CREATE POLICY "service_category_pricing read" ON public.service_category_pricing
  FOR SELECT TO authenticated
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON TABLE public.service_category_pricing FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.service_category_pricing FROM authenticated;
GRANT SELECT ON TABLE public.service_category_pricing TO authenticated;

-- Seed one default row per active category (full catalog, so 399's wider
-- vocabulary is covered) recording the pre-existing platform default.
-- No audit rows: this documents current behavior, it is not a decision.
INSERT INTO public.service_category_pricing (category_type, hourly_rate)
SELECT c.type, 150
  FROM public.service_categories c
 WHERE c.is_active
ON CONFLICT (category_type) DO NOTHING;

-- ---------- shared validation ----------
CREATE OR REPLACE FUNCTION public._assert_valid_provider_pricing(
  p_hourly_rate numeric,
  p_fixed_price_min numeric,
  p_fixed_price_max numeric
)
 RETURNS void
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_hourly_rate IS NOT NULL AND (p_hourly_rate < 0 OR p_hourly_rate > 10000) THEN
    RAISE EXCEPTION 'invalid_hourly_rate';
  END IF;
  IF p_fixed_price_min IS NOT NULL AND (p_fixed_price_min < 0 OR p_fixed_price_min > 100000) THEN
    RAISE EXCEPTION 'invalid_fixed_price_min';
  END IF;
  IF p_fixed_price_max IS NOT NULL AND (p_fixed_price_max < 0 OR p_fixed_price_max > 100000) THEN
    RAISE EXCEPTION 'invalid_fixed_price_max';
  END IF;
  IF p_fixed_price_min IS NOT NULL AND p_fixed_price_max IS NOT NULL
     AND p_fixed_price_min > p_fixed_price_max THEN
    RAISE EXCEPTION 'fixed_price_min_above_max';
  END IF;
END;
$function$;

-- ---------- the one resolver: COALESCE(provider, category, 150) ----------
CREATE OR REPLACE FUNCTION public.service_provider_effective_pricing(p_provider_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_sp public.service_providers%ROWTYPE;
  v_cp public.service_category_pricing%ROWTYPE;
  v_fixed_min numeric;
  v_fixed_max numeric;
  v_fixed_source text;
BEGIN
  SELECT * INTO v_sp FROM public.service_providers WHERE id = p_provider_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  SELECT * INTO v_cp
    FROM public.service_category_pricing
   WHERE lower(category_type) = lower(v_sp.category_type);

  -- The fixed pair is one override: both provider values set = provider
  -- pair, otherwise the whole pair follows the category.
  IF v_sp.fixed_price_min IS NOT NULL AND v_sp.fixed_price_max IS NOT NULL THEN
    v_fixed_min := v_sp.fixed_price_min;
    v_fixed_max := v_sp.fixed_price_max;
    v_fixed_source := 'provider';
  ELSIF v_cp.fixed_price_min IS NOT NULL OR v_cp.fixed_price_max IS NOT NULL THEN
    v_fixed_min := v_cp.fixed_price_min;
    v_fixed_max := v_cp.fixed_price_max;
    v_fixed_source := 'category';
  ELSE
    v_fixed_min := NULL;
    v_fixed_max := NULL;
    v_fixed_source := 'none';
  END IF;

  RETURN jsonb_build_object(
    'hourly_rate', COALESCE(v_sp.hourly_rate, v_cp.hourly_rate, 150),
    'hourly_source', CASE
        WHEN v_sp.hourly_rate IS NOT NULL THEN 'provider'
        WHEN v_cp.hourly_rate IS NOT NULL THEN 'category'
        ELSE 'platform' END,
    'fixed_price_min', v_fixed_min,
    'fixed_price_max', v_fixed_max,
    'fixed_source', v_fixed_source,
    'currency', COALESCE(v_cp.currency, 'EGP')
  );
END;
$function$;

-- ---------- 6. table-level validation + audit (covers direct writes) ----------
CREATE OR REPLACE FUNCTION public.service_providers_pricing_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.hourly_rate IS DISTINCT FROM OLD.hourly_rate
     OR NEW.fixed_price_min IS DISTINCT FROM OLD.fixed_price_min
     OR NEW.fixed_price_max IS DISTINCT FROM OLD.fixed_price_max THEN
    PERFORM public._assert_valid_provider_pricing(
      NEW.hourly_rate, NEW.fixed_price_min, NEW.fixed_price_max);
    PERFORM public.write_audit(
      'PROVIDER_PRICING_CHANGED', 'service_providers', NEW.id::text,
      jsonb_build_object(
        'old', jsonb_build_object(
          'hourly_rate', OLD.hourly_rate,
          'fixed_price_min', OLD.fixed_price_min,
          'fixed_price_max', OLD.fixed_price_max),
        'new', jsonb_build_object(
          'hourly_rate', NEW.hourly_rate,
          'fixed_price_min', NEW.fixed_price_min,
          'fixed_price_max', NEW.fixed_price_max),
        'note', NULLIF(current_setting('app.pricing_note', true), '')
      ));
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_service_provider_pricing_guard ON public.service_providers;
CREATE TRIGGER trg_service_provider_pricing_guard
  BEFORE UPDATE ON public.service_providers
  FOR EACH ROW EXECUTE FUNCTION public.service_providers_pricing_guard();

-- ---------- 2. set provider overrides ----------
-- Explicit field semantics: a non-null value sets the override; a null
-- value leaves the stored value UNCHANGED unless the field is named in
-- p_clear_fields, which clears it to NULL (inherit). A partial call never
-- wipes its siblings.
CREATE OR REPLACE FUNCTION public.admin_set_provider_pricing(
  p_provider_id uuid,
  p_hourly_rate numeric DEFAULT NULL::numeric,
  p_fixed_price_min numeric DEFAULT NULL::numeric,
  p_fixed_price_max numeric DEFAULT NULL::numeric,
  p_clear_fields text[] DEFAULT '{}'::text[],
  p_note text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_sp public.service_providers%ROWTYPE;
  v_region uuid;
  v_note text := NULLIF(btrim(COALESCE(p_note, '')), '');
  v_new_hourly numeric;
  v_new_min numeric;
  v_new_max numeric;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_active_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;

  PERFORM public._assert_valid_provider_pricing(
    p_hourly_rate, p_fixed_price_min, p_fixed_price_max);

  IF p_clear_fields IS NOT NULL AND EXISTS (
    SELECT 1 FROM unnest(p_clear_fields) f
    WHERE f NOT IN ('hourly_rate', 'fixed_price_min', 'fixed_price_max')
  ) THEN
    RAISE EXCEPTION 'invalid_clear_fields';
  END IF;

  SELECT * INTO v_sp
    FROM public.service_providers
   WHERE id = p_provider_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'provider_not_found';
  END IF;

  v_new_hourly := CASE
    WHEN p_hourly_rate IS NOT NULL THEN p_hourly_rate
    WHEN 'hourly_rate' = ANY(COALESCE(p_clear_fields, '{}')) THEN NULL
    ELSE v_sp.hourly_rate END;
  v_new_min := CASE
    WHEN p_fixed_price_min IS NOT NULL THEN p_fixed_price_min
    WHEN 'fixed_price_min' = ANY(COALESCE(p_clear_fields, '{}')) THEN NULL
    ELSE v_sp.fixed_price_min END;
  v_new_max := CASE
    WHEN p_fixed_price_max IS NOT NULL THEN p_fixed_price_max
    WHEN 'fixed_price_max' = ANY(COALESCE(p_clear_fields, '{}')) THEN NULL
    ELSE v_sp.fixed_price_max END;

  -- Validate the resolved triple as it will be stored.
  PERFORM public._assert_valid_provider_pricing(v_new_hourly, v_new_min, v_new_max);

  -- Same scope rule as the "Admins can manage providers" table policy:
  -- owner everything, country-level everything, region admins only inside
  -- their assigned scope, NULL region = owner/country only.
  v_region := public._point_region_id(v_sp.latitude, v_sp.longitude);
  IF NOT public._admin_write_scope(v_region) THEN
    RAISE EXCEPTION 'outside_region_scope';
  END IF;

  -- The pricing trigger validates and writes the audit row; the note
  -- travels through a transaction-local setting so there is exactly one
  -- audit entry per change, whoever wrote it.
  PERFORM set_config('app.pricing_note', COALESCE(v_note, ''), true);

  UPDATE public.service_providers
     SET hourly_rate = v_new_hourly,
         fixed_price_min = v_new_min,
         fixed_price_max = v_new_max,
         updated_at = now()
   WHERE id = p_provider_id;

  PERFORM set_config('app.pricing_note', '', true);

  RETURN jsonb_build_object(
    'success', true,
    'provider_id', p_provider_id,
    'hourly_rate', v_new_hourly,
    'fixed_price_min', v_new_min,
    'fixed_price_max', v_new_max,
    'pricing', public.service_provider_effective_pricing(p_provider_id)
  );
END;
$function$;

-- ---------- 3. upsert a category default ----------
CREATE OR REPLACE FUNCTION public.admin_set_category_pricing(
  p_category_type text,
  p_hourly_rate numeric DEFAULT NULL::numeric,
  p_fixed_price_min numeric DEFAULT NULL::numeric,
  p_fixed_price_max numeric DEFAULT NULL::numeric,
  p_note text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cat text;
  v_old public.service_category_pricing%ROWTYPE;
BEGIN
  -- Category defaults are platform-wide: owner / country-level only.
  IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;

  PERFORM public._assert_valid_provider_pricing(
    p_hourly_rate, p_fixed_price_min, p_fixed_price_max);

  SELECT c.type INTO v_cat
    FROM public.service_categories c
   WHERE lower(c.type) = lower(btrim(COALESCE(p_category_type, '')))
     AND c.is_active
   LIMIT 1;
  IF v_cat IS NULL THEN
    RAISE EXCEPTION 'invalid_category';
  END IF;

  -- Lock the row so a concurrent edit logs the true old value. The one
  -- uncovered race is two first-time inserts of the same category; the
  -- loser then logs an empty old row.
  SELECT * INTO v_old
    FROM public.service_category_pricing
   WHERE category_type = v_cat
   FOR UPDATE;

  INSERT INTO public.service_category_pricing AS cp (
    category_type, hourly_rate, fixed_price_min, fixed_price_max,
    currency, updated_by, updated_at
  )
  VALUES (
    v_cat, p_hourly_rate, p_fixed_price_min, p_fixed_price_max,
    'EGP', auth.uid(), now()
  )
  ON CONFLICT (category_type) DO UPDATE
    SET hourly_rate = EXCLUDED.hourly_rate,
        fixed_price_min = EXCLUDED.fixed_price_min,
        fixed_price_max = EXCLUDED.fixed_price_max,
        updated_by = EXCLUDED.updated_by,
        updated_at = EXCLUDED.updated_at;

  PERFORM public.write_audit(
    'CATEGORY_PRICING_CHANGED', 'service_category_pricing', v_cat,
    jsonb_build_object(
      'old', jsonb_build_object(
        'hourly_rate', v_old.hourly_rate,
        'fixed_price_min', v_old.fixed_price_min,
        'fixed_price_max', v_old.fixed_price_max),
      'new', jsonb_build_object(
        'hourly_rate', p_hourly_rate,
        'fixed_price_min', p_fixed_price_min,
        'fixed_price_max', p_fixed_price_max),
      'note', NULLIF(btrim(COALESCE(p_note, '')), '')
    ));

  RETURN jsonb_build_object(
    'success', true,
    'category_type', v_cat,
    'hourly_rate', p_hourly_rate,
    'fixed_price_min', p_fixed_price_min,
    'fixed_price_max', p_fixed_price_max
  );
END;
$function$;

-- ---------- 4. scoped read paths for the admin editor ----------
CREATE OR REPLACE FUNCTION public.admin_list_provider_pricing(
  p_search text DEFAULT NULL::text,
  p_category_type text DEFAULT NULL::text,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_items jsonb;
  v_total bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_active_admin_uid(auth.uid()) THEN
    RETURN jsonb_build_object('items', '[]'::jsonb, 'total', 0);
  END IF;

  -- A region admin sees exactly the rows they could edit (same rule as the
  -- write RPC and the "Admins can manage providers" table policy).
  WITH scoped AS MATERIALIZED (
    SELECT sp.id, sp.name, sp.category_type, sp.is_verified, sp.city,
           sp.hourly_rate, sp.fixed_price_min, sp.fixed_price_max,
           sp.updated_at,
           public._point_region_id(sp.latitude, sp.longitude) AS region_id
      FROM public.service_providers sp
     WHERE (p_category_type IS NULL OR btrim(p_category_type) = ''
            OR lower(sp.category_type) = lower(btrim(p_category_type)))
       AND (p_search IS NULL OR btrim(p_search) = ''
            OR sp.name ILIKE '%' || btrim(p_search) || '%'
            OR COALESCE(sp.city, '') ILIKE '%' || btrim(p_search) || '%')
  ),
  visible AS (
    SELECT * FROM scoped s
     WHERE public._admin_write_scope(s.region_id)
  ),
  counted AS (
    SELECT count(*) AS n FROM visible
  ),
  items AS (
    SELECT jsonb_build_object(
             'provider_id', v.id,
             'name', v.name,
             'category_type', v.category_type,
             'category_name_ar', sc.name_ar,
             'category_name_en', sc.name_en,
             'is_verified', v.is_verified,
             'city', v.city,
             'region_label', public._region_label_path(v.region_id),
             'hourly_rate', v.hourly_rate,
             'fixed_price_min', v.fixed_price_min,
             'fixed_price_max', v.fixed_price_max,
             'category_hourly_rate', cp.hourly_rate,
             'category_fixed_price_min', cp.fixed_price_min,
             'category_fixed_price_max', cp.fixed_price_max,
             'effective_hourly_rate',
               (eff->>'hourly_rate')::numeric,
             'effective_fixed_price_min',
               (eff->>'fixed_price_min')::numeric,
             'effective_fixed_price_max',
               (eff->>'fixed_price_max')::numeric,
             'hourly_source', eff->>'hourly_source',
             'fixed_source', eff->>'fixed_source',
             'updated_at', v.updated_at
           ) AS item
      FROM visible v
      LEFT JOIN public.service_category_pricing cp
        ON lower(cp.category_type) = lower(v.category_type)
      LEFT JOIN public.service_categories sc
        ON sc.type = v.category_type
      CROSS JOIN LATERAL (SELECT public.service_provider_effective_pricing(v.id) AS eff) e
     ORDER BY lower(v.name)
     LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 200))
    OFFSET GREATEST(0, COALESCE(p_offset, 0))
  )
  SELECT counted.n, COALESCE((SELECT jsonb_agg(items.item) FROM items), '[]'::jsonb)
    INTO v_total, v_items
    FROM counted;

  RETURN jsonb_build_object('items', v_items, 'total', v_total);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_category_pricing()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_items jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_active_admin_uid(auth.uid()) THEN
    RETURN jsonb_build_object(
      'items', '[]'::jsonb,
      'can_edit', false,
      'platform_default_hourly_rate', 150);
  END IF;

  SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO v_items
    FROM (
      SELECT jsonb_build_object(
               'category_type', c.type,
               'name_ar', c.name_ar,
               'name_en', c.name_en,
               'hourly_rate', cp.hourly_rate,
               'fixed_price_min', cp.fixed_price_min,
               'fixed_price_max', cp.fixed_price_max,
               'currency', COALESCE(cp.currency, 'EGP'),
               'updated_at', cp.updated_at
             ) AS item
        FROM public.service_categories c
        LEFT JOIN public.service_category_pricing cp
          ON cp.category_type = c.type
       WHERE c.is_active
       ORDER BY c.name_ar
    ) s;

  RETURN jsonb_build_object(
    'items', v_items,
    'can_edit', public._is_country_admin_uid(auth.uid()),
    'platform_default_hourly_rate', 150);
END;
$function$;

-- ---------- 5. provider read-only self view ----------
CREATE OR REPLACE FUNCTION public.provider_get_my_pricing()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_items jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('items', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO v_items
    FROM (
      SELECT jsonb_build_object(
               'provider_id', sp.id,
               'name', sp.name,
               'category_type', sp.category_type,
               'category_name_ar', sc.name_ar,
               'category_name_en', sc.name_en,
               'hourly_rate', sp.hourly_rate,
               'fixed_price_min', sp.fixed_price_min,
               'fixed_price_max', sp.fixed_price_max,
               'category_hourly_rate', cp.hourly_rate,
               'category_fixed_price_min', cp.fixed_price_min,
               'category_fixed_price_max', cp.fixed_price_max,
               'effective_hourly_rate', (eff->>'hourly_rate')::numeric,
               'effective_fixed_price_min', (eff->>'fixed_price_min')::numeric,
               'effective_fixed_price_max', (eff->>'fixed_price_max')::numeric,
               'hourly_source', eff->>'hourly_source',
               'fixed_source', eff->>'fixed_source',
               'currency', COALESCE(cp.currency, 'EGP'),
               'admin_managed', true
             ) AS item
        FROM public.service_providers sp
        LEFT JOIN public.service_category_pricing cp
          ON lower(cp.category_type) = lower(sp.category_type)
        LEFT JOIN public.service_categories sc
          ON sc.type = sp.category_type
        CROSS JOIN LATERAL (SELECT public.service_provider_effective_pricing(sp.id) AS eff) e
       WHERE sp.user_id = v_uid
       ORDER BY sp.created_at
    ) s;

  RETURN jsonb_build_object(
    'items', v_items,
    'platform_default_hourly_rate', 150);
END;
$function$;

-- ---------- 7. booking estimate floor follows the same resolver ----------
CREATE OR REPLACE FUNCTION public.service_bookings_normalize_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_provider public.service_providers%rowtype;
  v_pricing jsonb;
  v_floor numeric;
begin
  -- Lifecycle and payment state are server-owned; a fresh booking is always
  -- a pending, unpaid request with no completion or collection markers.
  new.status := 'pending';
  new.completed_at := null;
  new.payment_status := 'unpaid';
  new.cash_collected_at := null;
  new.cash_collected_by := null;
  new.final_price := null;

  -- Provider truth comes from the provider row, never the client payload.
  select * into v_provider from public.service_providers where id = new.provider_id;
  if not found then
    raise exception 'PROVIDER_NOT_FOUND';
  end if;
  new.provider_name := v_provider.name;
  new.category_type := v_provider.category_type;

  -- 196: no zero/negative estimates; the provider floor still applies.
  if new.estimated_price is not null and new.estimated_price <= 0 then
    raise exception 'INVALID_PRICE';
  end if;
  -- 397: the floor is the RESOLVED fixed minimum (provider pair override,
  -- else category default), the same value every price read shows.
  v_pricing := public.service_provider_effective_pricing(new.provider_id);
  v_floor := (v_pricing->>'fixed_price_min')::numeric;
  if v_floor is not null
     and (new.estimated_price is null or new.estimated_price < v_floor) then
    new.estimated_price := v_floor;
  end if;

  return new;
end;
$function$;

-- ---------- 8. provisioning: NULL override so providers inherit live ----------
-- One-token delta (150 -> NULL): the category default and the 150 platform
-- fallback now resolve live through service_provider_effective_pricing, so
-- later category changes apply to providers without an override.
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
BEGIN
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
    SELECT id INTO v_sp_id
      FROM public.service_providers
     WHERE user_id = p_user_id
       AND lower(category_type) = CASE WHEN v_cat IN ('service', 'home_services', 'homeservices') THEN 'plumbing' ELSE v_cat END
     LIMIT 1;

    IF v_sp_id IS NULL THEN
      SELECT id INTO v_sp_id
        FROM public.service_providers
       WHERE user_id = p_user_id
       ORDER BY created_at ASC
       LIMIT 1;
    END IF;

    IF v_sp_id IS NULL THEN
      INSERT INTO public.service_providers (
        user_id, name, category_type, description, profile_image_url,
        rating, rating_count, is_verified, is_available, hourly_rate
      )
      VALUES (
        p_user_id,
        v_name,
        CASE WHEN v_cat IN ('service', 'home_services', 'homeservices') THEN 'plumbing' ELSE v_cat END,
        '',
        COALESCE(v_user.profile_photo_url, v_user.avatar_url),
        5.0,
        0,
        true,
        true,
        NULL -- override only; category default / 150 resolve live (397)
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

-- ---------- privileges ----------
REVOKE ALL ON FUNCTION public._assert_valid_provider_pricing(numeric, numeric, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._assert_valid_provider_pricing(numeric, numeric, numeric) FROM anon;
REVOKE ALL ON FUNCTION public._assert_valid_provider_pricing(numeric, numeric, numeric) FROM authenticated;

REVOKE ALL ON FUNCTION public.service_provider_effective_pricing(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.service_provider_effective_pricing(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.service_provider_effective_pricing(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_set_provider_pricing(uuid, numeric, numeric, numeric, text[], text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_provider_pricing(uuid, numeric, numeric, numeric, text[], text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_set_provider_pricing(uuid, numeric, numeric, numeric, text[], text) TO authenticated;
DROP FUNCTION IF EXISTS public.admin_set_provider_pricing(uuid, numeric, numeric, numeric, text);

REVOKE ALL ON FUNCTION public.admin_set_category_pricing(text, numeric, numeric, numeric, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_category_pricing(text, numeric, numeric, numeric, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_set_category_pricing(text, numeric, numeric, numeric, text) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_list_provider_pricing(text, text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_provider_pricing(text, text, integer, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_list_provider_pricing(text, text, integer, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_list_category_pricing() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_category_pricing() FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_list_category_pricing() TO authenticated;

REVOKE ALL ON FUNCTION public.provider_get_my_pricing() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.provider_get_my_pricing() FROM anon;
GRANT EXECUTE ON FUNCTION public.provider_get_my_pricing() TO authenticated;

COMMIT;
