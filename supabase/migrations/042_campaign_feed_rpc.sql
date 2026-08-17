-- ============================================================
-- 042 — Customer campaign feed RPC (DB-driven home carousel)
-- ============================================================
-- Nightly full-platform build, STEP 5: replaces the hardcoded Flutter
-- promo carousel with a database-driven feed.
--
-- _campaign_region_visible(p_campaign_id, p_member_region):
--   Checks if a campaign's targeting rows include the caller's region
--   (national NULL = visible to all; or a target region that is the
--   member's own region or any ancestor on the regions.parent_region_id
--   chain — a governorate campaign reaches villages/districts beneath it).
--
-- get_active_campaigns(p_locale):
--   Customer-facing only: returns NULL rows when auth.uid() is NULL.
--   Published + schedule-open, region-scoped via _campaign_region_visible.
--   Banner: best (lowest priority, newest) active 'home_carousel' banner
--   in the requested locale. image_path + cta are nullable — a campaign
--   without a banner still appears and the client renders a gradient slide.
--   Order: priority DESC, published_at DESC.
--
-- Idempotent / additive. SECURITY DEFINER + SET search_path = public, pg_temp.
-- ============================================================

BEGIN;

-- ─── 1. region eligibility helper ─────────────────────────────

CREATE OR REPLACE FUNCTION public._campaign_region_visible(
  p_campaign_id uuid,
  p_member_region uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.campaign_targets t
     WHERE t.campaign_id = p_campaign_id
       AND (
         t.region_id IS NULL
         OR t.region_id = p_member_region
         OR t.region_id IN (
           WITH RECURSIVE region_chain AS (
             SELECT p_member_region AS region_id
             UNION ALL
             SELECT r.parent_region_id
               FROM public.regions r
               JOIN region_chain rc ON r.id = rc.region_id
              WHERE r.parent_region_id IS NOT NULL
           )
           SELECT region_id FROM region_chain
         )
       )
  );
$$;

COMMENT ON FUNCTION public._campaign_region_visible(uuid, uuid) IS
  'Region eligibility for campaign feed (042). Returns true when the member '
  'region is NULL (no preference), or when the campaign has a national target '
  '(NULL region_id) or targets a region that is an ancestor of the member '
  'on the regions.parent_region_id hierarchy (max depth 5 in Egypt).';

REVOKE ALL ON FUNCTION public._campaign_region_visible(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._campaign_region_visible(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public._campaign_region_visible(uuid, uuid)
  TO authenticated, service_role;

-- ─── 2. feed RPC ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_active_campaigns(p_locale text DEFAULT 'ar')
RETURNS TABLE (
  id                 uuid,
  code               text,
  campaign_type      text,
  priority           text,
  status             text,
  name_ar            text,
  name_en            text,
  subtitle_ar        text,
  subtitle_en        text,
  description_ar     text,
  description_en     text,
  starts_at          timestamptz,
  ends_at            timestamptz,
  published_at       timestamptz,
  image_path         text,
  cta                jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_region uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  v_region := public._member_region_id(v_uid);

  RETURN QUERY
  SELECT c.id,
         c.code,
         c.campaign_type,
         c.priority,
         c.status,
         c.name_ar,
         c.name_en,
         c.subtitle_ar,
         c.subtitle_en,
         c.description_ar,
         c.description_en,
         c.starts_at,
         c.ends_at,
         c.published_at,
         b.image_path,
         b.cta
    FROM public.campaigns c
    LEFT JOIN LATERAL (
      SELECT cb.image_path, cb.cta
        FROM public.campaign_banners cb
       WHERE cb.campaign_id = c.id
         AND cb.placement = 'home_carousel'
         AND cb.is_active
         AND cb.locale = p_locale
       ORDER BY cb.priority ASC, cb.created_at DESC
       LIMIT 1
    ) b ON true
   WHERE c.status = 'published'
     AND c.archived_at IS NULL
     AND (c.starts_at IS NULL OR c.starts_at <= now())
     AND (c.ends_at IS NULL OR c.ends_at >= now())
     AND public._campaign_region_visible(c.id, v_region)
   ORDER BY c.priority DESC, c.published_at DESC NULLS LAST, c.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.get_active_campaigns(text) IS
  'Customer campaign feed for the DB-driven home carousel (migration 042). '
  'Published + schedule-open campaigns region-scoped to the caller. Returns '
  'empty for non-authenticated callers.';

REVOKE ALL ON FUNCTION public.get_active_campaigns(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_active_campaigns(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_active_campaigns(text)
  TO authenticated, service_role;

COMMIT;
