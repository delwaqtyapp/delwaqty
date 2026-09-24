-- ─────────────────────────────────────────────────────────────
-- 088: platform_settings INSERT/DELETE policies for admins
-- Root cause: the admin Settings page saves via `.upsert()`
-- (INSERT ... ON CONFLICT DO UPDATE) but platform_settings only
-- had SELECT + UPDATE policies, so the INSERT step was blocked
-- by RLS → "فشل" (settingsFailed) on every save.
-- Lock to admins only: SELECT is already public-read,
-- writing stays behind public.is_admin().
-- ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "platform_settings admin insert" ON public.platform_settings;
CREATE POLICY "platform_settings admin insert" ON public.platform_settings
  FOR INSERT WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "platform_settings admin delete" ON public.platform_settings;
CREATE POLICY "platform_settings admin delete" ON public.platform_settings
  FOR DELETE USING (public.is_admin());