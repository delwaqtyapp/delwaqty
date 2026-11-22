-- Run after migration 150. Every fixture and resulting row is rolled back.
-- Verifies review/rating forgery lockdown: identity freeze on review edits,
-- verified-order rule on review insert, verified-booking rule on service
-- review insert, and ride-participant rule on ride ratings.
BEGIN;
DO $$
DECLARE
  buyer uuid := gen_random_uuid();
  other uuid := gen_random_uuid();
  drv uuid := gen_random_uuid();
  merch uuid := gen_random_uuid();
  ord_delivered uuid := gen_random_uuid();
  ord_pending uuid := gen_random_uuid();
  ord_other uuid := gen_random_uuid();
  bk_completed uuid := gen_random_uuid();
  bk_pending uuid := gen_random_uuid();
  ride_id uuid := gen_random_uuid();
  rev uuid := gen_random_uuid();
  v_blocked boolean;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (buyer,buyer::text||'@example.invalid'),
    (other,other::text||'@example.invalid'),
    (drv,drv::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (buyer,buyer::text||'@example.invalid'),
    (other,other::text||'@example.invalid'),
    (drv,drv::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;

  -- merchant owned by someone else (owner not needed for these checks)
  INSERT INTO public.merchants(id, owner_user_id, name)
    VALUES (merch, other, 'Fixture Merchant');

  INSERT INTO public.orders(id, user_id, merchant_id, status, subtotal, total_amount) VALUES
    (ord_delivered, buyer, merch, 'delivered', 10, 10),
    (ord_pending, buyer, merch, 'pending', 10, 10),
    (ord_other, other, merch, 'delivered', 10, 10);

  INSERT INTO public.service_providers(id, name, category_type)
    VALUES (drv, 'Fixture Provider', 'plumbing');

  INSERT INTO public.service_bookings(id, user_id, provider_id, provider_name, category_type, scheduled_date, scheduled_time, status) VALUES
    (bk_completed, buyer, drv, 'Fixture Provider', 'plumbing', CURRENT_DATE, '10:00', 'completed'),
    (bk_pending, buyer, drv, 'Fixture Provider', 'plumbing', CURRENT_DATE, '10:00', 'pending');

  INSERT INTO public.drivers(id, user_id, full_name, status, is_verified, is_active, accepts_deliveries, current_latitude, current_longitude)
    VALUES (drv, drv, 'Fixture Driver', 'online', true, true, true, 30, 31);

  -- Migration 392 gates rating on cash collection, so this fixture ride is
  -- already collected (a completed cash handoff).
  INSERT INTO public.rides(id, rider_id, driver_id, status, payment_status, cash_collected_at, cash_collected_by,
      pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude)
    VALUES (ride_id, buyer, drv, 'completed', 'paid', now(), drv, 30.0, 31.0, 30.1, 31.1);

  PERFORM set_config('request.jwt.claim.sub', buyer::text, true);
  PERFORM set_config('role','authenticated',true);

  -- 1. buyer CAN review with their own delivered order.
  INSERT INTO public.reviews(id, user_id, merchant_id, order_id, rating)
    VALUES (rev, buyer, merch, ord_delivered, 5);

  -- 2. buyer CANNOT review citing a pending order.
  v_blocked := false;
  BEGIN
    INSERT INTO public.reviews(user_id, merchant_id, order_id, rating)
      VALUES (buyer, merch, ord_pending, 5);
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'review accepted pending order'; END IF;

  -- 3. buyer CANNOT review citing another user's delivered order.
  v_blocked := false;
  BEGIN
    INSERT INTO public.reviews(user_id, merchant_id, order_id, rating)
      VALUES (buyer, merch, ord_other, 5);
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'review accepted another users order'; END IF;

  -- 4. buyer can edit their own review's rating...
  UPDATE public.reviews SET rating = 4, comment = 'revised' WHERE id = rev;

  -- 5. ...but CANNOT reassign it to another user (trigger).
  v_blocked := false;
  BEGIN
    UPDATE public.reviews SET user_id = other WHERE id = rev;
  EXCEPTION WHEN OTHERS THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'review reassigned to another user'; END IF;

  -- 6. ...and CANNOT move it to another order (trigger).
  v_blocked := false;
  BEGIN
    UPDATE public.reviews SET order_id = ord_pending WHERE id = rev;
  EXCEPTION WHEN OTHERS THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'review moved to another order'; END IF;

  -- 7. service review with completed own booking: allowed.
  INSERT INTO public.service_reviews(user_id, user_name, category_type, provider_id, booking_id, rating)
    VALUES (buyer, 'Buyer', 'plumbing', drv, bk_completed, 5);

  -- 8. service review citing pending booking: blocked.
  v_blocked := false;
  BEGIN
    INSERT INTO public.service_reviews(user_id, user_name, category_type, provider_id, booking_id, rating)
      VALUES (buyer, 'Buyer', 'plumbing', drv, bk_pending, 1);
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'service review accepted pending booking'; END IF;

  -- 9. rider can rate their own ride.
  INSERT INTO public.ride_ratings(ride_id, rater_id, ratee_role, stars)
    VALUES (ride_id, buyer, 'driver', 5);

  -- 10. a non-participant cannot rate the ride.
  PERFORM set_config('role','none',true);
  PERFORM set_config('request.jwt.claim.sub', other::text, true);
  PERFORM set_config('role','authenticated',true);
  v_blocked := false;
  BEGIN
    INSERT INTO public.ride_ratings(ride_id, rater_id, ratee_role, stars)
      VALUES (ride_id, other, 'driver', 1);
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'non-participant rated a ride'; END IF;

  PERFORM set_config('role','none',true);
END;
$$;
ROLLBACK;
