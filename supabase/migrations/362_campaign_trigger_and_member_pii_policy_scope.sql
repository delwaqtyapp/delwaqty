-- 362 (stage 1 of the bare-is_admin() policy sweep):
-- - campaigns_guard_status_change: lifecycle status changes now require an
--   owner/country-level admin, matching the 361 RPC gates (lab MEDIUM:
--   scoped village/center admins could archive campaigns via direct UPDATE).
-- - Member-PII table policies: bare is_admin() replaced with region-scoped
--   admin access via _admin_member_scope (owner/country/in-scope regional
--   admins only; NULL member region = owner/country only).

CREATE OR REPLACE FUNCTION public._admin_member_scope(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public._admin_write_scope(public._ops_scope_region(public._member_region_id(p_user_id)));
$function$;

GRANT EXECUTE ON FUNCTION public._admin_member_scope(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.campaigns_guard_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    -- Lifecycle transitions are owner/country-level only, matching the
    -- campaign_* RPC gates (361). Creators keep the submit/resubmit path.
    IF auth.uid() IS NOT NULL AND NOT public._is_country_admin_uid(auth.uid()) THEN
      IF NOT (
        OLD.created_by = auth.uid()
        AND OLD.status IN ('draft','rejected')
        AND NEW.status IN ('draft','pending_review')
        AND (
          EXISTS (SELECT 1 FROM public.merchants m WHERE m.owner_user_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.merchant_profiles mp WHERE mp.user_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.service_providers sp WHERE sp.user_id = auth.uid())
        )
      ) THEN
        RAISE EXCEPTION 'Not authorized';
      END IF;
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
$function$;

-- users
DROP POLICY IF EXISTS users_select_admin ON public.users;
CREATE POLICY users_select_admin ON public.users FOR SELECT TO authenticated
  USING (public._admin_member_scope(id));
DROP POLICY IF EXISTS users_update_admin ON public.users;
CREATE POLICY users_update_admin ON public.users FOR UPDATE TO authenticated
  USING (public._admin_member_scope(id))
  WITH CHECK (public._admin_member_scope(id));

-- location_updates
DROP POLICY IF EXISTS "admins select locations" ON public.location_updates;
CREATE POLICY "admins select locations" ON public.location_updates FOR SELECT TO authenticated
  USING (public._admin_member_scope(user_id));
DROP POLICY IF EXISTS "admins delete locations" ON public.location_updates;
CREATE POLICY "admins delete locations" ON public.location_updates FOR DELETE TO authenticated
  USING (public._admin_member_scope(user_id));

-- notification_tokens
DROP POLICY IF EXISTS "Admins select all tokens" ON public.notification_tokens;
CREATE POLICY "Admins select all tokens" ON public.notification_tokens FOR SELECT TO authenticated
  USING (public._admin_member_scope(user_id));

-- notifications
DROP POLICY IF EXISTS "Admins can select notifications" ON public.notifications;
CREATE POLICY "Admins can select notifications" ON public.notifications FOR SELECT TO authenticated
  USING (public._admin_member_scope(user_id));
DROP POLICY IF EXISTS "Admins can insert notifications" ON public.notifications;
CREATE POLICY "Admins can insert notifications" ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (public._admin_member_scope(user_id));
DROP POLICY IF EXISTS "Admins can delete notifications" ON public.notifications;
CREATE POLICY "Admins can delete notifications" ON public.notifications FOR DELETE TO authenticated
  USING (public._admin_member_scope(user_id));

-- chat_rooms (region_id on the room)
DROP POLICY IF EXISTS "admins select rooms" ON public.chat_rooms;
CREATE POLICY "admins select rooms" ON public.chat_rooms FOR SELECT TO authenticated
  USING (public._admin_write_scope(public._ops_scope_region(region_id)));
DROP POLICY IF EXISTS "admins insert rooms" ON public.chat_rooms;
CREATE POLICY "admins insert rooms" ON public.chat_rooms FOR INSERT TO authenticated
  WITH CHECK (public._admin_write_scope(public._ops_scope_region(region_id)));
DROP POLICY IF EXISTS "admins update rooms" ON public.chat_rooms;
CREATE POLICY "admins update rooms" ON public.chat_rooms FOR UPDATE TO authenticated
  USING (public._admin_write_scope(public._ops_scope_region(region_id)))
  WITH CHECK (public._admin_write_scope(public._ops_scope_region(region_id)));
DROP POLICY IF EXISTS "admins delete rooms" ON public.chat_rooms;
CREATE POLICY "admins delete rooms" ON public.chat_rooms FOR DELETE TO authenticated
  USING (public._admin_write_scope(public._ops_scope_region(region_id)));

-- chat_messages (scope via the room's region)
DROP POLICY IF EXISTS "admins select messages" ON public.chat_messages;
CREATE POLICY "admins select messages" ON public.chat_messages FOR SELECT TO authenticated
  USING (public._admin_write_scope(public._ops_scope_region((
    SELECT r.region_id FROM public.chat_rooms r WHERE r.id = room_id))));
DROP POLICY IF EXISTS "admins insert messages" ON public.chat_messages;
CREATE POLICY "admins insert messages" ON public.chat_messages FOR INSERT TO authenticated
  WITH CHECK (public._admin_write_scope(public._ops_scope_region((
    SELECT r.region_id FROM public.chat_rooms r WHERE r.id = room_id))));
DROP POLICY IF EXISTS "admins update messages" ON public.chat_messages;
CREATE POLICY "admins update messages" ON public.chat_messages FOR UPDATE TO authenticated
  USING (public._admin_write_scope(public._ops_scope_region((
    SELECT r.region_id FROM public.chat_rooms r WHERE r.id = room_id))))
  WITH CHECK (public._admin_write_scope(public._ops_scope_region((
    SELECT r.region_id FROM public.chat_rooms r WHERE r.id = room_id))));
DROP POLICY IF EXISTS "admins delete messages" ON public.chat_messages;
CREATE POLICY "admins delete messages" ON public.chat_messages FOR DELETE TO authenticated
  USING (public._admin_write_scope(public._ops_scope_region((
    SELECT r.region_id FROM public.chat_rooms r WHERE r.id = room_id))));

-- complaints (scope via complainant's member region)
DROP POLICY IF EXISTS "admins select complaints" ON public.complaints;
CREATE POLICY "admins select complaints" ON public.complaints FOR SELECT TO authenticated
  USING (public._admin_member_scope(complainant_id));
DROP POLICY IF EXISTS "admins insert complaints" ON public.complaints;
CREATE POLICY "admins insert complaints" ON public.complaints FOR INSERT TO authenticated
  WITH CHECK (public._admin_member_scope(complainant_id));
DROP POLICY IF EXISTS "admins update complaints" ON public.complaints;
CREATE POLICY "admins update complaints" ON public.complaints FOR UPDATE TO authenticated
  USING (public._admin_member_scope(complainant_id))
  WITH CHECK (public._admin_member_scope(complainant_id));
DROP POLICY IF EXISTS "admins delete complaints" ON public.complaints;
CREATE POLICY "admins delete complaints" ON public.complaints FOR DELETE TO authenticated
  USING (public._admin_member_scope(complainant_id));

-- sanctions (scope via target member's region)
DROP POLICY IF EXISTS "admins select sanctions" ON public.sanctions;
CREATE POLICY "admins select sanctions" ON public.sanctions FOR SELECT TO authenticated
  USING (public._admin_member_scope(target_user_id));
DROP POLICY IF EXISTS "admins insert sanctions" ON public.sanctions;
CREATE POLICY "admins insert sanctions" ON public.sanctions FOR INSERT TO authenticated
  WITH CHECK (public._admin_member_scope(target_user_id));
DROP POLICY IF EXISTS "admins update sanctions" ON public.sanctions;
CREATE POLICY "admins update sanctions" ON public.sanctions FOR UPDATE TO authenticated
  USING (public._admin_member_scope(target_user_id))
  WITH CHECK (public._admin_member_scope(target_user_id));
DROP POLICY IF EXISTS "admins delete sanctions" ON public.sanctions;
CREATE POLICY "admins delete sanctions" ON public.sanctions FOR DELETE TO authenticated
  USING (public._admin_member_scope(target_user_id));

-- driver_documents / driver_locations (scope via driver's member region)
DROP POLICY IF EXISTS "driver documents read" ON public.driver_documents;
CREATE POLICY "driver documents read" ON public.driver_documents FOR SELECT TO authenticated
  USING (public._admin_member_scope((SELECT d.user_id FROM public.drivers d WHERE d.id = driver_id))
         OR (driver_id IN (SELECT d2.id FROM public.drivers d2 WHERE d2.user_id = auth.uid())));
DROP POLICY IF EXISTS "driver location read" ON public.driver_locations;
CREATE POLICY "driver location read" ON public.driver_locations FOR SELECT TO authenticated
  USING (public._admin_member_scope((SELECT d.user_id FROM public.drivers d WHERE d.id = driver_id))
         OR (driver_id IN (SELECT d2.id FROM public.drivers d2 WHERE d2.user_id = auth.uid())));

-- verification_attempts
DROP POLICY IF EXISTS verification_attempts_admin_read ON public.verification_attempts;
CREATE POLICY verification_attempts_admin_read ON public.verification_attempts FOR SELECT TO authenticated
  USING (public._admin_member_scope(user_id));
DROP POLICY IF EXISTS verification_attempts_admin_review ON public.verification_attempts;
CREATE POLICY verification_attempts_admin_review ON public.verification_attempts FOR UPDATE TO authenticated
  USING (public._admin_member_scope(user_id)
         OR ((auth.uid() = user_id) AND (status = 'pending'::text)))
  WITH CHECK (public._admin_member_scope(user_id)
         OR ((auth.uid() = user_id) AND (status = 'pending'::text)));

-- sos_alerts
DROP POLICY IF EXISTS "sos alerts admin select" ON public.sos_alerts;
CREATE POLICY "sos alerts admin select" ON public.sos_alerts FOR SELECT TO authenticated
  USING (public._admin_member_scope(user_id));

-- service_audio_logs (scope via the member the audio belongs to)
DROP POLICY IF EXISTS service_audio_logs_admin_select ON public.service_audio_logs;
CREATE POLICY service_audio_logs_admin_select ON public.service_audio_logs FOR SELECT TO authenticated
  USING (public._admin_member_scope(user_id));

-- grace_accounts
DROP POLICY IF EXISTS grace_owner_select ON public.grace_accounts;
CREATE POLICY grace_owner_select ON public.grace_accounts FOR SELECT TO authenticated
  USING ((user_id = auth.uid()) OR public._admin_member_scope(user_id));

-- user_region_preferences
DROP POLICY IF EXISTS user_region_preferences_admin_select ON public.user_region_preferences;
CREATE POLICY user_region_preferences_admin_select ON public.user_region_preferences FOR SELECT TO authenticated
  USING (public._admin_member_scope(user_id));
