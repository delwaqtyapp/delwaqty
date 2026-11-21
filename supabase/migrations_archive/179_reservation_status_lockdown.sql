-- 179_reservation_status_lockdown.sql
-- Bughunt F22 (third pass): a customer could self-CONFIRM a reservation
-- without the merchant. Two paths:
--   a) RLS: reservations_update_merchant allows user_id = auth.uid(), and
--      the customer app writes the reservations table directly - status,
--      table_number, anything. No column guard existed.
--   b) RPC: update_reservation_status lets the reservation owner set
--      'confirmed' (dead code in the shipped app, but callable).
-- Fix:
--   a) SECURITY INVOKER guard trigger: for app-role callers who are neither
--      admin nor the merchant owner, status may only change to 'cancelled'
--      and ownership fields are immutable. Customer logistics edits
--      (party_size, time, special_requests) keep working; merchant app
--      confirm/cancel keeps working via is_merchant_owner.
--   b) update_reservation_status: non-merchant non-admin callers may only
--      cancel.

CREATE OR REPLACE FUNCTION public.reservations_guard_customer_updates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF current_user IN ('authenticated', 'anon') THEN
    IF public.is_admin() OR public.is_merchant_owner(OLD.merchant_id) THEN
      RETURN NEW;
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status <> 'cancelled' THEN
      RAISE EXCEPTION 'Only the merchant or platform can change reservation status';
    END IF;
    IF NEW.merchant_id IS DISTINCT FROM OLD.merchant_id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'Reservation ownership cannot change';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS reservations_guard_customer_updates ON public.reservations;
CREATE TRIGGER reservations_guard_customer_updates
  BEFORE UPDATE ON public.reservations
  FOR EACH ROW
  EXECUTE FUNCTION public.reservations_guard_customer_updates();

CREATE OR REPLACE FUNCTION public.update_reservation_status(p_reservation_id uuid, p_status text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_r public.reservations;
  v_uid uuid := auth.uid();
  v_merchant_ok boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('pending','confirmed','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS');
  END IF;
  SELECT * INTO v_r FROM public.reservations WHERE id = p_reservation_id FOR UPDATE;
  IF v_r IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.merchants m
     WHERE m.id = v_r.merchant_id AND m.owner_user_id = v_uid
  ) INTO v_merchant_ok;
  IF v_r.user_id IS DISTINCT FROM v_uid AND NOT v_merchant_ok AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  -- Customers may only cancel their own reservation; confirming is the
  -- merchant's (or platform's) call.
  IF NOT v_merchant_ok AND NOT public.is_admin() AND p_status <> 'cancelled' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'MERCHANT_ONLY_STATUS');
  END IF;
  IF p_status = 'cancelled' AND v_r.status = 'cancelled' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_CANCELLED');
  END IF;
  UPDATE public.reservations SET status = p_status WHERE id = v_r.id;
  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'status', p_status);
END;
$function$;
