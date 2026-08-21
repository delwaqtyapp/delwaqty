-- =============================================================
-- 032_egypt_geographic_schema.sql
-- Phase 2.1B — Egypt complete geographic coverage (ADR-057).
--
-- Part 1 (this file): schema, security, spatial RPC.
-- Part 2 (032_egypt_geographic_seed.sql): idempotent data seed.
--
--   regions                 EXISTING table, extended admin tree
--                            (markaz / district / city / village /
--                             new_city / area under governorates)
--   geo_places              significant named geographic entities
--                            (tourism, transport, landmarks — NEVER admin)
--   geo_aliases             normalized searchable names
--   geo_admin_boundaries    PostGIS polygons for spatial matching
--   geo_region_for_point()  server-side spatial RPC (016 pattern)
--
-- Approved decisions (ADR-057):
--   D1  OCHA HDX COD-AB authoritative load dataset + Wikipedia/NUCA new
--       cities + GeoNames/Wikipedia/OSM verified places.
--   D2  hybrid geocoder — server-side secure proxy; Photon/OSM + GeoNames
--       storable; Google online-only, never persisted.
--   D3  regions.type CHECK extended additively (no qism overload;
--       urban aqsam stored as 'district').
--
-- Security (mirrors 030/031):
--   * every new table: SELECT for anon + authenticated, admin-only write
--     via public.is_admin() (016 pattern), no anon writes.
--   * REVOKE-before-GRANT on every new table.
--   * geo_region_for_point() SECURITY DEFINER with SET search_path;
--     EXECUTE granted to authenticated only.
--   * 030/031 remain untouched. Governorate UUIDs immutable.
-- Idempotent: safe to re-run. Deterministic seed (ON CONFLICT DO NOTHING).
-- =============================================================

-- ─── 1. EXTENSIONS ──────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ─── 2. REGIONS — TYPE TAXONOMY EXTENSION (D3, ADR-057) ─────
-- Additive: adds markaz / village / new_city to the existing 030 CHECK
-- (country / governorate / city / district / area). Urban aqsam are stored
-- as 'district' (approved D3 option (a)). No existing row type changes.

ALTER TABLE public.regions DROP CONSTRAINT IF EXISTS regions_type_check;
ALTER TABLE public.regions
  ADD CONSTRAINT regions_type_check CHECK (
    type IN ('country','governorate','markaz','district','city',
             'village','new_city','area')
  );

-- parent+type composite (deepens is_admin_for_region recursive walk)
CREATE INDEX IF NOT EXISTS idx_regions_parent_type
  ON public.regions (parent_region_id, type);

-- trigram indexes for Arabic/English fuzzy name search
CREATE INDEX IF NOT EXISTS idx_regions_name_ar_trgm
  ON public.regions USING gin (name_ar gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_regions_name_en_trgm
  ON public.regions USING gin (name_en gin_trgm_ops);

-- ─── 3. GEO_PLACES ──────────────────────────────────────────
-- Significant named geographic entities only. NEVER an admin unit and
-- NEVER a business directory (ADR-057 �14 gate).
CREATE TABLE IF NOT EXISTS public.geo_places (
  id uuid PRIMARY KEY,
  type text NOT NULL CHECK (
    type IN ('hotel','resort','tourist_village','tourist_city','compound',
             'development','airport','port','university','hospital',
             'station','landmark','settlement','poi')
  ),
  region_id uuid REFERENCES public.regions(id) ON DELETE CASCADE,
  name_ar text,
  name_en text,
  latitude double precision CHECK (latitude BETWEEN -90 AND 90),
  longitude double precision CHECK (longitude BETWEEN -180 AND 180),
  point geometry(Point,4326),
  source text NOT NULL,
  source_ref text NOT NULL,
  source_date date,
  source_type text NOT NULL CHECK (
    source_type IN ('OFFICIAL VERIFIED','SECONDARY VERIFIED',
                    'PROVIDER-DERIVED','UNVERIFIED-MISSING')
  ),
  confidence text NOT NULL CHECK (
    confidence IN ('HIGH','MEDIUM','LOW','UNVERIFIED')
  ),
  provenance jsonb NOT NULL DEFAULT '{}'::jsonb,
  license text,
  is_active boolean NOT NULL DEFAULT TRUE,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT geo_places_point_matches CHECK (
    (latitude IS NULL AND longitude IS NULL AND point IS NULL)
    OR (
      latitude IS NOT NULL AND longitude IS NOT NULL
      AND point IS NOT NULL
    )
  ),
  CONSTRAINT geo_places_source_ref UNIQUE (source, source_ref)
);

DROP TRIGGER IF EXISTS geo_places_set_updated_at ON public.geo_places;
CREATE TRIGGER geo_places_set_updated_at
  BEFORE UPDATE ON public.geo_places
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_geo_places_region
  ON public.geo_places (region_id);
CREATE INDEX IF NOT EXISTS idx_geo_places_type
  ON public.geo_places (type) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_geo_places_point
  ON public.geo_places USING gist (point);
CREATE INDEX IF NOT EXISTS idx_geo_places_name_ar_trgm
  ON public.geo_places USING gin (name_ar gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_geo_places_name_en_trgm
  ON public.geo_places USING gin (name_en gin_trgm_ops);

-- ─── 4. GEO_ALIASES ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.geo_aliases (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_type text NOT NULL CHECK (entity_type IN ('region','place')),
  entity_id uuid NOT NULL,
  alias text NOT NULL,
  lang text,
  is_primary boolean NOT NULL DEFAULT FALSE,
  source text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT geo_aliases_unique UNIQUE (entity_type, entity_id, alias, lang)
);

CREATE INDEX IF NOT EXISTS idx_geo_aliases_entity
  ON public.geo_aliases (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_geo_aliases_alias_trgm
  ON public.geo_aliases USING gin (alias gin_trgm_ops);

-- ─── 5. GEO_ADMIN_BOUNDARIES ────────────────────────────────
-- PostGIS polygons (import-only data) for server-side point-in-polygon.
CREATE TABLE IF NOT EXISTS public.geo_admin_boundaries (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  region_id uuid NOT NULL REFERENCES public.regions(id) ON DELETE CASCADE,
  level integer NOT NULL CHECK (level BETWEEN 1 AND 4),
  geometry geometry(MultiPolygon,4326) NOT NULL,
  source text NOT NULL,
  source_ref text NOT NULL,
  license text,
  valid_from date,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT geo_admin_boundaries_unique
    UNIQUE (region_id, source, source_ref)
);

CREATE INDEX IF NOT EXISTS idx_geo_admin_boundaries_geom
  ON public.geo_admin_boundaries USING gist (geometry);
CREATE INDEX IF NOT EXISTS idx_geo_admin_boundaries_region
  ON public.geo_admin_boundaries (region_id, level);

-- ─── 6. RLS + POLICIES ──────────────────────────────────────
-- Read path: public reference data (anon + authenticated).
-- Write path: admin only via public.is_admin() (016 pattern).
ALTER TABLE public.geo_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geo_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geo_admin_boundaries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "geo_places select public" ON public.geo_places;
CREATE POLICY "geo_places select public" ON public.geo_places
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "geo_places admin write" ON public.geo_places;
CREATE POLICY "geo_places admin write" ON public.geo_places
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "geo_aliases select public" ON public.geo_aliases;
CREATE POLICY "geo_aliases select public" ON public.geo_aliases
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "geo_aliases admin write" ON public.geo_aliases;
CREATE POLICY "geo_aliases admin write" ON public.geo_aliases
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "geo_admin_boundaries select public"
  ON public.geo_admin_boundaries;
CREATE POLICY "geo_admin_boundaries select public"
  ON public.geo_admin_boundaries
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "geo_admin_boundaries admin write"
  ON public.geo_admin_boundaries;
CREATE POLICY "geo_admin_boundaries admin write"
  ON public.geo_admin_boundaries
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- REVOKE-before-GRANT discipline (030/031 lesson): never leave the
-- platform default ALL-on-new-table grants. anon never holds writes.
REVOKE ALL ON public.geo_places FROM anon, authenticated;
REVOKE ALL ON public.geo_aliases FROM anon, authenticated;
REVOKE ALL ON public.geo_admin_boundaries FROM anon, authenticated;
GRANT SELECT ON public.geo_places, public.geo_aliases,
               public.geo_admin_boundaries TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.geo_places, public.geo_aliases,
               public.geo_admin_boundaries TO authenticated;

-- ─── 7. SPATIAL RPC — geo_region_for_point ──────────────────
-- Server-side resolution of a GPS fix to the canonical region chain.
--   (1) point-in-polygon over geo_admin_boundaries (deepest match)
--   (2) nearest boundary within tolerance        -> MEDIUM (snapping)
--   (3) nearest governorate centroid fallback    -> LOW   (Option E)
--   (4) optional centroid refinement to village/area/city when a deeper
--       granularity is requested (p_max_depth >= 3) and within tolerance
-- Confidence gates let the client decide persistence (never overwrite
-- manual/verified preferences; LOW never auto-persists).
-- SECURITY DEFINER + SET search_path (016 pattern); no authz here.

CREATE OR REPLACE FUNCTION public.geo_region_for_point(
  p_lat double precision,
  p_lon double precision,
  p_max_depth integer DEFAULT 2,
  p_tolerance_m double precision DEFAULT 25000
)
RETURNS TABLE (
  region_id uuid,
  code text,
  name_ar text,
  name_en text,
  type text,
  parent_region_id uuid,
  governorate_id uuid,
  governorate_code text,
  governorate_name_ar text,
  governorate_name_en text,
  confidence text,
  distance_m double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pt geometry;
  v_region_id uuid;
  v_region_type text;
  v_conf text;
  v_dist double precision;
  v_child_id uuid;
  v_child_dist double precision;
  v_child_type text;
BEGIN
  IF p_lat IS NULL OR p_lon IS NULL
     OR p_lat < -90 OR p_lat > 90 OR p_lon < -180 OR p_lon > 180 THEN
    RETURN QUERY SELECT
      NULL::uuid, NULL::text, NULL::text, NULL::text, NULL::text,
      NULL::uuid, NULL::uuid, NULL::text, NULL::text, NULL::text,
      'INVALID', NULL::double precision;
    RETURN;
  END IF;

  v_pt := ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326);

  -- (1) point-in-polygon: deepest contained boundary
  SELECT b.region_id
    INTO v_region_id
    FROM public.geo_admin_boundaries b
   WHERE ST_Contains(b.geometry, v_pt)
   ORDER BY b.level DESC
   LIMIT 1;

  IF v_region_id IS NOT NULL THEN
    v_conf := 'HIGH';
    v_dist := 0;
  ELSE
    -- (2) nearest boundary within tolerance (GPS noise / snapping).
    -- geometry bbox prefilter in degrees (m/111320), exact order in meters.
    SELECT b.region_id,
           ST_Distance(b.geometry::geography, v_pt::geography)
      INTO v_region_id, v_dist
      FROM public.geo_admin_boundaries b
     WHERE ST_DWithin(b.geometry, v_pt, p_tolerance_m / 111320.0)
     ORDER BY ST_Distance(b.geometry::geography, v_pt::geography)
     LIMIT 1;
    IF v_region_id IS NOT NULL THEN
      v_conf := 'MEDIUM';
    ELSE
      -- (3) nearest governorate centroid fallback (Option E, LOW)
      SELECT b.region_id,
             ST_Distance(ST_PointOnSurface(b.geometry)::geography, v_pt::geography)
        INTO v_region_id, v_dist
        FROM public.geo_admin_boundaries b
       WHERE b.level = 1
       ORDER BY ST_Distance(ST_PointOnSurface(b.geometry)::geography, v_pt::geography)
       LIMIT 1;
      v_conf := 'LOW';
    END IF;
  END IF;

  IF v_region_id IS NULL THEN
    RETURN QUERY SELECT
      NULL::uuid, NULL::text, NULL::text, NULL::text, NULL::text,
      NULL::uuid, NULL::uuid, NULL::text, NULL::text, NULL::text,
      'UNVERIFIED', NULL::double precision;
    RETURN;
  END IF;

  SELECT r.type INTO v_region_type
    FROM public.regions r
   WHERE r.id = v_region_id;

  -- (4) centroid refinement to child granularity (optional, HIGH/MEDIUM only)
  IF p_max_depth >= 3
     AND v_conf IN ('HIGH','MEDIUM')
     AND v_region_type IN ('governorate','markaz','district','new_city') THEN
    SELECT r.id, r.type,
           ST_Distance(
             ST_SetSRID(
               ST_MakePoint(
                 (r.metadata->>'lon')::double precision,
                 (r.metadata->>'lat')::double precision), 4326)::geography,
             v_pt::geography)
      INTO v_child_id, v_child_type, v_child_dist
      FROM public.regions r
     WHERE r.parent_region_id = v_region_id
       AND r.type IN ('markaz','district','city','village','new_city','area')
       AND r.metadata->>'lat' IS NOT NULL
       AND r.metadata->>'lon' IS NOT NULL
     ORDER BY ST_Distance(
       ST_SetSRID(
         ST_MakePoint(
           (r.metadata->>'lon')::double precision,
           (r.metadata->>'lat')::double precision), 4326)::geography,
       v_pt::geography)
     LIMIT 1;

    IF v_child_id IS NOT NULL
       AND v_child_dist IS NOT NULL
       AND v_child_dist <= p_tolerance_m THEN
      v_region_id := v_child_id;
      v_region_type := v_child_type;
      v_dist := v_child_dist;
    END IF;
  END IF;

  -- (5) matched region + governorate ancestor
  RETURN QUERY
  WITH RECURSIVE chain AS (
    SELECT r.id, r.parent_region_id, r.code, r.type, r.name_ar, r.name_en,
           1 AS depth
      FROM public.regions r
     WHERE r.id = v_region_id
    UNION ALL
    SELECT r.id, r.parent_region_id, r.code, r.type, r.name_ar, r.name_en,
           c.depth + 1
      FROM public.regions r
      JOIN chain c ON r.id = c.parent_region_id
     WHERE c.depth < 10
  ),
  gov AS (
    SELECT ch.id, ch.code, ch.name_ar, ch.name_en FROM chain ch
     WHERE ch.type = 'governorate' LIMIT 1
  ),
  country AS (
    SELECT ch.id, ch.code, ch.name_ar, ch.name_en FROM chain ch
     WHERE ch.type = 'country' LIMIT 1
  )
  SELECT ch.id, ch.code, ch.name_ar, ch.name_en, ch.type, ch.parent_region_id,
         COALESCE((SELECT g.id FROM gov g), (SELECT c0.id FROM country c0)),
         COALESCE((SELECT g.code FROM gov g), (SELECT c0.code FROM country c0)),
         COALESCE((SELECT g.name_ar FROM gov g), (SELECT c0.name_ar FROM country c0)),
         COALESCE((SELECT g.name_en FROM gov g), (SELECT c0.name_en FROM country c0)),
         v_conf, v_dist
    FROM chain ch
   WHERE ch.depth = 1;
END;
$$;

REVOKE ALL ON FUNCTION public.geo_region_for_point(
  double precision, double precision, integer, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.geo_region_for_point(
  double precision, double precision, integer, double precision)
  TO authenticated;

-- ─── 8. EXECUTE LOCKDOWN (audit finding 2.1B-F2) ──────────────
-- Supabase ALTER DEFAULT PRIVILEGES auto-grants EXECUTE to anon/
-- authenticated/service_role at function creation. REVOKE ... FROM PUBLIC
-- above alone does NOT remove the anon grant, so the anon EXECUTE right is
-- revoked explicitly here. Read-only RPCs remain callable by authenticated;
-- anon holds nothing on these functions. (is_admin()/is_admin_for_region()
-- are defined in 016/031; their anon EXECUTE is revoked here.)
REVOKE ALL ON FUNCTION public.geo_region_for_point(
  double precision, double precision, integer, double precision) FROM anon;
REVOKE ALL ON FUNCTION public.is_admin() FROM anon;
REVOKE ALL ON FUNCTION public.is_admin(uid uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_admin_for_region(uuid) FROM anon;
