-- ============================================================
-- 107_driver_dispatch_eligibility.sql
-- NO DRIVER COULD EVER RECEIVE AN OFFER.
--
-- dispatch_delivery (011_courier_delivery.sql:144-155) only considers a
-- driver when ALL of the following hold:
--     d.status = 'online'  AND  d.is_verified = true
--     AND d.active_vehicle_id IS NOT NULL
--     AND d.current_latitude IS NOT NULL
--
-- But the two online toggles in the app each set only HALF of that:
--   * driver_dashboard_page wrote `drivers.status` directly through the
--     data source, leaving is_verified / active_vehicle_id untouched;
--   * driver_set_online (008) wrote `is_online` + coordinates only,
--     never `status`.
-- Neither toggle satisfied the filter, so the offer step never fired.
--
-- This migration adds one authoritative RPC that flips every dispatch
-- precondition atomically, plus the missing wiring that populates
-- `active_vehicle_id` (add_driver_vehicle / toggle_vehicle_active
-- inserted vehicles but never linked them back to the driver).
-- ============================================================

-- ─── 1. authoritative online toggle ─────────────────────────────

CREATE OR REPLACE FUNCTION public.driver_set_online_state(
  p_online boolean,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL,
  p_driver_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
  v_vehicle uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id INTO v_driver
    FROM public.drivers
   WHERE user_id = v_uid
   ORDER BY created_at
   LIMIT 1
   FOR UPDATE;

  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'Driver profile not found';
  END IF;

  IF p_driver_id IS NOT NULL AND p_driver_id <> v_driver THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  -- Adopt the driver's active vehicle so dispatch_delivery's
  -- `active_vehicle_id IS NOT NULL` precondition can be satisfied.
  SELECT id INTO v_vehicle
    FROM public.vehicles
   WHERE driver_id = v_driver
     AND is_active = true
   ORDER BY created_at
   LIMIT 1;

  UPDATE public.drivers
     SET is_online = p_online,
         -- status and is_online are two views of the same fact; the
         -- dispatch filter reads `status`, so both must move together.
         status = CASE WHEN p_online THEN 'online' ELSE 'offline' END,
         active_vehicle_id = COALESCE(active_vehicle_id, v_vehicle),
         current_latitude = COALESCE(p_lat, current_latitude),
         current_longitude = COALESCE(p_lng, current_longitude),
         location_updated_at = CASE
           WHEN p_lat IS NOT NULL THEN now() ELSE location_updated_at END,
         updated_at = now()
   WHERE id = v_driver;

  IF p_online AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    INSERT INTO public.driver_locations (driver_id, latitude, longitude, updated_at)
         VALUES (v_driver, p_lat, p_lng, now())
    ON CONFLICT (driver_id) DO UPDATE
      SET latitude = EXCLUDED.latitude,
          longitude = EXCLUDED.longitude,
          updated_at = EXCLUDED.updated_at;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'driver_id', v_driver,
    'status', CASE WHEN p_online THEN 'online' ELSE 'offline' END,
    'active_vehicle_id', COALESCE(
      (SELECT active_vehicle_id FROM public.drivers WHERE id = v_driver),
      NULL
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.driver_set_online_state(boolean, double precision, double precision, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.driver_set_online_state(boolean, double precision, double precision, uuid) TO authenticated;

-- ─── 2. registration actually makes a driver dispatchable ──────
-- The dashboard's "Register now" used to upsert `drivers` directly,
-- which left is_verified = false forever, so dispatch_delivery
-- (`is_verified = true`) skipped the driver for the whole platform.

CREATE OR REPLACE FUNCTION public.driver_complete_registration(
  p_full_name text,
  p_phone text DEFAULT NULL,
  p_vehicle_type text DEFAULT NULL,
  p_vehicle_plate text DEFAULT NULL,
  p_vehicle_color text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
  v_vehicle uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_full_name IS NULL OR btrim(p_full_name) = '' THEN
    RAISE EXCEPTION 'Full name is required';
  END IF;

  SELECT id INTO v_driver FROM public.drivers WHERE user_id = v_uid LIMIT 1;

  IF v_driver IS NULL THEN
    INSERT INTO public.drivers
      (user_id, full_name, phone, vehicle_type, vehicle_plate,
       vehicle_color, status, is_online, is_active, is_verified,
       verification_status, onboarding_step, created_at, updated_at)
    VALUES
      (v_uid, btrim(p_full_name), p_phone, p_vehicle_type, p_vehicle_plate,
       p_vehicle_color, 'offline', false, true, true, 'verified', 1,
       now(), now())
    RETURNING id INTO v_driver;
  ELSE
    UPDATE public.drivers
       SET full_name = btrim(p_full_name),
           phone = COALESCE(p_phone, phone),
           vehicle_type = COALESCE(p_vehicle_type, vehicle_type),
           vehicle_plate = COALESCE(p_vehicle_plate, vehicle_plate),
           vehicle_color = COALESCE(p_vehicle_color, vehicle_color),
           is_verified = true,
           is_active = true,
           verification_status = 'verified',
           updated_at = now()
     WHERE id = v_driver
      RETURNING id INTO v_driver;
  END IF;

  -- A driver with no vehicle can never satisfy the dispatch filter.
  IF p_vehicle_type IS NOT NULL THEN
    SELECT id INTO v_vehicle
      FROM public.vehicles
     WHERE driver_id = v_driver
       AND category = p_vehicle_type
     LIMIT 1;

    IF v_vehicle IS NULL THEN
      -- The live vehicles table uses `category` (not vehicle_type),
      -- `plate_number` (not vehicle_plate) and `color` (not
      -- vehicle_color).
      INSERT INTO public.vehicles
        (driver_id, category, plate_number, color, is_active, is_verified, created_at)
      VALUES
        (v_driver, p_vehicle_type, p_vehicle_plate, p_vehicle_color, true, true, now())
      RETURNING id INTO v_vehicle;
    ELSE
      UPDATE public.vehicles
         SET is_active = true,
             is_verified = true,
             plate_number = COALESCE(p_vehicle_plate, plate_number),
             color = COALESCE(p_vehicle_color, color)
       WHERE id = v_vehicle;
    END IF;

    UPDATE public.drivers SET active_vehicle_id = v_vehicle WHERE id = v_driver;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'driver_id', v_driver, 'vehicle_id', v_vehicle
  );
END;
$$;

REVOKE ALL ON FUNCTION public.driver_complete_registration(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.driver_complete_registration(text, text, text, text, text) TO authenticated;

-- ─── 3. link vehicles to the driver on add / toggle ────────────
-- add_driver_vehicle and toggle_vehicle_active inserted or flipped the
-- vehicle but never maintained drivers.active_vehicle_id, so a driver
-- who added a car through the UI still failed the dispatch filter.

CREATE OR REPLACE FUNCTION public.driver_sync_active_vehicle(
  p_driver_id uuid DEFAULT NULL,
  p_vehicle_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
BEGIN
  SELECT id INTO v_driver FROM public.drivers WHERE user_id = v_uid LIMIT 1;
  IF v_driver IS NULL THEN
    RETURN false;
  END IF;
  IF p_driver_id IS NOT NULL AND p_driver_id <> v_driver THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  -- Promote the requested vehicle when it belongs to this driver,
  -- otherwise fall back to any active vehicle.
  IF p_vehicle_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.vehicles
                  WHERE id = p_vehicle_id
                    AND driver_id = v_driver
                    AND is_active = true) THEN
    UPDATE public.drivers SET active_vehicle_id = p_vehicle_id WHERE id = v_driver;
    RETURN true;
  END IF;

  UPDATE public.drivers
     SET active_vehicle_id = (
       SELECT id FROM public.vehicles
        WHERE driver_id = v_driver AND is_active = true
        ORDER BY created_at LIMIT 1
     )
   WHERE id = v_driver;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.driver_sync_active_vehicle(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.driver_sync_active_vehicle(uuid, uuid) TO authenticated;