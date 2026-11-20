-- Run after migration 148. Every fixture and resulting row is rolled back.
-- Verifies: completing a service booking records the provider commission
-- exactly once at the provider rate on the agreed price, and non-completing
-- transitions record nothing.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid();
  p_user uuid := gen_random_uuid();
  sp uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  a jsonb;
  v_row public.platform_commissions%ROWTYPE;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(p_user,p_user::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(p_user,p_user::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.service_providers(id,user_id,name,category_type)
    VALUES (sp,p_user,'Synthetic provider','plumbing');
  INSERT INTO public.service_bookings(id,user_id,provider_id,provider_name,category_type,status,scheduled_date,scheduled_time,address,estimated_price)
    VALUES (b,c,sp,'Synthetic provider','plumbing','confirmed',CURRENT_DATE,'18:00','Synthetic address',200);

  -- Customer confirms a non-completing transition first: no commission yet.
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.update_service_booking_status(b, 'inProgress');
  PERFORM set_config('role','none',true);
  IF (a->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'inProgress failed: %', a; END IF;
  IF EXISTS (SELECT 1 FROM public.platform_commissions WHERE reference_type='service_booking' AND reference_id=b) THEN
    RAISE EXCEPTION 'commission recorded before completion';
  END IF;

  -- Provider completes the booking: commission = 7% of 200 = 14.00.
  PERFORM set_config('request.jwt.claim.sub', p_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.update_service_booking_status(b, 'completed');
  PERFORM set_config('role','none',true);
  IF (a->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'completion failed: %', a; END IF;

  SELECT * INTO v_row FROM public.platform_commissions
   WHERE reference_type='service_booking' AND reference_id=b AND member_id=p_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'no provider commission row'; END IF;
  IF v_row.gross_amount <> 200 OR v_row.commission_rate <> 7
     OR v_row.commission_amount <> 14.00 OR v_row.net_amount <> 186.00
     OR v_row.status <> 'computed' THEN
    RAISE EXCEPTION 'provider commission row wrong: %', v_row;
  END IF;

  -- Terminal state: a second completion refuses and records nothing extra.
  PERFORM set_config('request.jwt.claim.sub', p_user::text, true);
  PERFORM set_config('role','authenticated',true);
  a := public.update_service_booking_status(b, 'completed');
  PERFORM set_config('role','none',true);
  IF a->>'reason' IS DISTINCT FROM 'TERMINAL_STATE' THEN
    RAISE EXCEPTION 'repeat completion allowed: %', a;
  END IF;
  IF (SELECT count(*) FROM public.platform_commissions WHERE reference_type='service_booking' AND reference_id=b) <> 1 THEN
    RAISE EXCEPTION 'commission recording not idempotent';
  END IF;
END;
$$;
ROLLBACK;
