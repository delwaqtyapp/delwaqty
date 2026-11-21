-- ============================================================
-- 153_service_booking_update_lockdown.sql
-- service_bookings had the same hole as orders: the customer OR
-- the provider could UPDATE every column directly (price,
-- payment_status, provider_id, status), bypassing the
-- commission-recording RPC update_service_booking_status (148).
-- That RPC is role-aware (customer, provider owner, platform
-- owner, regional admin) and records the provider commission on
-- completion. A guard trigger now freezes all booking columns
-- for non-admin client roles; every transition goes through
-- the RPC. SECURITY DEFINER RPCs are unaffected.
-- ============================================================

CREATE OR REPLACE FUNCTION public.service_bookings_guard_client_writes()
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
  RAISE EXCEPTION 'booking fields are managed by update_service_booking_status';
END;
$$;

DROP TRIGGER IF EXISTS trg_service_bookings_guard ON public.service_bookings;
CREATE TRIGGER trg_service_bookings_guard
  BEFORE UPDATE ON public.service_bookings
  FOR EACH ROW EXECUTE FUNCTION public.service_bookings_guard_client_writes();
