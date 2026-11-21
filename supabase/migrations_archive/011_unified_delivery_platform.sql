-- M7: Unified Delivery & Logistics Platform
-- Extends the rides-based dispatch engine to support all delivery services.
-- PRINCIPLE: No duplicate tables. The rides table IS the unified dispatch table.

-- ============================================================
-- 1. SERVICE TYPE ON RIDES
-- ============================================================
-- Adds a service_type column to distinguish ride-hailing from delivery services.
-- The same dispatch engine, driver platform, wallet, and realtime power both.

ALTER TABLE rides ADD COLUMN IF NOT EXISTS service_type TEXT DEFAULT 'ride'
  CHECK (service_type IN (
    'ride',
    'food_delivery',
    'grocery_delivery',
    'pharmacy_delivery',
    'marketplace_delivery',
    'courier',
    'package_delivery',
    'document_delivery',
    'flower_delivery',
    'retail_delivery'
  ));

ALTER TABLE rides ADD COLUMN IF NOT EXISTS merchant_id UUID REFERENCES merchants(id);
ALTER TABLE rides ADD COLUMN IF NOT EXISTS pickup_notes TEXT;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS dropoff_notes TEXT;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS delivery_proof_url TEXT;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS signature_required BOOLEAN DEFAULT false;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS otp_required BOOLEAN DEFAULT true;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'standard'
  CHECK (priority IN ('standard', 'priority', 'express'));
ALTER TABLE rides ADD COLUMN IF NOT EXISTS items_summary TEXT;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS weight_kg DECIMAL(6,2);

-- Index for delivery queries
CREATE INDEX IF NOT EXISTS idx_rides_service_type ON rides(service_type);
CREATE INDEX IF NOT EXISTS idx_rides_merchant_id ON rides(merchant_id);
CREATE INDEX IF NOT EXISTS idx_rides_status_service ON rides(status, service_type);

-- ============================================================
-- 2. DRIVER SERVICE CAPABILITIES
-- ============================================================
-- Extend drivers to support multi-service capabilities.

ALTER TABLE drivers ADD COLUMN IF NOT EXISTS service_types TEXT[] DEFAULT ARRAY['ride']::TEXT[];
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS accepts_deliveries BOOLEAN DEFAULT false;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS max_delivery_distance_km DECIMAL(6,2) DEFAULT 15;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS max_weight_kg DECIMAL(6,2) DEFAULT 20;

-- ============================================================
-- 3. DELIVERY PRICING
-- ============================================================
-- Separate pricing table for delivery services (extends ride_pricing pattern).

CREATE TABLE IF NOT EXISTS delivery_pricing (
  service_type TEXT PRIMARY KEY,
  base_fee DECIMAL(10,2) NOT NULL,
  per_km DECIMAL(10,2) NOT NULL,
  per_kg DECIMAL(10,2) DEFAULT 0,
  minimum_fee DECIMAL(10,2) NOT NULL,
  priority_multiplier DECIMAL(4,2) DEFAULT 1.0,
  express_multiplier DECIMAL(4,2) DEFAULT 1.5,
  currency TEXT DEFAULT 'EGP',
  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed delivery pricing for all service types
INSERT INTO delivery_pricing (service_type, base_fee, per_km, per_kg, minimum_fee, priority_multiplier, express_multiplier) VALUES
  ('food_delivery',       8.00, 3.00, 0.50, 12.00, 1.3, 1.8),
  ('grocery_delivery',    10.00, 3.50, 1.00, 15.00, 1.3, 1.8),
  ('pharmacy_delivery',   7.00, 2.50, 0.30, 10.00, 1.5, 2.0),
  ('marketplace_delivery', 12.00, 4.00, 1.50, 18.00, 1.3, 1.8),
  ('courier',             15.00, 5.00, 2.00, 20.00, 1.2, 1.5),
  ('package_delivery',    10.00, 3.50, 1.00, 15.00, 1.2, 1.5),
  ('document_delivery',   6.00, 2.00, 0.00, 8.00, 1.3, 1.8),
  ('flower_delivery',     9.00, 3.00, 0.50, 12.00, 1.3, 1.8),
  ('retail_delivery',     10.00, 3.50, 1.00, 15.00, 1.3, 1.8)
ON CONFLICT (service_type) DO NOTHING;

ALTER TABLE delivery_pricing ENABLE ROW LEVEL SECURITY;
CREATE POLICY "delivery pricing public read" ON delivery_pricing FOR SELECT USING (true);

ALTER PUBLICATION supabase_realtime ADD TABLE delivery_pricing;

-- ============================================================
-- 4. MERCHANT CONFIGURATION TABLE
-- ============================================================
-- Merchants that can request deliveries through the platform.

CREATE TABLE IF NOT EXISTS merchant_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  service_types TEXT[] DEFAULT ARRAY['food_delivery']::TEXT[],
  accepts_direct_dispatch BOOLEAN DEFAULT true,
  average_prep_time_minutes INTEGER DEFAULT 15,
  max_delivery_radius_km DECIMAL(6,2) DEFAULT 5.0,
  auto_accept_orders BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(merchant_id)
);

ALTER TABLE merchant_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "merchant profiles owner rw" ON merchant_profiles
  FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- 5. DELIVERY DISPATCH RPCs
-- ============================================================
-- Uses the same pattern as ride dispatch but adapted for deliveries.
-- Drivers who accept_deliveries=true receive delivery requests.

-- Dispatch a delivery: find nearest drivers who accept deliveries
CREATE OR REPLACE FUNCTION dispatch_delivery(
  p_ride_id UUID,
  p_radius_km DECIMAL DEFAULT 10,
  p_limit INTEGER DEFAULT 5
) RETURNS JSONB AS $$
DECLARE
  v_ride RECORD;
  v_request RECORD;
  v_driver RECORD;
  v_offered_count INTEGER := 0;
  v_found_any BOOLEAN := false;
BEGIN
  SELECT * INTO v_ride FROM rides WHERE id = p_ride_id;
  IF v_ride IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;
  IF v_ride.status != 'searching' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_searching');
  END IF;

  FOR v_driver IN
    SELECT d.id, d.user_id,
      haversine_km(v_ride.pickup_latitude, v_ride.pickup_longitude,
                   d.current_latitude, d.current_longitude) AS dist_km
    FROM drivers d
    WHERE d.status = 'online'
      AND d.is_verified = true
      AND d.active_vehicle_id IS NOT NULL
      AND d.active_vehicle_id IN (
        SELECT v.id FROM vehicles v
        WHERE v.driver_id = d.id
          AND v.is_active = true
          AND (v.category = v_ride.ride_type OR v_ride.service_type != 'ride')
      )
      AND (d.accepts_deliveries = true OR v_ride.service_type = 'ride')
      AND d.current_latitude IS NOT NULL
      AND d.current_longitude IS NOT NULL
      AND haversine_km(v_ride.pickup_latitude, v_ride.pickup_longitude,
                       d.current_latitude, d.current_longitude) <= p_radius_km
    ORDER BY dist_km ASC
    LIMIT p_limit
  LOOP
    BEGIN
      INSERT INTO ride_requests (ride_id, driver_id, status, distance_km, offered_at, expires_at)
      VALUES (
        p_ride_id, v_driver.id, 'offered', v_driver.dist_km,
        NOW(), NOW() + interval '20 seconds'
      );
      v_offered_count := v_offered_count + 1;
      v_found_any := true;
    EXCEPTION WHEN unique_violation THEN
      NULL;
    END;
  END LOOP;

  IF NOT v_found_any THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_drivers_available');
  END IF;

  RETURN jsonb_build_object('success', true, 'offered_to', v_offered_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Complete a delivery (extends complete_trip with proof)
CREATE OR REPLACE FUNCTION complete_delivery(
  p_ride_id UUID,
  p_driver_id UUID,
  p_proof_url TEXT DEFAULT NULL,
  p_final_distance DECIMAL DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_fare DECIMAL;
  v_ride RECORD;
BEGIN
  SELECT * INTO v_ride FROM rides WHERE id = p_ride_id AND driver_id = p_driver_id AND status = 'inTrip';
  IF v_ride IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;

  UPDATE rides SET
    status = 'completed',
    completed_at = NOW(),
    distance = COALESCE(p_final_distance, distance),
    delivery_proof_url = p_proof_url
  WHERE id = p_ride_id RETURNING fare INTO v_fare;

  UPDATE drivers SET
    total_trips = total_trips + 1,
    earnings_balance = earnings_balance + COALESCE(v_fare, 0)
  WHERE id = p_driver_id;

  INSERT INTO driver_earnings (driver_id, ride_id, type, amount, description)
  VALUES (p_driver_id, p_ride_id, 'trip', COALESCE(v_fare, 0), 'Delivery completed');

  UPDATE driver_locations SET ride_id = NULL WHERE driver_id = p_driver_id;

  RETURN jsonb_build_object('success', true, 'fare', COALESCE(v_fare, 0));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 6. DELIVERY PRICING RPC
-- ============================================================

CREATE OR REPLACE FUNCTION estimate_delivery_fee(
  p_service_type TEXT,
  p_distance_km DECIMAL,
  p_weight_kg DECIMAL DEFAULT 1.0,
  p_priority TEXT DEFAULT 'standard'
) RETURNS JSONB AS $$
DECLARE
  v_pricing RECORD;
  v_fee DECIMAL;
  v_multiplier DECIMAL := 1.0;
BEGIN
  SELECT * INTO v_pricing FROM delivery_pricing WHERE service_type = p_service_type AND is_active = true;
  IF v_pricing IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'pricing_not_found');
  END IF;

  v_fee := v_pricing.base_fee + (v_pricing.per_km * p_distance_km) + (v_pricing.per_kg * p_weight_kg);

  IF p_priority = 'priority' THEN
    v_multiplier := v_pricing.priority_multiplier;
  ELSIF p_priority = 'express' THEN
    v_multiplier := v_pricing.express_multiplier;
  END IF;

  v_fee := v_fee * v_multiplier;

  IF v_fee < v_pricing.minimum_fee THEN
    v_fee := v_pricing.minimum_fee;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'fee', ROUND(v_fee, 2),
    'base_fee', v_pricing.base_fee,
    'distance_fee', ROUND(v_pricing.per_km * p_distance_km, 2),
    'weight_fee', ROUND(v_pricing.per_kg * p_weight_kg, 2),
    'multiplier', v_multiplier,
    'currency', v_pricing.currency
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 7. MERCHANT ORDER MANAGEMENT RPCs
-- ============================================================

-- Mark order as ready for pickup (triggers delivery dispatch)
CREATE OR REPLACE FUNCTION merchant_ready_for_dispatch(
  p_ride_id UUID,
  p_merchant_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_ride RECORD;
BEGIN
  SELECT * INTO v_ride FROM rides WHERE id = p_ride_id AND merchant_id = p_merchant_id;
  IF v_ride IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'order_not_found');
  END IF;
  IF v_ride.status != 'searching' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_dispatched');
  END IF;

  -- The merchant confirms the order is ready; dispatch engine takes over
  RETURN jsonb_build_object('success', true, 'ride_id', p_ride_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get merchant's active deliveries
CREATE OR REPLACE FUNCTION get_merchant_deliveries(
  p_merchant_id UUID,
  p_status TEXT DEFAULT NULL
) RETURNS SETOF rides AS $$
  SELECT * FROM rides
  WHERE merchant_id = p_merchant_id
    AND service_type != 'ride'
    AND (p_status IS NULL OR status = p_status)
  ORDER BY created_at DESC
  LIMIT 50;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
-- 8. DRIVER DELIVERY CAPABILITY MANAGEMENT
-- ============================================================

CREATE OR REPLACE FUNCTION update_driver_capabilities(
  p_driver_id UUID,
  p_service_types TEXT[],
  p_accepts_deliveries BOOLEAN DEFAULT true,
  p_max_delivery_distance DECIMAL DEFAULT 15,
  p_max_weight DECIMAL DEFAULT 20
) RETURNS JSONB AS $$
BEGIN
  UPDATE drivers SET
    service_types = p_service_types,
    accepts_deliveries = p_accepts_deliveries,
    max_delivery_distance_km = p_max_delivery_distance,
    max_weight_kg = p_max_weight,
    updated_at = NOW()
  WHERE id = p_driver_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 9. STORAGE BUCKETS for driver docs + delivery proof
-- ============================================================
-- These will be created via Supabase Storage API, documented here for reference.
-- Buckets: driver-documents, delivery-proofs, merchant-assets, profile-photos
-- RLS: authenticated read, owner write for driver-documents and profile-photos
