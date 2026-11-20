-- =============================================================
-- 125_admin_region_builder.sql
-- Admin Region Builder (Governorate -> Markaz/District -> City/Village/Ezba/Naga)
-- with GPS coordinates & PostGIS boundary polygon + button-based assignment.
-- =============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_upsert_region(
  p_id uuid DEFAULT NULL,
  p_parent_region_id uuid DEFAULT NULL,
  p_type text DEFAULT 'village',
  p_name_ar text DEFAULT '',
  p_name_en text DEFAULT NULL,
  p_lat double precision DEFAULT NULL,
  p_lon double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT 3.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_code text;
  v_level integer;
  v_radius_m double precision;
  v_meta jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  IF p_type NOT IN (
    'governorate', 'markaz', 'district', 'city', 'village', 'new_city', 'area'
  ) THEN
    RAISE EXCEPTION 'INVALID_REGION_TYPE';
  END IF;

  IF btrim(COALESCE(p_name_ar, '')) = '' THEN
    RAISE EXCEPTION 'NAME_AR_REQUIRED';
  END IF;

  v_radius_m := LEAST(GREATEST(COALESCE(p_radius_km, 3.0), 0.3), 50.0) * 1000.0;
  v_meta := jsonb_strip_nulls(jsonb_build_object(
    'lat', p_lat,
    'lon', p_lon,
    'radius_km', COALESCE(p_radius_km, 3.0),
    'source', 'admin_curated'
  ));

  IF p_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.regions WHERE id = p_id) THEN
    v_id := p_id;
    UPDATE public.regions
       SET parent_region_id = COALESCE(p_parent_region_id, parent_region_id),
           type = p_type,
           name_ar = btrim(p_name_ar),
           name_en = NULLIF(btrim(COALESCE(p_name_en, '')), ''),
           metadata = COALESCE(metadata, '{}'::jsonb) || v_meta,
           updated_at = now()
     WHERE id = v_id;
  ELSE
    v_id := COALESCE(p_id, gen_random_uuid());
    v_code := 'EG-CUSTOM-' || substr(replace(v_id::text, '-', ''), 1, 8);
    INSERT INTO public.regions (
      id, code, parent_region_id, country_code, type,
      name_ar, name_en, is_active, metadata
    ) VALUES (
      v_id,
      v_code,
      p_parent_region_id,
      'EG',
      p_type,
      btrim(p_name_ar),
      NULLIF(btrim(COALESCE(p_name_en, '')), ''),
      true,
      v_meta
    );
  END IF;

  IF p_lat IS NOT NULL AND p_lon IS NOT NULL THEN
    v_level := CASE p_type
      WHEN 'governorate' THEN 1
      WHEN 'markaz' THEN 2
      WHEN 'district' THEN 2
      WHEN 'city' THEN 3
      WHEN 'new_city' THEN 3
      WHEN 'village' THEN 3
      ELSE 4
    END;

    INSERT INTO public.geo_admin_boundaries (
      region_id, level, geometry, source, source_ref
    ) VALUES (
      v_id,
      v_level,
      ST_Multi(
        ST_Buffer(
          ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326)::geography,
          v_radius_m
        )::geometry
      ),
      'admin_curated',
      v_id::text
    )
    ON CONFLICT (region_id, source, source_ref) DO UPDATE
      SET level = EXCLUDED.level,
          geometry = EXCLUDED.geometry;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_region(uuid, uuid, text, text, text, double precision, double precision, double precision) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_region(uuid, uuid, text, text, text, double precision, double precision, double precision) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_region(uuid, uuid, text, text, text, double precision, double precision, double precision) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_assign_region_by_id(
  p_email text,
  p_region_id uuid,
  p_scope text DEFAULT 'descendants'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_id uuid;
  v_region_name text;
BEGIN
  IF NOT (public.is_admin() OR public._is_owner_uid(auth.uid())) THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  IF p_scope NOT IN ('self', 'descendants') THEN
    RAISE EXCEPTION 'INVALID_SCOPE';
  END IF;

  SELECT id INTO v_admin_id
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email))
   LIMIT 1;

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'ADMIN_NOT_FOUND';
  END IF;

  SELECT COALESCE(name_ar, name_en) INTO v_region_name
    FROM public.regions
   WHERE id = p_region_id;

  IF v_region_name IS NULL THEN
    RAISE EXCEPTION 'REGION_NOT_FOUND';
  END IF;

  INSERT INTO public.admin_region_assignments (
    admin_id, region_id, scope, assigned_by
  ) VALUES (
    v_admin_id, p_region_id, p_scope, auth.uid()
  )
  ON CONFLICT (admin_id, region_id) DO UPDATE
    SET scope = EXCLUDED.scope,
        assigned_by = EXCLUDED.assigned_by;

  UPDATE public.admin_users
     SET region_id = p_region_id,
         region_name = v_region_name,
         updated_at = now()
   WHERE user_id = v_admin_id OR lower(email) = lower(btrim(p_email));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
