-- =============================================================
-- Migration 007: Transportation Platform (Ride-Hailing Ecosystem)
-- =============================================================
-- Extends the existing drivers/rides schema with the full
-- ride-hailing domain: vehicles, documents, ride requests,
-- trip lifecycle events, earnings, ratings, complaints,
-- realtime driver locations, saved places, trusted contacts,
-- and promo codes. Includes RLS, indexes, dispatch/pricing RPCs.
-- Idempotent: safe to re-run.
-- =============================================================

-- --- PostGIS-free geo helper (haversine, km) -----------------
CREATE OR REPLACE FUNCTION haversine_km(
  lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
DECLARE
  r DOUBLE PRECISION := 6371;
  dlat DOUBLE PRECISION := radians(lat2 - lat1);
  dlon DOUBLE PRECISION := radians(lon2 - lon1);
  a DOUBLE PRECISION;
BEGIN
  a := sin(dlat / 2) * sin(dlat / 2)
     + cos(radians(lat1)) * cos(radians(lat2))
     * sin(dlon / 2) * sin(dlon / 2);
  RETURN r * 2 * asin(least(1, sqrt(a)));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- --- Extend ride_type / status enums on rides ----------------
ALTER TABLE rides DROP CONSTRAINT IF EXISTS rides_ride_type_check;
ALTER TABLE rides ADD CONSTRAINT rides_ride_type_check
  CHECK (ride_type IN ('economy','comfort','premium','xl','motorbike','taxi'));

ALTER TABLE rides DROP CONSTRAINT IF EXISTS rides_status_check;
ALTER TABLE rides ADD CONSTRAINT rides_status_check
  CHECK (status IN ('searching','matched','arrived','inTrip','completed','cancelled'));

-- --- New columns on rides (pricing breakdown, OTP, promo) -----
ALTER TABLE rides ADD COLUMN IF NOT EXISTS base_fare DECIMAL(10,2);
ALTER TABLE rides ADD COLUMN IF NOT EXISTS distance_fare DECIMAL(10,2);
ALTER TABLE rides ADD COLUMN IF NOT EXISTS time_fare DECIMAL(10,2);
ALTER TABLE rides ADD COLUMN IF NOT EXISTS surge_multiplier DECIMAL(4,2) DEFAULT 1.0;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10,2) DEFAULT 0;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS promo_code TEXT;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash'
  CHECK (payment_method IN ('cash','card','wallet'));
ALTER TABLE rides ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending'
  CHECK (payment_status IN ('pending','paid','failed','refunded'));
ALTER TABLE rides ADD COLUMN IF NOT EXISTS pickup_otp TEXT;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'EGP';

-- --- Extend drivers (documents state, active vehicle) --------
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending'
  CHECK (verification_status IN ('pending','verified','rejected'));
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS active_vehicle_id UUID;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS total_trips INTEGER DEFAULT 0;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMPTZ;

-- --- Vehicles ------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  category TEXT NOT NULL DEFAULT 'economy'
    CHECK (category IN ('economy','comfort','premium','xl','motorbike','taxi')),
  make TEXT,
  model TEXT,
  year INTEGER,
  color TEXT,
  plate_number TEXT NOT NULL,
  seats INTEGER DEFAULT 4,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

-- --- Driver documents ----------------------------------------
CREATE TABLE IF NOT EXISTS driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL
    CHECK (doc_type IN ('identity','driving_license','vehicle_registration','insurance')),
  file_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','verified','rejected')),
  rejection_reason TEXT,
  expires_at DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ
);
ALTER TABLE driver_documents ENABLE ROW LEVEL SECURITY;

-- --- Ride requests (dispatch queue) --------------------------
CREATE TABLE IF NOT EXISTS ride_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'offered'
    CHECK (status IN ('offered','accepted','rejected','expired')),
  distance_km DECIMAL(10,4),
  offered_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '20 seconds'),
  UNIQUE (ride_id, driver_id)
);
ALTER TABLE ride_requests ENABLE ROW LEVEL SECURITY;

-- --- Trip lifecycle events (audit log) -----------------------
CREATE TABLE IF NOT EXISTS trip_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  actor TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE trip_events ENABLE ROW LEVEL SECURITY;

-- --- Driver earnings ledger ----------------------------------
CREATE TABLE IF NOT EXISTS driver_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
  type TEXT NOT NULL DEFAULT 'trip'
    CHECK (type IN ('trip','bonus','tip','withdrawal','adjustment')),
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'EGP',
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE driver_earnings ENABLE ROW LEVEL SECURITY;

-- --- Withdrawal requests -------------------------------------
CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','paid')),
  method TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- --- Ride ratings --------------------------------------------
CREATE TABLE IF NOT EXISTS ride_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  rater_id UUID REFERENCES users(id),
  ratee_role TEXT CHECK (ratee_role IN ('driver','rider')),
  stars INTEGER NOT NULL CHECK (stars >= 1 AND stars <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (ride_id, rater_id)
);
ALTER TABLE ride_ratings ENABLE ROW LEVEL SECURITY;

-- --- Complaints ----------------------------------------------
CREATE TABLE IF NOT EXISTS complaints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
  reporter_id UUID REFERENCES users(id),
  category TEXT,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','investigating','resolved','dismissed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);
ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;

-- --- Realtime driver locations -------------------------------
CREATE TABLE IF NOT EXISTS driver_locations (
  driver_id UUID PRIMARY KEY REFERENCES drivers(id) ON DELETE CASCADE,
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  heading DECIMAL(6,2),
  speed DECIMAL(6,2),
  ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;

-- --- Saved places (home / work / favorites) ------------------
CREATE TABLE IF NOT EXISTS saved_places (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  place_type TEXT DEFAULT 'favorite'
    CHECK (place_type IN ('home','work','favorite')),
  address TEXT NOT NULL,
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE saved_places ENABLE ROW LEVEL SECURITY;

-- --- Trusted contacts (safety) -------------------------------
CREATE TABLE IF NOT EXISTS trusted_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE trusted_contacts ENABLE ROW LEVEL SECURITY;

-- --- Favorite drivers ----------------------------------------
CREATE TABLE IF NOT EXISTS favorite_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, driver_id)
);
ALTER TABLE favorite_drivers ENABLE ROW LEVEL SECURITY;

-- --- Promo codes ---------------------------------------------
CREATE TABLE IF NOT EXISTS promo_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  discount_type TEXT NOT NULL DEFAULT 'percentage'
    CHECK (discount_type IN ('percentage','fixed')),
  discount_value DECIMAL(10,2) NOT NULL,
  max_discount DECIMAL(10,2),
  min_fare DECIMAL(10,2) DEFAULT 0,
  usage_limit INTEGER,
  used_count INTEGER DEFAULT 0,
  per_user_limit INTEGER DEFAULT 1,
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  valid_until TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE promo_codes ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS promo_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_id UUID NOT NULL REFERENCES promo_codes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE promo_redemptions ENABLE ROW LEVEL SECURITY;

-- --- Ride pricing configuration (per category) ---------------
CREATE TABLE IF NOT EXISTS ride_pricing (
  category TEXT PRIMARY KEY
    CHECK (category IN ('economy','comfort','premium','xl','motorbike','taxi')),
  base_fare DECIMAL(10,2) NOT NULL,
  per_km DECIMAL(10,2) NOT NULL,
  per_minute DECIMAL(10,2) NOT NULL,
  minimum_fare DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'EGP',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE ride_pricing ENABLE ROW LEVEL SECURITY;

INSERT INTO ride_pricing (category, base_fare, per_km, per_minute, minimum_fare) VALUES
  ('economy',   10.0, 3.5, 0.5, 15.0),
  ('comfort',   15.0, 4.5, 0.7, 22.0),
  ('premium',   25.0, 6.0, 1.0, 35.0),
  ('xl',        20.0, 5.5, 0.9, 30.0),
  ('motorbike',  6.0, 2.0, 0.3,  8.0),
  ('taxi',      12.0, 4.0, 0.6, 18.0)
ON CONFLICT (category) DO NOTHING;

-- --- Indexes -------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_rides_rider ON rides(rider_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status);
CREATE INDEX IF NOT EXISTS idx_ride_requests_driver ON ride_requests(driver_id, status);
CREATE INDEX IF NOT EXISTS idx_ride_requests_ride ON ride_requests(ride_id);
CREATE INDEX IF NOT EXISTS idx_trip_events_ride ON trip_events(ride_id);
CREATE INDEX IF NOT EXISTS idx_driver_earnings_driver ON driver_earnings(driver_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_driver ON vehicles(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_documents_driver ON driver_documents(driver_id);
CREATE INDEX IF NOT EXISTS idx_saved_places_user ON saved_places(user_id);
CREATE INDEX IF NOT EXISTS idx_driver_locations_ride ON driver_locations(ride_id);
CREATE INDEX IF NOT EXISTS idx_drivers_online ON drivers(is_online, is_verified);

-- =============================================================
-- RLS POLICIES
-- =============================================================
-- vehicles
DROP POLICY IF EXISTS "vehicles owner rw" ON vehicles;
CREATE POLICY "vehicles owner rw" ON vehicles FOR ALL
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()))
  WITH CHECK (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

-- driver_documents
DROP POLICY IF EXISTS "driver docs owner rw" ON driver_documents;
CREATE POLICY "driver docs owner rw" ON driver_documents FOR ALL
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()))
  WITH CHECK (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

-- ride_requests: driver sees own offers
DROP POLICY IF EXISTS "ride requests driver" ON ride_requests;
CREATE POLICY "ride requests driver" ON ride_requests FOR ALL
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()))
  WITH CHECK (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

-- trip_events: rider or driver of the ride can view/insert
DROP POLICY IF EXISTS "trip events participants" ON trip_events;
CREATE POLICY "trip events participants" ON trip_events FOR ALL
  USING (ride_id IN (
    SELECT id FROM rides WHERE rider_id = auth.uid()
      OR driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid())
  ))
  WITH CHECK (ride_id IN (
    SELECT id FROM rides WHERE rider_id = auth.uid()
      OR driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid())
  ));

-- driver_earnings: owner read
DROP POLICY IF EXISTS "earnings owner read" ON driver_earnings;
CREATE POLICY "earnings owner read" ON driver_earnings FOR SELECT
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

-- withdrawal_requests: owner rw
DROP POLICY IF EXISTS "withdrawals owner rw" ON withdrawal_requests;
CREATE POLICY "withdrawals owner rw" ON withdrawal_requests FOR ALL
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()))
  WITH CHECK (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));

-- ride_ratings: rater rw, participants read
DROP POLICY IF EXISTS "ratings rater rw" ON ride_ratings;
CREATE POLICY "ratings rater rw" ON ride_ratings FOR ALL
  USING (rater_id = auth.uid())
  WITH CHECK (rater_id = auth.uid());
DROP POLICY IF EXISTS "ratings public read" ON ride_ratings;
CREATE POLICY "ratings public read" ON ride_ratings FOR SELECT USING (true);

-- complaints: reporter rw
DROP POLICY IF EXISTS "complaints reporter rw" ON complaints;
CREATE POLICY "complaints reporter rw" ON complaints FOR ALL
  USING (reporter_id = auth.uid())
  WITH CHECK (reporter_id = auth.uid());

-- driver_locations: driver writes own; any authenticated reads (needed for live tracking)
DROP POLICY IF EXISTS "driver location owner write" ON driver_locations;
CREATE POLICY "driver location owner write" ON driver_locations FOR ALL
  USING (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()))
  WITH CHECK (driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "driver location read" ON driver_locations;
CREATE POLICY "driver location read" ON driver_locations FOR SELECT
  USING (auth.role() = 'authenticated');

-- saved_places / trusted_contacts / favorite_drivers: owner rw
DROP POLICY IF EXISTS "saved places owner rw" ON saved_places;
CREATE POLICY "saved places owner rw" ON saved_places FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "trusted contacts owner rw" ON trusted_contacts;
CREATE POLICY "trusted contacts owner rw" ON trusted_contacts FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "favorite drivers owner rw" ON favorite_drivers;
CREATE POLICY "favorite drivers owner rw" ON favorite_drivers FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- promo_codes / ride_pricing: public read
DROP POLICY IF EXISTS "promo public read" ON promo_codes;
CREATE POLICY "promo public read" ON promo_codes FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "pricing public read" ON ride_pricing;
CREATE POLICY "pricing public read" ON ride_pricing FOR SELECT USING (true);
DROP POLICY IF EXISTS "promo redemptions owner rw" ON promo_redemptions;
CREATE POLICY "promo redemptions owner rw" ON promo_redemptions FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- =============================================================
-- PRICING RPC: estimate_fare
-- =============================================================
CREATE OR REPLACE FUNCTION estimate_fare(
  p_category TEXT,
  p_distance_km DOUBLE PRECISION,
  p_duration_min DOUBLE PRECISION,
  p_surge DOUBLE PRECISION DEFAULT 1.0
) RETURNS JSONB AS $$
DECLARE
  cfg ride_pricing%ROWTYPE;
  base DECIMAL(10,2);
  dist DECIMAL(10,2);
  tim DECIMAL(10,2);
  subtotal DECIMAL(10,2);
  total DECIMAL(10,2);
BEGIN
  SELECT * INTO cfg FROM ride_pricing WHERE category = p_category;
  IF NOT FOUND THEN
    SELECT * INTO cfg FROM ride_pricing WHERE category = 'economy';
  END IF;
  base := cfg.base_fare;
  dist := (cfg.per_km * p_distance_km)::DECIMAL(10,2);
  tim  := (cfg.per_minute * p_duration_min)::DECIMAL(10,2);
  subtotal := base + dist + tim;
  total := GREATEST(subtotal * p_surge, cfg.minimum_fare)::DECIMAL(10,2);
  RETURN jsonb_build_object(
    'base_fare', base,
    'distance_fare', dist,
    'time_fare', tim,
    'surge_multiplier', p_surge,
    'subtotal', subtotal,
    'total', total,
    'minimum_fare', cfg.minimum_fare,
    'currency', cfg.currency
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================
-- DISPATCH RPC: find_nearest_drivers
-- Returns online, verified drivers within radius, nearest first.
-- =============================================================
CREATE OR REPLACE FUNCTION find_nearest_drivers(
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION,
  p_category TEXT DEFAULT NULL,
  p_radius_km DOUBLE PRECISION DEFAULT 8,
  p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
  driver_id UUID,
  full_name TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  distance_km DOUBLE PRECISION,
  rating DECIMAL(3,2)
) AS $$
BEGIN
  RETURN QUERY
  SELECT d.id, d.full_name, dl.latitude, dl.longitude,
         haversine_km(p_lat, p_lon, dl.latitude::DOUBLE PRECISION, dl.longitude::DOUBLE PRECISION) AS distance_km,
         d.rating
  FROM drivers d
  JOIN driver_locations dl ON dl.driver_id = d.id
  WHERE d.is_online = true
    AND d.is_verified = true
    AND (p_category IS NULL OR EXISTS (
      SELECT 1 FROM vehicles v
      WHERE v.driver_id = d.id AND v.is_active = true AND v.category = p_category
    ))
    AND haversine_km(p_lat, p_lon, dl.latitude::DOUBLE PRECISION, dl.longitude::DOUBLE PRECISION) <= p_radius_km
    AND NOT EXISTS (
      SELECT 1 FROM rides r
      WHERE r.driver_id = d.id AND r.status IN ('matched','arrived','inTrip')
    )
  ORDER BY distance_km ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================
-- TRIP LIFECYCLE RPC: accept_ride (atomic driver assignment)
-- =============================================================
CREATE OR REPLACE FUNCTION accept_ride(
  p_ride_id UUID,
  p_driver_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_otp TEXT;
  v_status TEXT;
  drv drivers%ROWTYPE;
BEGIN
  SELECT status INTO v_status FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF v_status IS DISTINCT FROM 'searching' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_unavailable');
  END IF;
  SELECT * INTO drv FROM drivers WHERE id = p_driver_id;
  v_otp := lpad((floor(random() * 10000))::INT::TEXT, 4, '0');
  UPDATE rides SET
    driver_id = p_driver_id,
    driver_name = drv.full_name,
    driver_phone = drv.phone,
    vehicle_type = drv.vehicle_type,
    vehicle_plate = drv.vehicle_plate,
    vehicle_color = drv.vehicle_color,
    status = 'matched',
    matched_at = NOW(),
    pickup_otp = v_otp
  WHERE id = p_ride_id;
  UPDATE ride_requests SET status = 'accepted', responded_at = NOW()
    WHERE ride_id = p_ride_id AND driver_id = p_driver_id;
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'matched', 'driver');
  RETURN jsonb_build_object('success', true, 'otp', v_otp);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- TRIP LIFECYCLE RPC: advance_ride (state machine)
-- =============================================================
CREATE OR REPLACE FUNCTION advance_ride(
  p_ride_id UUID,
  p_new_status TEXT,
  p_otp TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  r rides%ROWTYPE;
BEGIN
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;

  IF p_new_status = 'arrived' AND r.status = 'matched' THEN
    UPDATE rides SET status = 'arrived', arrived_at = NOW() WHERE id = p_ride_id;
  ELSIF p_new_status = 'inTrip' AND r.status = 'arrived' THEN
    IF r.pickup_otp IS NOT NULL AND p_otp IS DISTINCT FROM r.pickup_otp THEN
      RETURN jsonb_build_object('success', false, 'reason', 'invalid_otp');
    END IF;
    UPDATE rides SET status = 'inTrip', started_at = NOW() WHERE id = p_ride_id;
  ELSIF p_new_status = 'completed' AND r.status = 'inTrip' THEN
    UPDATE rides SET status = 'completed', completed_at = NOW(), payment_status = 'paid'
      WHERE id = p_ride_id;
    -- credit driver earnings
    IF r.driver_id IS NOT NULL AND r.fare IS NOT NULL THEN
      INSERT INTO driver_earnings (driver_id, ride_id, type, amount, description)
        VALUES (r.driver_id, p_ride_id, 'trip', r.fare, 'Trip fare');
      UPDATE drivers SET
        earnings_balance = earnings_balance + r.fare,
        total_trips = total_trips + 1
      WHERE id = r.driver_id;
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;

  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, p_new_status, 'system');
  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- PROMO RPC: validate_promo
-- =============================================================
CREATE OR REPLACE FUNCTION validate_promo(
  p_code TEXT,
  p_user_id UUID,
  p_fare DOUBLE PRECISION
) RETURNS JSONB AS $$
DECLARE
  pc promo_codes%ROWTYPE;
  used INTEGER;
  discount DECIMAL(10,2);
BEGIN
  SELECT * INTO pc FROM promo_codes
    WHERE code = upper(p_code) AND is_active = true
      AND (valid_until IS NULL OR valid_until > NOW())
      AND valid_from <= NOW();
  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'invalid');
  END IF;
  IF pc.min_fare > p_fare THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'min_fare');
  END IF;
  IF pc.usage_limit IS NOT NULL AND pc.used_count >= pc.usage_limit THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'exhausted');
  END IF;
  SELECT COUNT(*) INTO used FROM promo_redemptions
    WHERE promo_id = pc.id AND user_id = p_user_id;
  IF used >= pc.per_user_limit THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'already_used');
  END IF;
  IF pc.discount_type = 'percentage' THEN
    discount := (p_fare * pc.discount_value / 100)::DECIMAL(10,2);
  ELSE
    discount := pc.discount_value;
  END IF;
  IF pc.max_discount IS NOT NULL THEN
    discount := LEAST(discount, pc.max_discount);
  END IF;
  discount := LEAST(discount, p_fare::DECIMAL(10,2));
  RETURN jsonb_build_object('valid', true, 'discount', discount, 'promo_id', pc.id);
END;
$$ LANGUAGE plpgsql STABLE;

-- Seed a sample promo (safe, inactive if exists)
INSERT INTO promo_codes (code, discount_type, discount_value, max_discount, min_fare, usage_limit, per_user_limit, is_active)
VALUES ('WELCOME20', 'percentage', 20, 30, 20, 10000, 1, true)
ON CONFLICT (code) DO NOTHING;
