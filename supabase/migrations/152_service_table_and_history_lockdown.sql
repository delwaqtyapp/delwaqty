-- ============================================================
-- 152_service_table_and_history_lockdown.sql
--  1. whatsapp_otp_verifications held live OTP codes behind a
--     policy named "service_only" that actually read
--     USING (true) WITH CHECK (true): ANY client (anon too)
--     could read every OTP code or insert a verified row.
--     Policy dropped; service_role bypasses RLS, so edge
--     functions keep working and every client path is denied.
--  2. notification_push_config had the same USING(true) shape:
--     its auth_token for the push edge function was readable
--     and writable by any client. Same fix.
--  3. promo_redemptions was owner read/write/delete: a user
--     could delete their redemption rows to reuse a coupon
--     forever. Now select + insert only.
--  4. trip_events was participant ALL: a rider or driver could
--     rewrite or erase the trip trail. Now select + insert only.
--  5. complaints: a complainant could update the admin-side
--     columns (status, priority, admin_notes, resolution_note,
--     resolved_at, assigned_admin_id). Guard trigger freezes
--     those for non-admin client roles; the complainant keeps
--     subject/description/attachments.
-- ============================================================

-- ─── 1 & 2. service-only tables: deny every client path ──────

DROP POLICY IF EXISTS whatsapp_otp_service_only ON public.whatsapp_otp_verifications;
DROP POLICY IF EXISTS "push config service role all" ON public.notification_push_config;

-- ─── 3. promo redemptions: no rewrite, no delete ─────────────

DROP POLICY IF EXISTS "promo redemptions owner rw" ON public.promo_redemptions;
CREATE POLICY "promo redemptions owner read" ON public.promo_redemptions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY "promo redemptions owner add" ON public.promo_redemptions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ─── 4. trip events: append-only for participants ────────────

DROP POLICY IF EXISTS "trip events participants" ON public.trip_events;
CREATE POLICY "trip events participant read" ON public.trip_events
  FOR SELECT TO authenticated
  USING (ride_id IN (
    SELECT r.id FROM public.rides r
    WHERE r.rider_id = auth.uid()
       OR r.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  ));
CREATE POLICY "trip events participant add" ON public.trip_events
  FOR INSERT TO authenticated
  WITH CHECK (ride_id IN (
    SELECT r.id FROM public.rides r
    WHERE r.rider_id = auth.uid()
       OR r.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
  ));

-- ─── 5. complaints: complainant cannot write the admin side ──

CREATE OR REPLACE FUNCTION public.complaints_guard_admin_fields()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status
     OR NEW.priority IS DISTINCT FROM OLD.priority
     OR NEW.admin_notes IS DISTINCT FROM OLD.admin_notes
     OR NEW.resolution_note IS DISTINCT FROM OLD.resolution_note
     OR NEW.resolved_at IS DISTINCT FROM OLD.resolved_at
     OR NEW.assigned_admin_id IS DISTINCT FROM OLD.assigned_admin_id
     OR NEW.escalated_at IS DISTINCT FROM OLD.escalated_at
     OR NEW.escalated_from_admin_id IS DISTINCT FROM OLD.escalated_from_admin_id
     OR NEW.complainant_id IS DISTINCT FROM OLD.complainant_id
     OR NEW.respondent_id IS DISTINCT FROM OLD.respondent_id
     OR NEW.reporter_id IS DISTINCT FROM OLD.reporter_id
     OR NEW.order_id IS DISTINCT FROM OLD.order_id
     OR NEW.ride_id IS DISTINCT FROM OLD.ride_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'complaint handling fields are managed by the admin team';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_complaints_guard_admin_fields ON public.complaints;
CREATE TRIGGER trg_complaints_guard_admin_fields
  BEFORE UPDATE ON public.complaints
  FOR EACH ROW EXECUTE FUNCTION public.complaints_guard_admin_fields();
