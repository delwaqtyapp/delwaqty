-- 148: record the provider commission when a home-service booking completes.
--
-- update_service_booking_status marked bookings completed but recorded no
-- economics - the same hole 147 closed for deliveries. The commission_rules
-- table already carries the provider default (7%) and the admin snapshot tool
-- already uses the ('service_booking', id) reference convention. Recording
-- only: no wallet movements, transfers, payouts or balance changes; cash
-- settlement continues through the existing subsystems.
BEGIN;

CREATE OR REPLACE FUNCTION public.update_service_booking_status(p_booking_id uuid, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_book service_bookings%ROWTYPE;
  v_allowed boolean := false;
  v_cur_status text;
  v_provider_uid uuid;
  v_gross numeric;
  v_rate numeric;
  v_commission numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF p_status NOT IN ('confirmed','inProgress','completed','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATUS');
  END IF;

  SELECT * INTO v_book
    FROM public.service_bookings
   WHERE id = p_booking_id
   FOR UPDATE;
  IF v_book.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;

  -- Role-aware authorization, in order of least-to-most privilege:
  -- 1) booking owner (the requesting customer)
  -- 2) the assigned Service Provider (their business owns the booking)
  -- 3) the platform Owner
  -- 4) an in-scope region Administrator with SERVICE_MANAGE / MEMBER_MODERATE
  v_allowed := v_book.user_id = v_uid;

  IF NOT v_allowed THEN
    v_allowed := public.is_service_provider_owner(v_book.provider_id);
  END IF;

  IF NOT v_allowed THEN
    v_allowed := public._is_owner_uid(v_uid);
  END IF;

  IF NOT v_allowed THEN
    v_allowed := public.has_permission('SERVICE_MANAGE', NULL, NULL)
      OR public.has_permission('MEMBER_MODERATE', NULL, NULL);
  END IF;

  IF NOT v_allowed THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_YOUR_BOOKING');
  END IF;

  v_cur_status := v_book.status;
  IF v_cur_status IN ('completed','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'TERMINAL_STATE', 'status', v_cur_status);
  END IF;

  UPDATE public.service_bookings
     SET status = p_status,
         completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
         updated_at = now()
   WHERE id = p_booking_id;

  -- Completion records the platform's commission on the provider: the agreed
  -- price (final when set, else the estimate) at the provider rate, once.
  IF p_status = 'completed' THEN
    SELECT user_id INTO v_provider_uid
      FROM public.service_providers WHERE id = v_book.provider_id;
    IF v_provider_uid IS NOT NULL THEN
      v_gross := COALESCE(v_book.final_price, v_book.estimated_price, 0);
      v_rate := COALESCE(
        public.get_commission_rate('provider', v_book.category_type, v_provider_uid), 0);
      v_commission := public.calculate_commission(v_gross, v_rate);
      INSERT INTO public.platform_commissions
        (member_id, reference_type, reference_id, gross_amount, commission_rate,
         commission_amount, net_amount, currency, status)
      VALUES (v_provider_uid, 'service_booking', p_booking_id, v_gross, v_rate,
              v_commission, v_gross - v_commission, 'EGP', 'computed')
      ON CONFLICT (reference_type, reference_id) DO NOTHING;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'status', p_status);
END;
$function$;

NOTIFY pgrst, 'reload schema';
COMMIT;
