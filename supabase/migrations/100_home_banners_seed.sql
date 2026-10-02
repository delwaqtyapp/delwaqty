-- ============================================================
-- 100_home_banners_seed.sql
-- Home ad banners: app-wide (Egypt) + governorate feed.
--
-- Problem (user report): the promo carousel slot between "main
-- categories" and "Discover near you" on the customer home is empty.
-- Two independent causes, both fixed here:
--   1. Guests (anon) can never see banners — get_active_campaigns (042)
--      bails when auth.uid() IS NULL AND anon was stripped of EXECUTE,
--      so the home silently fell back to an empty slot.
--   2. No banners exist — campaigns target nothing, so the region-scoped
--      feed returns zero rows for everyone.
--
-- Changes:
--   * get_active_campaigns rewritten: authenticated callers keep the exact
--     042 region scoping; guests (auth.uid() IS NULL) now get PUBLISHED,
--     schedule-open, NATIONAL campaigns only (region_id IS NULL target) —
--     app-wide public banners visible without login, nothing unpublished or
--     region-private leaks. EXECUTE granted to anon.
--   * Seed: 5 Egypt-wide banners (code BANNER_*) + 3 governorate banners
--     (Cairo / Giza / Alexandria). Published through the whitelisted
--     lifecycle (triggers force draft on INSERT, so: draft → pending_review
--     → approved → published). No banner images required — the client
--     renders a branded gradient slide when image_path is NULL (042 design).
--
-- Idempotent: inserts are ON CONFLICT (code) DO NOTHING; function is
-- CREATE OR REPLACE; GRANT is idempotent. Safe to re-run.
-- Admin note: applying via the SQL editor runs as postgres (no auth.uid()),
-- which is why the guarded transitions are used instead of the RPC chain.
-- ============================================================

BEGIN;

-- ─── 1. feed RPC: guests see national banners ─────────────---

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
  IF v_uid IS NOT NULL THEN
    v_region := public._member_region_id(v_uid);
  END IF;

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
     AND (
       -- authenticated: 042 region scoping unchanged
       (v_uid IS NOT NULL AND public._campaign_region_visible(c.id, v_region))
       OR
       -- guests (anon): national app-wide banners only
       (v_uid IS NULL AND EXISTS (
         SELECT 1
           FROM public.campaign_targets nt
          WHERE nt.campaign_id = c.id
            AND nt.region_id IS NULL
       ))
     )
   ORDER BY c.priority DESC, c.published_at DESC NULLS LAST, c.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.get_active_campaigns(text) IS
  'Customer campaign feed for the home carousel. Authenticated: region-scoped '
  'published campaigns (042). Guests (anon): national-only published banners. '
  'Amended in migration 100 to surface app-wide banners without login.';

REVOKE ALL ON FUNCTION public.get_active_campaigns(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_active_campaigns(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_active_campaigns(text)
  TO anon, authenticated, service_role;

-- ─── 2. seeds ───────────────────────────────────────────────--

-- 2a. Egypt-wide banners (visible to everyone, incl. guests). The three
-- governorate banners (2b) are region-targeted ONLY, so they demonstrate the
-- per-area feed on top of the app-wide set.
INSERT INTO public.campaigns (
  code, campaign_type, priority, name_ar, name_en,
  subtitle_ar, subtitle_en, description_ar, description_en,
  ends_at, target_roles, benefit, created_at, updated_at
) VALUES
  ('BANNER_WELCOME_20', 'promotion', 'important',
   'خصم 20% على أول طلب دليفرى', '20% off your first delivery order',
   'كوبون WELCOME20 لجميع الطلبات الجديدة', 'Use code WELCOME20 on any new order',
   'أهلًا بك في دليفرى! احصل على خصم 20% على أول طلب لك.', 'Welcome to DelwaQty — enjoy 20% off your first order.',
   now() + interval '90 days', '{}', '{"kind":"none"}'::jsonb, now(), now()),
  ('BANNER_FREE_DELIVERY', 'coupon', 'important',
   'توصيل مجاني لأول ٣ طلبات', 'Free delivery on your first 3 orders',
   'لجميع مناطق الدليفرى على مستوى مصر', 'Across all delivery zones in Egypt',
   'اطلب ٣ مرات واستمتع بتوصيل مجاني في كل مرة.', 'Order 3 times and get free delivery each time.',
   now() + interval '90 days', '{}', '{"kind":"none"}'::jsonb, now(), now()),
  ('BANNER_RESTAURANTS', 'offer', 'normal',
   'أشهر المطاعم بأسعار مخفضة', 'Top restaurants at lower prices',
   'عروض اليوم من أقرب المطاعم لك', 'Today offers from the restaurants nearest you',
   'تشكيلة مطاعم مميزة بعروض حصرية كل يوم.', 'A curated restaurant lineup with daily exclusive offers.',
   now() + interval '90 days', '{}', '{"kind":"none"}'::jsonb, now(), now()),
  ('BANNER_24H_WEEK', 'announcement', 'normal',
   'دليفرى على مدار الساعة', 'Delivery around the clock',
   'طلباتك توصلك في أي وقت وطوال الأسبوع', 'Get your orders any time, all week long',
   'خدمة الدليفرى متاحة ٢٤ ساعة طوال أيام الأسبوع.', 'Delivery service is available 24/7 all week.',
   NULL, '{}', '{"kind":"none"}'::jsonb, now(), now()),
  ('BANNER_MARKET', 'promotion', 'normal',
   'اللازم من الأسواق', 'Daily essentials from the market',
   'تسوق من أقرب الأسواق وأنت في مكانك', 'Shop from the nearest markets without leaving home',
   'طلبات السوبرماركت تصلك حتى باب بيتك بسرعة.', 'Supermarket orders delivered fast to your door.',
   now() + interval '90 days', '{}', '{"kind":"none"}'::jsonb, now(), now())
ON CONFLICT (code) DO NOTHING;

-- 2b. Governorate banners (Cairo / Giza / Alexandria) — stable ids from 030.
INSERT INTO public.campaigns (
  code, campaign_type, priority, name_ar, name_en,
  subtitle_ar, subtitle_en, description_ar, description_en,
  ends_at, target_roles, benefit, created_at, updated_at
) VALUES
  ('BANNER_CAIRO', 'offer', 'important',
   'عروض القاهرة', 'Cairo offers',
   'توصيل سريع لجميع مناطق القاهرة الكبرى', 'Fast delivery across Greater Cairo',
   'عروض خاصة لعملاء محافظة القاهرة.', 'Exclusive offers for Cairo customers.',
   now() + interval '60 days', '{}', '{"kind":"none"}'::jsonb, now(), now()),
  ('BANNER_GIZA', 'offer', 'important',
   'عروض الجيزة', 'Giza offers',
   'توصيل سريع لجميع مناطق الجيزة', 'Fast delivery across all Giza zones',
   'عروض خاصة لعملاء محافظة الجيزة.', 'Exclusive offers for Giza customers.',
   now() + interval '60 days', '{}', '{"kind":"none"}'::jsonb, now(), now()),
  ('BANNER_ALEX', 'offer', 'important',
   'عروض الإسكندرية', 'Alexandria offers',
   'توصيل سريع لجميع مناطق الإسكندرية', 'Fast delivery across all Alexandria zones',
   'عروض خاصة لعملاء محافظة الإسكندرية.', 'Exclusive offers for Alexandria customers.',
   now() + interval '60 days', '{}', '{"kind":"none"}'::jsonb, now(), now())
ON CONFLICT (code) DO NOTHING;

-- 2c. Targeting: national rows for ALL banners; plus governorate rows.
INSERT INTO public.campaign_targets (campaign_id, region_id, created_at)
SELECT c.id, NULL, now()
  FROM public.campaigns c
 WHERE c.code IN (
   'BANNER_WELCOME_20','BANNER_FREE_DELIVERY','BANNER_RESTAURANTS',
   'BANNER_24H_WEEK','BANNER_MARKET'
 )
   AND NOT EXISTS (
     SELECT 1 FROM public.campaign_targets t
      WHERE t.campaign_id = c.id AND t.region_id IS NULL
   );

INSERT INTO public.campaign_targets (campaign_id, region_id, created_at)
SELECT c.id, r.id, now()
  FROM public.campaigns c
  JOIN public.regions r
    ON (c.code = 'BANNER_CAIRO'  AND r.id = '00000000-0000-0000-0000-000000000107')
    OR (c.code = 'BANNER_GIZA'   AND r.id = '00000000-0000-0000-0000-000000000112')
    OR (c.code = 'BANNER_ALEX'   AND r.id = '00000000-0000-0000-0000-000000000101')
 WHERE NOT EXISTS (
   SELECT 1 FROM public.campaign_targets t
    WHERE t.campaign_id = c.id AND t.region_id = r.id
 );

-- 2d. Publish through the whitelisted lifecycle (draft → pending_review →
-- approved → published); the INSERT trigger forces draft, and the guard
-- trigger authorizes only these transitions.
UPDATE public.campaigns
   SET status = 'pending_review'
 WHERE code IN (
   'BANNER_WELCOME_20','BANNER_FREE_DELIVERY','BANNER_RESTAURANTS',
   'BANNER_24H_WEEK','BANNER_MARKET','BANNER_CAIRO','BANNER_GIZA','BANNER_ALEX'
 ) AND status = 'draft';

UPDATE public.campaigns
   SET status = 'approved'
 WHERE code IN (
   'BANNER_WELCOME_20','BANNER_FREE_DELIVERY','BANNER_RESTAURANTS',
   'BANNER_24H_WEEK','BANNER_MARKET','BANNER_CAIRO','BANNER_GIZA','BANNER_ALEX'
 ) AND status = 'pending_review';

UPDATE public.campaigns
   SET status = 'published'
 WHERE code IN (
   'BANNER_WELCOME_20','BANNER_FREE_DELIVERY','BANNER_RESTAURANTS',
   'BANNER_24H_WEEK','BANNER_MARKET','BANNER_CAIRO','BANNER_GIZA','BANNER_ALEX'
 ) AND status = 'approved';

COMMIT;