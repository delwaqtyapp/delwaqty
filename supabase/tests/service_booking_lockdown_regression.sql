-- Run after migration 153. Fixtures and rows roll back.
-- Verifies: customer/provider cannot rewrite bookings directly, the
-- commission-recording RPC still works for both roles, and completion
-- records the provider commission exactly once.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid();   -- customer
  p uuid := gen_random_uuid();   -- provider owner user
  sp uuid := gen_random_uuid();  -- service_providers row
  b uuid := gen_random_uuid();   -- booking
  v_blocked boolean;
  v_res jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(p,p::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(p,p::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.service_providers(id, user_id, name, category_type)
    VALUES (sp, p, 'Fixture Provider', 'plumbing');
  INSERT INTO public.service_bookings(id, user_id, provider_id, provider_name,
      category_type, scheduled_date, scheduled_time, status, estimated_price)
    VALUES (b, c, sp, 'Fixture Provider', 'plumbing', CURRENT_DATE, '10:00',
            'confirmed', 200);

  -- customer cannot rewrite the booking directly
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);

  v_blocked := false;
  BEGIN
    UPDATE public.service_bookings SET payment_status = 'paid' WHERE id = b;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer marked booking paid'; END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.service_bookings SET estimated_price = 1 WHERE id = b;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer rewrote price'; END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.service_bookings SET status = 'completed' WHERE id = b;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer completed own booking directly'; END IF;

  -- customer cancels through the RPC: allowed, no commission on cancel
  SELECT public.update_service_booking_status(b, 'cancelled') INTO v_res;
  IF NOT (v_res->>'ok')::boolean THEN
    RAISE EXCEPTION 'customer cancel via RPC refused: %', v_res;
  END IF;
  -- terminal state is sticky
  SELECT public.update_service_booking_status(b, 'completed') INTO v_res;
  IF v_res->>'reason' <> 'TERMINAL_STATE' THEN
    RAISE EXCEPTION 'cancelled booking resurrected: %', v_res;
  END IF;

  -- provider completes a second booking through the RPC: commission recorded
  PERFORM set_config('role','none',true);
  IF EXISTS (SELECT 1 FROM public.platform_commissions
             WHERE reference_type='service_booking' AND reference_id=b) THEN
    RAISE EXCEPTION 'commission recorded for a cancelled booking';
  END IF;
  INSERT INTO public.service_bookings(id, user_id, provider_id, provider_name,
      category_type, scheduled_date, scheduled_time, status, estimated_price)
    VALUES (gen_random_uuid(), c, sp, 'Fixture Provider', 'plumbing',
            CURRENT_DATE, '11:00', 'confirmed', 200)
    RETURNING id INTO b;
  PERFORM set_config('request.jwt.claim.sub', p::text, true);
  PERFORM set_config('role','authenticated',true);

  v_blocked := false;
  BEGIN
    UPDATE public.service_bookings SET status = 'completed' WHERE id = b;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'provider completed booking directly'; END IF;

  SELECT public.update_service_booking_status(b, 'completed') INTO v_res;
  IF NOT (v_res->>'ok')::boolean THEN
    RAISE EXCEPTION 'provider completion via RPC refused: %', v_res;
  END IF;

  PERFORM set_config('role','none',true);
  IF NOT EXISTS (
    SELECT 1 FROM public.platform_commissions
    WHERE reference_type='service_booking' AND reference_id=b
      AND gross_amount=200 AND commission_amount=14.00 AND net_amount=186.00
  ) THEN
    RAISE EXCEPTION 'provider commission missing or wrong';
  END IF;

  -- idempotent
  PERFORM set_config('request.jwt.claim.sub', p::text, true);
  PERFORM set_config('role','authenticated',true);
  SELECT public.update_service_booking_status(b, 'completed') INTO v_res;
  IF v_res->>'reason' <> 'TERMINAL_STATE' THEN
    RAISE EXCEPTION 'second completion not refused: %', v_res;
  END IF;

  PERFORM set_config('role','none',true);
END;
$$;
ROLLBACK;
