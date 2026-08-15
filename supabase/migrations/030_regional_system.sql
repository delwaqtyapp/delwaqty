-- =============================================================
-- 030_regional_system.sql
-- Phase 2.1 — Canonical Egypt region model (ADR-050).
--
--   regions                  country → governorate → city/district → area
--   user_region_preferences  per-user region state (detected / manual / verified)
--
-- Supabase is the canonical region source of truth. The app never ships a
-- production region database; Flutter consumes canonical region ids only.
--
-- Seeded now (authoritative public data, ISO 3166-2:EG):
--   * Egypt (country root)
--   * all 27 Egyptian governorates (stable deterministic UUIDs + ISO codes)
-- City / district / area data is deliberately NOT fabricated here; it must be
-- added later from a verified source.
--
-- Security:
--   * regions: SELECT for anon + authenticated (public reference data);
--     INSERT/UPDATE/DELETE admin-only via public.is_admin() (016 pattern).
--   * user_region_preferences: owner rw (RLS), admin select.
--   * No SECURITY DEFINER RPCs in this migration (Phase 2.1 needs none).
--   * Supabase platform default privileges grant ALL on new tables to
--     anon/authenticated; this migration revokes that surface and re-grants
--     only the approved model above (anon never holds write privileges).
-- Idempotent: safe to re-run. Deterministic seed (ON CONFLICT (id) DO NOTHING).
-- =============================================================

-- ─── 1. REGIONS ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.regions (
  id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  parent_region_id UUID REFERENCES public.regions(id) ON DELETE CASCADE,
  country_code TEXT NOT NULL DEFAULT 'EG',
  type TEXT NOT NULL CHECK (type IN ('country','governorate','city','district','area')),
  name_ar TEXT NOT NULL,
  name_en TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_regions_parent
  ON public.regions (parent_region_id);
CREATE INDEX IF NOT EXISTS idx_regions_type_active
  ON public.regions (type, is_active);
CREATE INDEX IF NOT EXISTS idx_regions_name_ar
  ON public.regions (name_ar);
CREATE INDEX IF NOT EXISTS idx_regions_name_en
  ON public.regions (name_en);

DROP TRIGGER IF EXISTS regions_set_updated_at ON public.regions;
CREATE TRIGGER regions_set_updated_at
  BEFORE UPDATE ON public.regions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "regions select public" ON public.regions;
CREATE POLICY "regions select public" ON public.regions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "regions admin write" ON public.regions;
CREATE POLICY "regions admin write" ON public.regions
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

REVOKE ALL ON public.regions FROM anon, authenticated;
REVOKE ALL ON public.user_region_preferences FROM anon, authenticated;
GRANT SELECT ON public.regions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.regions TO authenticated;

-- ─── 2. SEED — Egypt + 27 governorates (ISO 3166-2:EG) ─────
-- One row per line (machine-parseable for the dataset test).

INSERT INTO public.regions
  (id, code, parent_region_id, country_code, type, name_ar, name_en, is_active, metadata)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'EG', NULL, 'EG', 'country', 'مصر', 'Egypt', TRUE, '{"iso3166_2":"EG"}'::jsonb),
  ('00000000-0000-0000-0000-000000000101', 'EG-ALX', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الإسكندرية', 'Alexandria', TRUE, '{"iso3166_2":"EG-ALX","aliases":["Al Iskandariyah","Al-Iskandariyah"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000102', 'EG-ASN', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'أسوان', 'Aswan', TRUE, '{"iso3166_2":"EG-ASN","aliases":["Assuan"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000103', 'EG-AST', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'أسيوط', 'Asyut', TRUE, '{"iso3166_2":"EG-AST","aliases":["Assiut","Asyut Governorate"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000104', 'EG-BA', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'البحر الأحمر', 'Red Sea', TRUE, '{"iso3166_2":"EG-BA","aliases":["Al Bahr al Ahmar","El Bahr El Ahmar"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000105', 'EG-BH', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'البحيرة', 'Beheira', TRUE, '{"iso3166_2":"EG-BH","aliases":["Al Buhayrah","El Beheira"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000106', 'EG-BNS', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'بني سويف', 'Beni Suef', TRUE, '{"iso3166_2":"EG-BNS","aliases":["Bani Suwayf","Bani Suef"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000107', 'EG-C', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'القاهرة', 'Cairo', TRUE, '{"iso3166_2":"EG-C","aliases":["Al Qahirah","El Qahira"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000108', 'EG-DK', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الدقهلية', 'Dakahlia', TRUE, '{"iso3166_2":"EG-DK","aliases":["Ad Daqahliyah","El Dakahlia"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000109', 'EG-DT', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'دمياط', 'Damietta', TRUE, '{"iso3166_2":"EG-DT","aliases":["Dumyat","Damietta Governorate"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000110', 'EG-FYM', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الفيوم', 'Faiyum', TRUE, '{"iso3166_2":"EG-FYM","aliases":["Al Fayyum","Fayoum","El Fayoum"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000111', 'EG-GH', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الغربية', 'Gharbia', TRUE, '{"iso3166_2":"EG-GH","aliases":["Al Gharbiyah","El Gharbia"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000112', 'EG-GZ', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الجيزة', 'Giza', TRUE, '{"iso3166_2":"EG-GZ","aliases":["Al Jizah","El Giza"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000113', 'EG-IS', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الإسماعيلية', 'Ismailia', TRUE, '{"iso3166_2":"EG-IS","aliases":["Al Ismailiyah","El Ismailia"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000114', 'EG-JS', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'جنوب سيناء', 'South Sinai', TRUE, '{"iso3166_2":"EG-JS","aliases":["Janub Sina","Janub Sina"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000115', 'EG-KB', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'القليوبية', 'Qalyubia', TRUE, '{"iso3166_2":"EG-KB","aliases":["Al Qalyubiyah","El Qalyubia","Kalyoubia"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000116', 'EG-KFS', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'كفر الشيخ', 'Kafr el Sheikh', TRUE, '{"iso3166_2":"EG-KFS","aliases":["Kafr Ash Shaykh","Kafr El-Sheikh"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000117', 'EG-KN', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'قنا', 'Qena', TRUE, '{"iso3166_2":"EG-KN","aliases":["Qina"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000118', 'EG-LX', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الأقصر', 'Luxor', TRUE, '{"iso3166_2":"EG-LX","aliases":["Al Uqsur","El Uqsur"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000119', 'EG-MN', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'المنيا', 'Minya', TRUE, '{"iso3166_2":"EG-MN","aliases":["Al Minya","El Minya"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000120', 'EG-MNF', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'المنوفية', 'Monufia', TRUE, '{"iso3166_2":"EG-MNF","aliases":["Al Minufiyah","El Monufia","Menoufia"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000121', 'EG-MT', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'مطروح', 'Matrouh', TRUE, '{"iso3166_2":"EG-MT","aliases":["Matruh"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000122', 'EG-PTS', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'بورسعيد', 'Port Said', TRUE, '{"iso3166_2":"EG-PTS","aliases":["Bur Said","Port Said Governorate"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000123', 'EG-SHG', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'سوهاج', 'Sohag', TRUE, '{"iso3166_2":"EG-SHG","aliases":["Suhaj"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000124', 'EG-SHR', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الشرقية', 'Sharqia', TRUE, '{"iso3166_2":"EG-SHR","aliases":["Ash Sharqiyah","El Sharqia","Sharkia"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000125', 'EG-SIN', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'شمال سيناء', 'North Sinai', TRUE, '{"iso3166_2":"EG-SIN","aliases":["Shamal Sina","Shamal Sina"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000126', 'EG-SUZ', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'السويس', 'Suez', TRUE, '{"iso3166_2":"EG-SUZ","aliases":["As Suways","El Suez"]}'::jsonb),
  ('00000000-0000-0000-0000-000000000127', 'EG-WAD', '00000000-0000-0000-0000-000000000001', 'EG', 'governorate', 'الوادي الجديد', 'New Valley', TRUE, '{"iso3166_2":"EG-WAD","aliases":["Al Wadi al Jadid","El Wadi El Gadid","Wadi El Gedid"]}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- ─── 3. USER REGION PREFERENCES ────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_region_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  region_id UUID NOT NULL REFERENCES public.regions(id) ON DELETE CASCADE,
  source TEXT NOT NULL CHECK (source IN ('detected','manual','verified')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS user_region_preferences_set_updated_at
  ON public.user_region_preferences;
CREATE TRIGGER user_region_preferences_set_updated_at
  BEFORE UPDATE ON public.user_region_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.user_region_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_region_preferences owner rw"
  ON public.user_region_preferences;
CREATE POLICY "user_region_preferences owner rw"
  ON public.user_region_preferences
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_region_preferences admin select"
  ON public.user_region_preferences;
CREATE POLICY "user_region_preferences admin select"
  ON public.user_region_preferences
  FOR SELECT USING (public.is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.user_region_preferences TO authenticated;
