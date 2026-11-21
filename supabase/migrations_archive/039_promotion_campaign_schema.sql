-- ============================================================
-- 039_promotion_campaign_schema.sql
-- Phase 2 Promotion/Content/Campaign platform — migration 039
-- (owner O1�O6 approved; ADR-059; PHASE_2_PROMOTION_IMPLEMENTATION_PLAN.md �13)
--
-- Scope (core campaign domain — schema + RLS + validators ONLY):
--   1. campaigns             — the single promotion/content container
--      (regional_offers MERGE target, O1; campaign types incl. offer/promotion/
--      coupon/announcement/operational/emergency; commercial vs operational/
--      emergency via priority lane; server-enforced lifecycle; referential
--      benefit + frequency config; bilingual fields).
--   2. campaign_banners      — placements (home_carousel/home_hero/market_top/
--      campaign_detail), locale (ar/en), storage-path image references (no
--      binary in PostgreSQL), controlled CTA.
--   3. campaign_reviews      — immutable transition audit ledger.
--   4. campaign_cta_routes   — CTA route allowlist (reference data, seeded from
--      the FeatureRegistry route set).
--   5. campaign_seen         — frequency control (impressions per user/campaign).
--   6. validate helpers      — campaign_validate_priority / campaign_validate_cta /
--      campaign_validate_benefit / campaign_validate_target_roles (SECURITY
--      DEFINER, SET search_path, anon EXECUTE revoked).
--   7. campaigns_guard_status_change trigger — whitelist lifecycle transitions;
--      emergency types forced to critical.
--
-- Security posture (016 pattern; 030/031 lesson):
--   * REVOKE-before-GRANT on every new table. anon gets NOTHING on campaign
--     tables; authenticated gets SELECT only, and RLS restricts that SELECT to
--     admins (is_admin()). campaign_seen gets NO client grants at all.
--   * NO client SELECT on campaign content tables as a table grant — the feed
--     (get_active_campaigns, migration 041) is the only read path for
--     customers; unpublished content cannot leak via direct table access.
--   * Writes are RPC-only (migration 040 lifecycle/approval RPCs). No INSERT/
--     UPDATE/DELETE policies exist in this migration.
--   * Functions: SECURITY DEFINER + SET search_path = public, pg_temp;
--     REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon; GRANT EXECUTE to
--     authenticated + service_role.
--   * Campaign tables are NOT added to supabase_realtime (fetch + TTL cache;
--     realtime only for emergency/operational via notifications, 041/042).
--
-- Idempotent: safe to re-run. Additive. Non-destructive. No data seeds for
-- campaigns (O6: no auto-published seeds). No lifecycle/approval RPCs here
-- (they need approval_requests → migration 040). No feed RPC (migration 041).
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─── 1. campaigns ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.campaigns (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code            text NOT NULL UNIQUE,
  campaign_type   text NOT NULL CHECK (campaign_type IN (
                    'offer','promotion','coupon',
                    'product_promotion','service_promotion',
                    'announcement','informational',
                    'service_announcement','outage','important_notice',
                    'emergency_notice','safety_notice'
                  )),
  priority        text NOT NULL DEFAULT 'normal'
                  CHECK (priority IN ('normal','important','critical')),
  name_ar         text NOT NULL,
  name_en         text,
  subtitle_ar     text,
  subtitle_en     text,
  description_ar  text,
  description_en  text,
  status          text NOT NULL DEFAULT 'draft' CHECK (status IN (
                    'draft','pending_review','approved','rejected','scheduled',
                    'published','paused','expired','archived','cancelled'
                  )),
  starts_at       timestamptz,
  ends_at         timestamptz,
  published_at    timestamptz,
  target_roles    text[] NOT NULL DEFAULT '{}',
  min_orders      integer,
  min_spend       numeric(12,2),
  benefit         jsonb NOT NULL DEFAULT '{"kind":"none"}'::jsonb,
  frequency       jsonb NOT NULL DEFAULT '{}'::jsonb,
  proposed_by     uuid REFERENCES public.users(id),
  reason          text,
  created_by      uuid REFERENCES public.users(id),
  updated_by      uuid REFERENCES public.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz,
  CONSTRAINT campaigns_window_order
    CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at),
  CONSTRAINT campaigns_emergency_critical
    CHECK (campaign_type NOT IN ('emergency_notice','safety_notice')
           OR priority = 'critical')
);

COMMENT ON TABLE public.campaigns IS
  'Promotion/content/campaign container (regional_offers MERGE, ADR-059). '
  'Writes via RPCs only; no client INSERT/UPDATE/DELETE policies.';

ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaigns admin select" ON public.campaigns;
CREATE POLICY "campaigns admin select" ON public.campaigns
  FOR SELECT USING (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_campaigns_status_priority
  ON public.campaigns (status, priority);
CREATE INDEX IF NOT EXISTS idx_campaigns_schedule
  ON public.campaigns (starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_campaigns_type
  ON public.campaigns (campaign_type);

DROP TRIGGER IF EXISTS campaigns_set_updated_at ON public.campaigns;
CREATE TRIGGER campaigns_set_updated_at
  BEFORE UPDATE ON public.campaigns
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ─── 2. campaign_banners ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.campaign_banners (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  placement   text NOT NULL CHECK (placement IN
                ('home_carousel','home_hero','market_top','campaign_detail')),
  locale      text NOT NULL CHECK (locale IN ('ar','en')),
  image_path  text NOT NULL,
  cta         jsonb NOT NULL DEFAULT '{"type":"none"}'::jsonb,
  priority    integer NOT NULL DEFAULT 100 CHECK (priority >= 0),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT campaign_banners_unique
    UNIQUE (campaign_id, placement, locale)
);

COMMENT ON TABLE public.campaign_banners IS
  'Per-placement/per-locale banner image references (storage paths only — '
  'no binary media in PostgreSQL; campaign-media bucket, migration 040).';

ALTER TABLE public.campaign_banners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaign_banners admin select" ON public.campaign_banners;
CREATE POLICY "campaign_banners admin select" ON public.campaign_banners
  FOR SELECT USING (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_campaign_banners_placement_active
  ON public.campaign_banners (placement, is_active);

DROP TRIGGER IF EXISTS campaign_banners_set_updated_at ON public.campaign_banners;
CREATE TRIGGER campaign_banners_set_updated_at
  BEFORE UPDATE ON public.campaign_banners
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ─── 3. campaign_reviews (immutable transition ledger) ────────

CREATE TABLE IF NOT EXISTS public.campaign_reviews (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id    uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  reviewer_id    uuid REFERENCES public.users(id),
  action         text NOT NULL CHECK (action IN
                   ('submit','approve','reject','publish','pause','resume',
                    'cancel','archive','expire')),
  reason         text,
  previous_state text NOT NULL,
  new_state      text NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.campaign_reviews IS
  'Immutable audit ledger of campaign lifecycle transitions. INSERT only via '
  'lifecycle RPCs (migration 040). No UPDATE/DELETE policies.';

ALTER TABLE public.campaign_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaign_reviews admin select" ON public.campaign_reviews;
CREATE POLICY "campaign_reviews admin select" ON public.campaign_reviews
  FOR SELECT USING (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_campaign_reviews_campaign
  ON public.campaign_reviews (campaign_id, created_at);

-- ─── 4. campaign_cta_routes (CTA allowlist reference data) ────

CREATE TABLE IF NOT EXISTS public.campaign_cta_routes (
  route       text PRIMARY KEY,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.campaign_cta_routes IS
  'Allowlist of internal go_router routes a campaign CTA may target. '
  'Seeded from the FeatureRegistry route set; validated at write and feed time. '
  'Public read (reference data).';

ALTER TABLE public.campaign_cta_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaign_cta_routes public select" ON public.campaign_cta_routes;
CREATE POLICY "campaign_cta_routes public select" ON public.campaign_cta_routes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "campaign_cta_routes admin manage" ON public.campaign_cta_routes;
CREATE POLICY "campaign_cta_routes admin manage" ON public.campaign_cta_routes
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Seed (idempotent) from the FeatureRegistry route set. Additive only.
INSERT INTO public.campaign_cta_routes (route, description)
SELECT x.route, x.description
FROM (VALUES
  ('/home', 'Home'),
  ('/search', 'Search'),
  ('/orders', 'Orders'),
  ('/profile', 'Profile'),
  ('/market', 'Market'),
  ('/market/cart', 'Cart'),
  ('/settings', 'Settings'),
  ('/settings/about', 'About'),
  ('/settings/help-center', 'Help center'),
  ('/settings/privacy-security', 'Privacy & security'),
  ('/settings/terms-of-service', 'Terms of service'),
  ('/settings/privacy-policy', 'Privacy policy'),
  ('/notifications', 'Notifications'),
  ('/wallet', 'Wallet'),
  ('/region-selection', 'Region selection'),
  ('/restaurant/:merchantId', 'Restaurant (merchant)'),
  ('/home-services', 'Home services'),
  ('/home-services/category/:categoryType', 'Home services category'),
  ('/support', 'Support chat'),
  ('/support/room/:roomId', 'Support chat room'),
  ('/my-complaints', 'My complaints'),
  ('/new-complaint', 'New complaint'),
  ('/safety', 'Safety'),
  ('/safety/contacts', 'Safety contacts'),
  ('/safety/settings', 'Safety settings'),
  ('/driver', 'Driver'),
  ('/driver/rides', 'Driver rides'),
  ('/driver/trip/:id', 'Driver trip'),
  ('/driver/earnings', 'Driver earnings'),
  ('/driver/vehicles', 'Driver vehicles'),
  ('/driver/documents', 'Driver documents'),
  ('/ride/book', 'Ride booking'),
  ('/ride/tracking/:id', 'Ride tracking'),
  ('/ride/history', 'Ride history'),
  ('/direct-delivery', 'Direct delivery'),
  ('/service-audio-logs', 'Service audio logs'),
  ('/merchant-dashboard', 'Merchant dashboard'),
  ('/admin', 'Admin'),
  ('/campaign/:id', 'Campaign detail (Phase 2 promotion)')
) AS x(route, description)
WHERE NOT EXISTS (SELECT 1 FROM public.campaign_cta_routes c WHERE c.route = x.route);

-- ─── 5. campaign_seen (frequency control) ─────────────────────

CREATE TABLE IF NOT EXISTS public.campaign_seen (
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  impressions  integer NOT NULL DEFAULT 1 CHECK (impressions >= 0),
  PRIMARY KEY (user_id, campaign_id)
);

COMMENT ON TABLE public.campaign_seen IS
  'Frequency control (impressions per user/campaign). Written by ingestion '
  'RPC (migration 040/042), read by the feed RPC (migration 041). No client '
  'grants. Minimal identity retention (user_id) for frequency + unique viewers.';

ALTER TABLE public.campaign_seen ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_campaign_seen_last_seen
  ON public.campaign_seen (last_seen_at);

-- ─── REVOKE-before-GRANT (030/031 lesson) ─────────────────────
-- anon gets nothing on the campaign tables; authenticated gets SELECT only
-- (RLS-gated to admins via is_admin()); campaign_seen gets nothing at all
-- (RPC/feed only). campaign_cta_routes is public reference data.

REVOKE ALL ON public.campaigns FROM anon, authenticated;
GRANT SELECT ON public.campaigns TO authenticated;

REVOKE ALL ON public.campaign_banners FROM anon, authenticated;
GRANT SELECT ON public.campaign_banners TO authenticated;

REVOKE ALL ON public.campaign_reviews FROM anon, authenticated;
GRANT SELECT ON public.campaign_reviews TO authenticated;

REVOKE ALL ON public.campaign_cta_routes FROM anon, authenticated;
GRANT SELECT ON public.campaign_cta_routes TO anon, authenticated;

REVOKE ALL ON public.campaign_seen FROM anon, authenticated;

-- ─── 6. validate helpers (016 pattern) ────────────────────────

-- Emergency/critical lane: emergency types MUST be critical.
CREATE OR REPLACE FUNCTION public.campaign_validate_priority(
  p_campaign_type text,
  p_priority text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p_campaign_type IN ('emergency_notice','safety_notice')
      THEN p_priority = 'critical'
    ELSE p_priority IN ('normal','important','critical')
  END;
$$;

-- CTA allowlist + payload validation (no javascript:/executable payloads).
CREATE OR REPLACE FUNCTION public.campaign_validate_cta(p_cta jsonb)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_type text;
  v_route text;
  v_entity_type text;
  v_entity_id text;
  v_url text;
  v_code text;
BEGIN
  IF p_cta IS NULL THEN
    RETURN true;
  END IF;
  v_type := p_cta ->> 'type';
  IF v_type IS NULL OR v_type NOT IN
       ('none','internal_route','entity','external_url','copy_code') THEN
    RETURN false;
  END IF;
  IF v_type = 'none' THEN
    RETURN true;
  END IF;
  v_route := p_cta ->> 'route';
  v_entity_type := p_cta ->> 'entity_type';
  v_entity_id := p_cta ->> 'entity_id';
  v_url := p_cta ->> 'url';
  v_code := p_cta ->> 'code';
  IF v_type = 'internal_route' THEN
    RETURN v_route IS NOT NULL
      AND EXISTS (SELECT 1 FROM public.campaign_cta_routes r
                  WHERE r.route = v_route);
  END IF;
  IF v_type = 'entity' THEN
    RETURN v_entity_type IN ('merchant','product','service','category','campaign')
      AND v_entity_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  END IF;
  IF v_type = 'external_url' THEN
    RETURN v_url IS NOT NULL
      AND (v_url ~* '^https?://[A-Za-z0-9._-]+')
      AND v_url !~* '(^|[^A-Za-z0-9])javascript:|(^|[^A-Za-z0-9])data:|(^|[^A-Za-z0-9])file:|vbscript:'
      AND v_url !~ '[[:space:]]';
  END IF;
  IF v_type = 'copy_code' THEN
    RETURN v_code IS NOT NULL
      AND v_code ~ '^[A-Za-z0-9_-]{1,64}$';
  END IF;
  RETURN false;
END;
$$;

-- Benefit referential validation. free_delivery requires the explicit
-- platform_settings.promotions->free_delivery_enabled flag (migration 042
-- adds the column; until then it is absent → not enabled → invalid). A banner
-- alone never creates a financial entitlement (O4).
CREATE OR REPLACE FUNCTION public.campaign_validate_benefit(p_benefit jsonb)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_kind text;
  v_code text;
  v_coupon_id uuid;
  v_promo_code_id uuid;
  v_offer_id uuid;
  v_free_delivery_enabled boolean;
BEGIN
  IF p_benefit IS NULL THEN
    RETURN true;
  END IF;
  v_kind := p_benefit ->> 'kind';
  IF v_kind IS NULL OR v_kind NOT IN
       ('none','coupon','promo_code','offer','code_copy','free_delivery') THEN
    RETURN false;
  END IF;
  IF v_kind = 'none' THEN
    RETURN true;
  END IF;
  IF v_kind = 'coupon' THEN
    BEGIN
      v_coupon_id := (p_benefit ->> 'coupon_id')::uuid;
    EXCEPTION WHEN others THEN
      RETURN false;
    END;
    RETURN EXISTS (SELECT 1 FROM public.coupons c WHERE c.id = v_coupon_id);
  END IF;
  IF v_kind = 'promo_code' THEN
    BEGIN
      v_promo_code_id := (p_benefit ->> 'promo_code_id')::uuid;
    EXCEPTION WHEN others THEN
      RETURN false;
    END;
    RETURN EXISTS (SELECT 1 FROM public.promo_codes p WHERE p.id = v_promo_code_id);
  END IF;
  IF v_kind = 'offer' THEN
    BEGIN
      v_offer_id := (p_benefit ->> 'offer_id')::uuid;
    EXCEPTION WHEN others THEN
      RETURN false;
    END;
    RETURN EXISTS (SELECT 1 FROM public.offers o WHERE o.id = v_offer_id);
  END IF;
  IF v_kind = 'code_copy' THEN
    v_code := p_benefit ->> 'code';
    RETURN v_code IS NOT NULL AND v_code ~ '^[A-Za-z0-9_-]{1,64}$';
  END IF;
  IF v_kind = 'free_delivery' THEN
    SELECT (to_jsonb(ps) #>> '{promotions,free_delivery_enabled}') = 'true'
      INTO v_free_delivery_enabled
      FROM public.platform_settings ps
      WHERE ps.id = 'default';
    RETURN COALESCE(v_free_delivery_enabled, false);
  END IF;
  RETURN false;
END;
$$;

-- Audience role validation against the canonical users.role vocabulary.
CREATE OR REPLACE FUNCTION public.campaign_validate_target_roles(p_roles text[])
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_roles IS NULL OR p_roles <@
         ARRAY['customer','merchant','driver','admin','owner','provider','delivery']::text[];
$$;

-- ─── 7. lifecycle guard (whitelist transitions) ───────────────

CREATE OR REPLACE FUNCTION public.campaigns_guard_status_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
      RAISE EXCEPTION 'Not authorized';
    END IF;
    IF NOT (OLD.status, NEW.status) IN (
      ('draft','pending_review'),('draft','cancelled'),('draft','archived'),
      ('pending_review','approved'),('pending_review','rejected'),
      ('pending_review','cancelled'),
      ('approved','scheduled'),('approved','published'),('approved','cancelled'),
      ('rejected','draft'),('rejected','archived'),
      ('scheduled','published'),('scheduled','cancelled'),
      ('published','paused'),('published','expired'),('published','archived'),
      ('paused','published'),('paused','archived'),
      ('expired','archived'),
      ('cancelled','draft'),('cancelled','archived')
    ) THEN
      RAISE EXCEPTION 'Invalid campaign status transition % -> %',
        OLD.status, NEW.status;
    END IF;
    IF NEW.status = 'published' AND NEW.published_at IS NULL THEN
      NEW.published_at := now();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS campaigns_guard_status_change ON public.campaigns;
CREATE TRIGGER campaigns_guard_status_change
  BEFORE UPDATE ON public.campaigns
  FOR EACH ROW
  EXECUTE FUNCTION public.campaigns_guard_status_change();

-- ─── 8. function ACLs (016 pattern) ───────────────────────────
-- Supabase default privileges auto-grant EXECUTE to anon/authenticated/
-- service_role on new functions. Revoke anon + PUBLIC explicitly; grant
-- authenticated + service_role.

REVOKE ALL ON FUNCTION public.campaign_validate_priority(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_validate_priority(text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_validate_priority(text, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_validate_cta(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_validate_cta(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_validate_cta(jsonb)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_validate_benefit(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_validate_benefit(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_validate_benefit(jsonb)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_validate_target_roles(text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_validate_target_roles(text[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_validate_target_roles(text[])
  TO authenticated, service_role;

COMMIT;
