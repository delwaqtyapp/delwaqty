-- =============================================================
-- Migration 009: Driver Onboarding for Ride Dispatch (M4)
-- =============================================================
-- Adds a self-service onboarding RPC so a signed-in user can
-- become a ride driver with an active vehicle in a chosen
-- category, making them eligible for dispatch. Also adds the
-- legacy `status` column the delivery data source expects.
-- Idempotent: safe to re-run.
-- =============================================================

-- Legacy compatibility: delivery data source reads/writes drivers.status
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'offline';

-- Keep is_online in sync when status is toggled through legacy path
CREATE OR REPLACE FUNCTION sync_driver_online_from_status()
RETURNS TRIGGER AS $$
BEGIN
  NEW.is_online := (NEW.status = 'online');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_driver_status_sync ON drivers;
CREATE TRIGGER trg_driver_status_sync
  BEFORE UPDATE OF status ON drivers
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION sync_driver_online_from_status();

-- =============================================================
-- RPC: register_ride_driver
-- Ensures a drivers row for the caller and an active vehicle in
-- the requested category. In this build the driver is auto
-- verified so the full lifecycle is testable on device; in
-- production this is replaced by admin document verification.
-- =============================================================
CREATE OR REPLACE FUNCTION register_ride_driver(
  p_full_name TEXT,
  p_phone TEXT,
  p_category TEXT,
  p_make TEXT,
  p_model TEXT,
  p_color TEXT,
  p_plate TEXT,
  p_seats INTEGER DEFAULT 4
) RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_driver_id UUID;
  v_vehicle_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
  END IF;
  IF p_category NOT IN ('economy','comfort','premium','xl','motorbike','taxi') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_category');
  END IF;

  SELECT id INTO v_driver_id FROM drivers WHERE user_id = v_uid;
  IF v_driver_id IS NULL THEN
    INSERT INTO drivers (user_id, full_name, phone, vehicle_type, vehicle_model,
                         vehicle_color, vehicle_plate, is_online, is_verified,
                         verification_status, status, earnings_balance, rating,
                         total_trips)
      VALUES (v_uid, p_full_name, p_phone, p_category, p_make || ' ' || p_model,
              p_color, p_plate, false, true, 'verified', 'offline', 0, 5.0, 0)
      RETURNING id INTO v_driver_id;
  ELSE
    UPDATE drivers SET
      full_name = COALESCE(p_full_name, full_name),
      phone = COALESCE(p_phone, phone),
      is_verified = true,
      verification_status = 'verified'
    WHERE id = v_driver_id;
  END IF;

  SELECT id INTO v_vehicle_id FROM vehicles
    WHERE driver_id = v_driver_id AND category = p_category LIMIT 1;
  IF v_vehicle_id IS NULL THEN
    INSERT INTO vehicles (driver_id, category, make, model, color, plate_number,
                          seats, is_active)
      VALUES (v_driver_id, p_category, p_make, p_model, p_color, p_plate,
              p_seats, true)
      RETURNING id INTO v_vehicle_id;
  ELSE
    UPDATE vehicles SET make = p_make, model = p_model, color = p_color,
      plate_number = p_plate, seats = p_seats, is_active = true
    WHERE id = v_vehicle_id;
  END IF;

  UPDATE drivers SET active_vehicle_id = v_vehicle_id WHERE id = v_driver_id;

  RETURN jsonb_build_object('success', true, 'driver_id', v_driver_id,
                            'vehicle_id', v_vehicle_id);
END;
$$ LANGUAGE plpgsql;
