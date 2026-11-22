-- 363 (sweep stage 2 opener, lab 362 retest):
-- - Drop older spaced-name admin SELECT policies that OR around the scoped
--   362 policies on service_audio_logs and user_region_preferences.
-- - drivers admin SELECT scoped via _admin_member_scope (was any active
--   admin could read every driver profile, including NULL-region members).

DROP POLICY IF EXISTS "service_audio_logs admin select" ON public.service_audio_logs;
DROP POLICY IF EXISTS "user_region_preferences admin select" ON public.user_region_preferences;

DROP POLICY IF EXISTS "Admins can view all drivers" ON public.drivers;
CREATE POLICY "Admins can view all drivers" ON public.drivers FOR SELECT TO authenticated
  USING (public._admin_member_scope(user_id));
