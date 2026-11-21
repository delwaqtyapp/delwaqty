-- 208: Security M1 - platform_settings was world-readable (SELECT true for
-- public), exposing settlement/financial policy knobs. Base table is now
-- authenticated-only; anonymous pre-login clients get a narrow curated view.

CREATE OR REPLACE VIEW public.app_public_config AS
SELECT id, app_name, support_email, support_phone, maintenance_mode,
       min_app_version_android, min_app_version_ios, require_provider_documents
FROM public.platform_settings;

REVOKE ALL ON public.app_public_config FROM public;
GRANT SELECT ON public.app_public_config TO anon, authenticated;

DROP POLICY "Settings viewable by everyone" ON public.platform_settings;
CREATE POLICY "Settings readable by signed-in users"
  ON public.platform_settings FOR SELECT TO authenticated USING (true);

NOTIFY pgrst, 'reload schema';
