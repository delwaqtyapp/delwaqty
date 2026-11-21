-- ============================================================
-- 154_notification_and_evidence_lockdown.sql
--  1. notification_destinations (push routing config) had a
--     policy named "service role all" that actually said
--     USING(true) WITH CHECK(true): any client could rewrite
--     push routing. Dropped; service_role bypasses RLS.
--  2. notification_tokens had the same shape: any client could
--     read EVERY user's FCM token or delete them. Dropped; the
--     owner-scoped "Users can manage own tokens" policy and the
--     admin select policy remain.
--  3. service_audio_logs are dispute evidence, but the owner
--     policy allowed update/delete: a party could erase or
--     rewrite the recording record mid-dispute. Now select +
--     insert only.
-- ============================================================

DROP POLICY IF EXISTS "destinations service role all" ON public.notification_destinations;
DROP POLICY IF EXISTS "Service role manage tokens" ON public.notification_tokens;

DROP POLICY IF EXISTS "customer own logs rw" ON public.service_audio_logs;
CREATE POLICY "customer own logs read" ON public.service_audio_logs
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "customer own logs add" ON public.service_audio_logs
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- An authenticated-anyone read policy on the same routing table
-- (no app reads it) goes too.
DROP POLICY IF EXISTS "destinations authenticated read" ON public.notification_destinations;
