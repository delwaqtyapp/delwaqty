-- =============================================================
-- Migration 008: Dispatch Engine & Live Trip Lifecycle (M4)
-- =============================================================
-- Adds the real dispatch engine on top of migration 007:
--   * driver online/offline with live location
--   * ride offer queue (ride_requests) with timeout + reassignment
--   * atomic accept/reject, arrival, OTP-gated start, completion
--   * driver location bridged to the active ride row for tracking
--   * driver earnings + wallet credit, passenger rating by driver
--   * server-validated trip state machine (illegal transitions blocked)
-- Idempotent: safe to re-run.
-- =============================================================

-- --- Extra columns for lifecycle bookkeeping -----------------
ALTER TABLE rides ADD COLUMN IF NOT EXISTS cancelled_by TEXT
  CHECK (cancelled_by IN ('rider','driver','system'));
ALTER TABLE rides ADD COLUMN IF NOT EXISTS driver_rating INTEGER
  CHECK (driver_rating >= 1 AND driver_rating <= 5);
ALTER TABLE rides ADD COLUMN IF NOT EXISTS driver_feedback TEXT;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS driver_heading DECIMAL(6,2);
ALTER TABLE rides ADD COLUMN IF NOT EXISTS driver_arrived_confirmed BOOLEAN DEFAULT false;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS reassign_count INTEGER DEFAULT 0;

-- --- Dispatch tuning knobs on ride_requests ------------------
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS eta_minutes INTEGER;

-- =============================================================
-- RPC: driver_set_online  (online/offline + initial location)
-- =============================================================
CREATE OR REPLACE FUNCTION driver_set_online(
  p_driver_id UUID,
  p_online BOOLEAN,
  p_lat DOUBLE PRECISION DEFAULT NULL,
  p_lon DOUBLE PRECISION DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  UPDATE drivers SET
    is_online = p_online,
    current_latitude = COALESCE(p_lat, current_latitude),
    current_longitude = COALESCE(p_lon, current_longitude),
    location_updated_at = NOW()
  WHERE id = p_driver_id;

  IF p_online AND p_lat IS NOT NULL AND p_lon IS NOT NULL THEN
    INSERT INTO driver_locations (driver_id, latitude, longitude, updated_at)
      VALUES (p_driver_id, p_lat, p_lon, NOW())
    ON CONFLICT (driver_id) DO UPDATE
      SET latitude = EXCLUDED.latitude,
          longitude = EXCLUDED.longitude,
          updated_at = NOW();
  END IF;

  RETURN jsonb_build_object('success', true, 'online', p_online);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: driver_update_location
-- Updates driver_locations, drivers cache, and bridges the
-- position into the active ride row for passenger live tracking.
-- =============================================================
CREATE OR REPLACE FUNCTION driver_update_location(
  p_driver_id UUID,
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION,
  p_heading DOUBLE PRECISION DEFAULT NULL,
  p_speed DOUBLE PRECISION DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_owner UUID;
  v_ride UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  SELECT id INTO v_ride FROM rides
    WHERE driver_id = p_driver_id
      AND status IN ('matched','arrived','inTrip')
    ORDER BY created_at DESC LIMIT 1;

  INSERT INTO driver_locations (driver_id, latitude, longitude, heading, speed, ride_id, updated_at)
    VALUES (p_driver_id, p_lat, p_lon, p_heading, p_speed, v_ride, NOW())
  ON CONFLICT (driver_id) DO UPDATE
    SET latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        heading = EXCLUDED.heading,
        speed = EXCLUDED.speed,
        ride_id = EXCLUDED.ride_id,
        updated_at = NOW();

  UPDATE drivers SET
    current_latitude = p_lat,
    current_longitude = p_lon,
    location_updated_at = NOW()
  WHERE id = p_driver_id;

  IF v_ride IS NOT NULL THEN
    UPDATE rides SET
      driver_latitude = p_lat,
      driver_longitude = p_lon,
      driver_heading = p_heading
    WHERE id = v_ride;
  END IF;

  RETURN jsonb_build_object('success', true, 'ride_id', v_ride);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: dispatch_ride
-- Expires stale offers, then offers the ride to the nearest
-- available drivers who have not already rejected/expired it.
-- Called by the passenger client after requestRide and can be
-- re-invoked to reassign after timeouts.
-- =============================================================
CREATE OR REPLACE FUNCTION dispatch_ride(
  p_ride_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 8,
  p_limit INTEGER DEFAULT 5
) RETURNS JSONB AS $$
DECLARE
  r rides%ROWTYPE;
  v_offered INTEGER := 0;
  drv RECORD;
  v_eta INTEGER;
BEGIN
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;
  IF r.status <> 'searching' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_searching', 'status', r.status);
  END IF;

  -- expire timed-out offers
  UPDATE ride_requests SET status = 'expired'
    WHERE ride_id = p_ride_id AND status = 'offered' AND expires_at < NOW();

  -- do not double-offer while a live offer is pending
  IF EXISTS (SELECT 1 FROM ride_requests
             WHERE ride_id = p_ride_id AND status = 'offered' AND expires_at >= NOW()) THEN
    RETURN jsonb_build_object('success', true, 'offered', 0, 'reason', 'pending_offer');
  END IF;

  FOR drv IN
    SELECT d.id AS driver_id,
           haversine_km(r.pickup_latitude::DOUBLE PRECISION, r.pickup_longitude::DOUBLE PRECISION,
                        dl.latitude::DOUBLE PRECISION, dl.longitude::DOUBLE PRECISION) AS distance_km
    FROM drivers d
    JOIN driver_locations dl ON dl.driver_id = d.id
    WHERE d.is_online = true
      AND d.is_verified = true
      AND EXISTS (SELECT 1 FROM vehicles v
                  WHERE v.driver_id = d.id AND v.is_active = true AND v.category = r.ride_type)
      AND haversine_km(r.pickup_latitude::DOUBLE PRECISION, r.pickup_longitude::DOUBLE PRECISION,
                       dl.latitude::DOUBLE PRECISION, dl.longitude::DOUBLE PRECISION) <= p_radius_km
      AND NOT EXISTS (SELECT 1 FROM rides r2
                      WHERE r2.driver_id = d.id AND r2.status IN ('matched','arrived','inTrip'))
      AND NOT EXISTS (SELECT 1 FROM ride_requests rq
                      WHERE rq.ride_id = p_ride_id AND rq.driver_id = d.id
                        AND rq.status IN ('rejected','expired','accepted'))
    ORDER BY distance_km ASC
    LIMIT p_limit
  LOOP
    v_eta := GREATEST(1, CEIL(drv.distance_km / 0.5))::INTEGER; -- ~30km/h approach
    INSERT INTO ride_requests (ride_id, driver_id, status, distance_km, eta_minutes,
                               offered_at, expires_at)
      VALUES (p_ride_id, drv.driver_id, 'offered', drv.distance_km, v_eta,
              NOW(), NOW() + INTERVAL '20 seconds')
    ON CONFLICT (ride_id, driver_id) DO UPDATE
      SET status = 'offered', distance_km = EXCLUDED.distance_km,
          eta_minutes = EXCLUDED.eta_minutes, offered_at = NOW(),
          expires_at = NOW() + INTERVAL '20 seconds', responded_at = NULL;
    v_offered := v_offered + 1;
  END LOOP;

  IF v_offered = 0 THEN
    UPDATE rides SET reassign_count = reassign_count + 1 WHERE id = p_ride_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'offered', v_offered);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: accept_ride_request  (driver accepts an offer, atomic)
-- =============================================================
CREATE OR REPLACE FUNCTION accept_ride_request(
  p_ride_id UUID,
  p_driver_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_owner UUID;
  v_status TEXT;
  v_req_status TEXT;
  v_otp TEXT;
  drv drivers%ROWTYPE;
  veh vehicles%ROWTYPE;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  -- driver must not already be on a live trip
  IF EXISTS (SELECT 1 FROM rides WHERE driver_id = p_driver_id
             AND status IN ('matched','arrived','inTrip')) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'driver_busy');
  END IF;

  SELECT status INTO v_req_status FROM ride_requests
    WHERE ride_id = p_ride_id AND driver_id = p_driver_id FOR UPDATE;
  IF v_req_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_offer');
  END IF;
  IF v_req_status <> 'offered' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'offer_' || v_req_status);
  END IF;

  SELECT status INTO v_status FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF v_status IS DISTINCT FROM 'searching' THEN
    UPDATE ride_requests SET status = 'expired', responded_at = NOW()
      WHERE ride_id = p_ride_id AND driver_id = p_driver_id;
    RETURN jsonb_build_object('success', false, 'reason', 'ride_unavailable');
  END IF;

  SELECT * INTO drv FROM drivers WHERE id = p_driver_id;
  SELECT * INTO veh FROM vehicles
    WHERE driver_id = p_driver_id AND is_active = true LIMIT 1;
  v_otp := lpad((floor(random() * 10000))::INT::TEXT, 4, '0');

  UPDATE rides SET
    driver_id = p_driver_id,
    driver_name = drv.full_name,
    driver_phone = drv.phone,
    vehicle_type = COALESCE(veh.make || ' ' || veh.model, drv.vehicle_type),
    vehicle_plate = COALESCE(veh.plate_number, drv.vehicle_plate),
    vehicle_color = COALESCE(veh.color, drv.vehicle_color),
    driver_latitude = drv.current_latitude,
    driver_longitude = drv.current_longitude,
    status = 'matched',
    matched_at = NOW(),
    pickup_otp = v_otp
  WHERE id = p_ride_id;

  UPDATE ride_requests SET status = 'accepted', responded_at = NOW()
    WHERE ride_id = p_ride_id AND driver_id = p_driver_id;
  -- withdraw sibling offers
  UPDATE ride_requests SET status = 'expired', responded_at = NOW()
    WHERE ride_id = p_ride_id AND driver_id <> p_driver_id AND status = 'offered';

  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'accepted', 'driver');
  RETURN jsonb_build_object('success', true, 'otp', v_otp);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: reject_ride_request  (driver declines; frees for reassign)
-- =============================================================
CREATE OR REPLACE FUNCTION reject_ride_request(
  p_ride_id UUID,
  p_driver_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  UPDATE ride_requests SET status = 'rejected', responded_at = NOW()
    WHERE ride_id = p_ride_id AND driver_id = p_driver_id AND status = 'offered';
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'rejected', 'driver');
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: driver_arrive  (matched -> arrived)
-- =============================================================
CREATE OR REPLACE FUNCTION driver_arrive(
  p_ride_id UUID,
  p_driver_id UUID
) RETURNS JSONB AS $$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  IF r.status <> 'matched' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;
  UPDATE rides SET status = 'arrived', arrived_at = NOW(),
    driver_arrived_confirmed = true WHERE id = p_ride_id;
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'driver_arrived', 'driver');
  RETURN jsonb_build_object('success', true, 'status', 'arrived');
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: start_trip  (arrived -> inTrip, OTP gated)
-- =============================================================
CREATE OR REPLACE FUNCTION start_trip(
  p_ride_id UUID,
  p_driver_id UUID,
  p_otp TEXT
) RETURNS JSONB AS $$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  IF r.status <> 'arrived' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;
  IF r.pickup_otp IS NOT NULL AND p_otp IS DISTINCT FROM r.pickup_otp THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_otp');
  END IF;
  UPDATE rides SET status = 'inTrip', started_at = NOW() WHERE id = p_ride_id;
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'otp_verified', 'driver');
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'trip_started', 'driver');
  RETURN jsonb_build_object('success', true, 'status', 'inTrip');
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: complete_trip  (inTrip -> completed + earnings credit)
-- =============================================================
CREATE OR REPLACE FUNCTION complete_trip(
  p_ride_id UUID,
  p_driver_id UUID,
  p_final_distance DOUBLE PRECISION DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  IF r.status <> 'inTrip' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;

  UPDATE rides SET status = 'completed', completed_at = NOW(),
    payment_status = 'paid' WHERE id = p_ride_id;

  IF r.fare IS NOT NULL THEN
    INSERT INTO driver_earnings (driver_id, ride_id, type, amount, description)
      VALUES (p_driver_id, p_ride_id, 'trip', r.fare, 'Trip fare');
    UPDATE drivers SET
      earnings_balance = COALESCE(earnings_balance, 0) + r.fare,
      total_trips = COALESCE(total_trips, 0) + 1
    WHERE id = p_driver_id;
  END IF;

  -- detach driver location from finished ride
  UPDATE driver_locations SET ride_id = NULL WHERE driver_id = p_driver_id;

  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'trip_completed', 'driver');
  RETURN jsonb_build_object('success', true, 'status', 'completed', 'fare', r.fare);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: cancel_ride_lifecycle  (rider or driver, tracks who)
-- =============================================================
CREATE OR REPLACE FUNCTION cancel_ride_lifecycle(
  p_ride_id UUID,
  p_by TEXT,
  p_reason TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  r rides%ROWTYPE;
  v_is_rider BOOLEAN;
  v_is_driver BOOLEAN;
BEGIN
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;
  v_is_rider := (r.rider_id = auth.uid());
  v_is_driver := EXISTS (SELECT 1 FROM drivers WHERE id = r.driver_id AND user_id = auth.uid());
  IF NOT (v_is_rider OR v_is_driver) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  IF r.status IN ('completed','cancelled') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;

  UPDATE rides SET status = 'cancelled', cancelled_at = NOW(),
    cancellation_reason = p_reason,
    cancelled_by = CASE WHEN p_by IN ('rider','driver','system') THEN p_by
                        WHEN v_is_driver THEN 'driver' ELSE 'rider' END
  WHERE id = p_ride_id;

  UPDATE ride_requests SET status = 'expired', responded_at = NOW()
    WHERE ride_id = p_ride_id AND status = 'offered';
  UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;

  INSERT INTO trip_events (ride_id, event_type, actor)
    VALUES (p_ride_id, 'cancelled', CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END);
  RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: rate_passenger  (driver rates rider after completion)
-- =============================================================
CREATE OR REPLACE FUNCTION rate_passenger(
  p_ride_id UUID,
  p_driver_id UUID,
  p_stars INTEGER,
  p_comment TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  UPDATE rides SET driver_rating = p_stars, driver_feedback = p_comment WHERE id = p_ride_id;
  INSERT INTO ride_ratings (ride_id, rater_id, ratee_role, stars, comment)
    VALUES (p_ride_id, auth.uid(), 'rider', p_stars, p_comment)
  ON CONFLICT (ride_id, rater_id) DO UPDATE
    SET stars = EXCLUDED.stars, comment = EXCLUDED.comment;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: driver_dashboard_stats  (aggregated performance)
-- =============================================================
CREATE OR REPLACE FUNCTION driver_dashboard_stats(
  p_driver_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_owner UUID;
  v_today_rides INTEGER;
  v_today_earnings DECIMAL(10,2);
  v_week_earnings DECIMAL(10,2);
  v_balance DECIMAL(10,2);
  v_pending_withdrawals DECIMAL(10,2);
  v_total_trips INTEGER;
  v_rating DECIMAL(3,2);
  v_acceptance NUMERIC;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  SELECT COUNT(*) INTO v_today_rides FROM rides
    WHERE driver_id = p_driver_id AND status = 'completed'
      AND completed_at >= date_trunc('day', NOW());

  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings FROM driver_earnings
    WHERE driver_id = p_driver_id AND type IN ('trip','bonus','tip')
      AND created_at >= date_trunc('day', NOW());

  SELECT COALESCE(SUM(amount), 0) INTO v_week_earnings FROM driver_earnings
    WHERE driver_id = p_driver_id AND type IN ('trip','bonus','tip')
      AND created_at >= date_trunc('week', NOW());

  SELECT COALESCE(earnings_balance, 0), COALESCE(total_trips, 0), COALESCE(rating, 0)
    INTO v_balance, v_total_trips, v_rating FROM drivers WHERE id = p_driver_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals FROM withdrawal_requests
    WHERE driver_id = p_driver_id AND status IN ('pending','approved');

  SELECT CASE WHEN COUNT(*) = 0 THEN 100
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'accepted') / COUNT(*), 0)
         END INTO v_acceptance
    FROM ride_requests WHERE driver_id = p_driver_id
      AND status IN ('accepted','rejected','expired');

  RETURN jsonb_build_object(
    'success', true,
    'today_rides', v_today_rides,
    'today_earnings', v_today_earnings,
    'week_earnings', v_week_earnings,
    'balance', v_balance,
    'pending_withdrawals', v_pending_withdrawals,
    'total_trips', v_total_trips,
    'rating', v_rating,
    'acceptance_rate', v_acceptance
  );
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RPC: request_withdrawal  (driver cashes out earnings)
-- =============================================================
CREATE OR REPLACE FUNCTION request_withdrawal(
  p_driver_id UUID,
  p_amount DOUBLE PRECISION,
  p_method TEXT DEFAULT 'bank'
) RETURNS JSONB AS $$
DECLARE
  v_owner UUID;
  v_balance DECIMAL(10,2);
  v_id UUID;
BEGIN
  SELECT user_id, COALESCE(earnings_balance, 0) INTO v_owner, v_balance
    FROM drivers WHERE id = p_driver_id FOR UPDATE;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  IF p_amount <= 0 OR p_amount > v_balance THEN
    RETURN jsonb_build_object('success', false, 'reason', 'insufficient_balance');
  END IF;

  INSERT INTO withdrawal_requests (driver_id, amount, status, method)
    VALUES (p_driver_id, p_amount, 'pending', p_method)
    RETURNING id INTO v_id;
  INSERT INTO driver_earnings (driver_id, type, amount, description)
    VALUES (p_driver_id, 'withdrawal', -p_amount, 'Withdrawal request');
  UPDATE drivers SET earnings_balance = earnings_balance - p_amount WHERE id = p_driver_id;

  RETURN jsonb_build_object('success', true, 'withdrawal_id', v_id);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- RLS: allow ride participants (rider + assigned driver) to
-- read the ride row for tracking; drivers to read offered rides.
-- =============================================================
DROP POLICY IF EXISTS "rides rider rw" ON rides;
DROP POLICY IF EXISTS "rides participant read" ON rides;
CREATE POLICY "rides participant read" ON rides FOR SELECT
  USING (
    rider_id = auth.uid()
    OR driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid())
    OR id IN (
      SELECT ride_id FROM ride_requests
      WHERE driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid())
    )
  );
DROP POLICY IF EXISTS "rides rider write" ON rides;
CREATE POLICY "rides rider write" ON rides FOR INSERT
  WITH CHECK (rider_id = auth.uid());
DROP POLICY IF EXISTS "rides rider update" ON rides;
CREATE POLICY "rides rider update" ON rides FOR UPDATE
  USING (rider_id = auth.uid())
  WITH CHECK (rider_id = auth.uid());

-- ensure realtime publishes rides + ride_requests + driver_locations
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND tablename = 'rides') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE rides;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND tablename = 'ride_requests') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE ride_requests;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND tablename = 'driver_locations') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE driver_locations;
  END IF;
END $$;
