-- 199: auditor recheck items on 196/198 (owner blanket call 2026-11-21).
--
-- 1. _driver_visible_to_ride_party had no active-ride window: any historical
--    rider kept reading the driver's raw row (incl. live GPS) forever. Now
--    only ACTIVE ride states (matched/arrived/inTrip - the states where
--    customer tracking is legitimately live) grant raw-row access; everyone
--    else uses the safe driver_directory view.
--
-- 2. Booking completion price integrity: a booking with NULL estimate, no
--    provider floor and no completion-time quote priced its commission at 0.
--    Completion now requires a positive price source
--    (p_final_price > stored final_price > stored estimate, in that order).
--    INSERT-time NULL estimate stays allowed (legit quote-later flow).

create or replace function public._driver_visible_to_ride_party(p_driver_id uuid)
returns boolean
language sql stable security definer set search_path = public, pg_temp
as $func$
  select exists (select 1 from public.rides r
                  where r.driver_id = p_driver_id
                    and r.rider_id = auth.uid()
                    and r.status in ('matched', 'arrived', 'inTrip'));
$func$;

CREATE OR REPLACE FUNCTION public.update_service_booking_status(p_booking_id uuid, p_status text, p_final_price numeric default null)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_book service_bookings%ROWTYPE;
  v_is_customer boolean;
  v_is_provider boolean;
  v_is_admin boolean := false;
  v_region uuid;
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
  IF p_final_price IS NOT NULL AND p_final_price <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_PRICE');
  END IF;

  SELECT * INTO v_book
    FROM public.service_bookings
   WHERE id = p_booking_id
   FOR UPDATE;
  IF v_book.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;

  v_is_customer := v_book.user_id = v_uid;
  v_is_provider := public.is_service_provider_owner(v_book.provider_id);

  -- Admin branch is region-scoped (195/196): the booking's region is the
  -- booking customer's users.region_id; NULL-region customers fall back to
  -- owner/global admins only (_admin_scope_allows), matching the 194
  -- incident pattern and the 190 appeals precedent.
  IF NOT (v_is_customer OR v_is_provider) THEN
    IF public._is_owner_uid(v_uid) THEN
      v_is_admin := true;
    ELSE
      SELECT region_id INTO v_region FROM public.users WHERE id = v_book.user_id;
      v_is_admin := (public.has_permission('SERVICE_MANAGE', NULL, NULL)
                  OR public.has_permission('MEMBER_MODERATE', NULL, NULL))
                AND public._admin_scope_allows(v_region);
    END IF;
  END IF;

  IF NOT (v_is_customer OR v_is_provider OR v_is_admin) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_YOUR_BOOKING');
  END IF;

  v_cur_status := v_book.status;
  IF v_cur_status IN ('completed','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'TERMINAL_STATE', 'status', v_cur_status);
  END IF;

  -- Role transition matrix.
  IF v_is_customer THEN
    v_allowed := p_status = 'cancelled' AND v_cur_status IN ('pending','confirmed');
  ELSIF v_is_provider THEN
    v_allowed := (v_cur_status = 'pending'    AND p_status = 'confirmed')
              OR (v_cur_status = 'confirmed'  AND p_status = 'inProgress')
              OR (v_cur_status = 'inProgress' AND p_status = 'completed');
  ELSE -- region-scoped admin: support cancellation only
    v_allowed := p_status = 'cancelled';
  END IF;

  IF NOT v_allowed THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_TRANSITION',
      'from', v_cur_status, 'to', p_status);
  END IF;

  -- Only the provider may quote the final price, and only while the booking
  -- is live (196: commission base = provider final_price, else estimate).
  IF p_final_price IS NOT NULL AND NOT v_is_provider THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'PRICE_PROVIDER_ONLY');
  END IF;

  -- 199: completion needs a real price. A quote-less completion (NULL
  -- estimate, no stored final, no completion-time quote) would price the
  -- platform commission at zero.
  IF p_status = 'completed'
     AND COALESCE(p_final_price, v_book.final_price, v_book.estimated_price, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'PRICE_REQUIRED');
  END IF;

  UPDATE public.service_bookings
     SET status = p_status,
         final_price = CASE WHEN p_final_price IS NOT NULL THEN p_final_price ELSE final_price END,
         completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
         updated_at = now()
   WHERE id = p_booking_id;

  -- Completion records the platform's commission on the provider: the agreed
  -- price (final when set, else the estimate) at the provider rate, once.
  -- 197: price from the POST-update values - p_final_price lands in the same
  -- statement, so the pre-update v_book copy is stale here.
  IF p_status = 'completed' THEN
    SELECT user_id INTO v_provider_uid
      FROM public.service_providers WHERE id = v_book.provider_id;
    IF v_provider_uid IS NOT NULL THEN
      v_gross := COALESCE(p_final_price, v_book.final_price, v_book.estimated_price, 0);
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
