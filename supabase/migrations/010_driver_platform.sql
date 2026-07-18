-- M6: Complete Driver Platform
-- Extends drivers, vehicles, documents for full onboarding, vehicle management, wallet detail, performance metrics

-- ============================================================
-- 1. EXTEND DRIVERS TABLE
-- ============================================================
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS national_id_number TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS background_check_status TEXT DEFAULT 'not_started'
  CHECK (background_check_status IN ('not_started','pending','passed','failed'));
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS onboarding_step INTEGER DEFAULT 0;

-- ============================================================
-- 2. EXTEND VEHICLES TABLE
-- ============================================================
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS registration_expires_at DATE;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS insurance_expires_at DATE;

-- ============================================================
-- 3. EXTEND DRIVER_DOCUMENTS TABLE
-- ============================================================
-- Expand doc_type to include vehicle_photo and profile_photo
ALTER TABLE driver_documents DROP CONSTRAINT IF EXISTS driver_documents_doc_type_check;
ALTER TABLE driver_documents ADD CONSTRAINT driver_documents_doc_type_check
  CHECK (doc_type IN ('identity','driving_license','vehicle_registration','insurance','vehicle_photo','profile_photo'));
ALTER TABLE driver_documents ADD COLUMN IF NOT EXISTS file_name TEXT;
ALTER TABLE driver_documents ADD COLUMN IF NOT EXISTS file_size INTEGER;

-- ============================================================
-- 4. ONBOARDING RPCs
-- ============================================================

-- Save onboarding data step-by-step
CREATE OR REPLACE FUNCTION submit_driver_onboarding(
  p_driver_id UUID,
  p_full_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_national_id TEXT DEFAULT NULL,
  p_address TEXT DEFAULT NULL,
  p_profile_photo_url TEXT DEFAULT NULL,
  p_onboarding_step INTEGER DEFAULT 0
) RETURNS JSONB AS $$
BEGIN
  UPDATE drivers SET
    full_name = COALESCE(p_full_name, full_name),
    phone = COALESCE(p_phone, phone),
    national_id_number = COALESCE(p_national_id, national_id_number),
    address = COALESCE(p_address, address),
    profile_photo_url = COALESCE(p_profile_photo_url, profile_photo_url),
    onboarding_step = p_onboarding_step,
    updated_at = NOW()
  WHERE id = p_driver_id;
  RETURN jsonb_build_object('success', true, 'step', p_onboarding_step);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Mark onboarding as complete → status becomes pending_approval
CREATE OR REPLACE FUNCTION complete_driver_onboarding(p_driver_id UUID)
RETURNS JSONB AS $$
BEGIN
  UPDATE drivers SET
    onboarding_completed = true,
    onboarding_step = 5,
    verification_status = 'pending',
    updated_at = NOW()
  WHERE id = p_driver_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 5. DOCUMENT MANAGEMENT RPCs
-- ============================================================

-- Upsert a document (latest doc_type entry for driver wins)
CREATE OR REPLACE FUNCTION upsert_driver_document(
  p_driver_id UUID,
  p_doc_type TEXT,
  p_file_url TEXT,
  p_file_name TEXT DEFAULT NULL,
  p_file_size INTEGER DEFAULT NULL,
  p_expires_at DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_id UUID;
  v_existing UUID;
BEGIN
  SELECT id INTO v_existing FROM driver_documents
  WHERE driver_id = p_driver_id AND doc_type = p_doc_type
  ORDER BY created_at DESC LIMIT 1;

  IF v_existing IS NOT NULL THEN
    UPDATE driver_documents SET
      file_url = p_file_url,
      file_name = COALESCE(p_file_name, file_name),
      file_size = COALESCE(p_file_size, file_size),
      expires_at = p_expires_at,
      status = 'pending',
      rejection_reason = NULL,
      reviewed_at = NULL
    WHERE id = v_existing RETURNING id INTO v_id;
  ELSE
    INSERT INTO driver_documents (driver_id, doc_type, file_url, file_name, file_size, expires_at, status)
    VALUES (p_driver_id, p_doc_type, p_file_url, p_file_name, p_file_size, p_expires_at, 'pending')
    RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'document_id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get all documents for a driver
CREATE OR REPLACE FUNCTION get_driver_documents(p_driver_id UUID)
RETURNS SETOF driver_documents AS $$
  SELECT * FROM driver_documents
  WHERE driver_id = p_driver_id
  ORDER BY created_at DESC;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
-- 6. VEHICLE MANAGEMENT RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION add_driver_vehicle(
  p_driver_id UUID,
  p_category TEXT,
  p_make TEXT,
  p_model TEXT,
  p_year INTEGER,
  p_color TEXT,
  p_plate_number TEXT,
  p_seats INTEGER DEFAULT 4,
  p_photo_url TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO vehicles (driver_id, category, make, model, year, color, plate_number, seats, photo_url)
  VALUES (p_driver_id, p_category, p_make, p_model, p_year, p_color, p_plate_number, p_seats, p_photo_url)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'vehicle_id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_driver_vehicle(
  p_vehicle_id UUID,
  p_driver_id UUID,
  p_category TEXT DEFAULT NULL,
  p_make TEXT DEFAULT NULL,
  p_model TEXT DEFAULT NULL,
  p_year INTEGER DEFAULT NULL,
  p_color TEXT DEFAULT NULL,
  p_plate_number TEXT DEFAULT NULL,
  p_seats INTEGER DEFAULT NULL,
  p_photo_url TEXT DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
  UPDATE vehicles SET
    category = COALESCE(p_category, category),
    make = COALESCE(p_make, make),
    model = COALESCE(p_model, model),
    year = COALESCE(p_year, year),
    color = COALESCE(p_color, color),
    plate_number = COALESCE(p_plate_number, plate_number),
    seats = COALESCE(p_seats, seats),
    photo_url = COALESCE(p_photo_url, photo_url),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = NOW()
  WHERE id = p_vehicle_id AND driver_id = p_driver_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION toggle_vehicle_active(
  p_vehicle_id UUID,
  p_driver_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_current BOOLEAN;
BEGIN
  SELECT is_active INTO v_current FROM vehicles WHERE id = p_vehicle_id AND driver_id = p_driver_id;
  UPDATE vehicles SET is_active = NOT v_current, updated_at = NOW()
  WHERE id = p_vehicle_id AND driver_id = p_driver_id;
  RETURN jsonb_build_object('success', true, 'is_active', NOT v_current);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 7. WALLET DETAIL RPC
-- ============================================================

CREATE OR REPLACE FUNCTION get_driver_wallet_detail(p_driver_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_balance DECIMAL;
  v_bonus DECIMAL;
  v_incentive DECIMAL;
  v_pending_withdrawals DECIMAL;
  v_total_withdrawn DECIMAL;
BEGIN
  SELECT COALESCE(earnings_balance, 0) INTO v_balance FROM drivers WHERE id = p_driver_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_bonus
  FROM driver_earnings WHERE driver_id = p_driver_id AND type = 'bonus';

  SELECT COALESCE(SUM(amount), 0) INTO v_incentive
  FROM driver_earnings WHERE driver_id = p_driver_id AND type = 'incentive';

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests WHERE driver_id = p_driver_id AND status = 'pending';

  SELECT COALESCE(SUM(amount), 0) INTO v_total_withdrawn
  FROM withdrawal_requests WHERE driver_id = p_driver_id AND status IN ('approved','paid');

  RETURN jsonb_build_object(
    'balance', COALESCE(v_balance, 0),
    'bonus_balance', v_bonus,
    'incentive_balance', v_incentive,
    'pending_withdrawals', v_pending_withdrawals,
    'total_withdrawn', v_total_withdrawn,
    'currency', 'EGP'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 8. ENHANCED PERFORMANCE STATS RPC
-- ============================================================

CREATE OR REPLACE FUNCTION get_driver_performance(p_driver_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_total_trips INTEGER;
  v_completed_trips INTEGER;
  v_cancelled_by_driver INTEGER;
  v_total_offers INTEGER;
  v_acceptance_count INTEGER;
  v_avg_rating DECIMAL;
  v_today_earnings DECIMAL;
  v_week_earnings DECIMAL;
  v_month_earnings DECIMAL;
  v_balance DECIMAL;
  v_bonus DECIMAL;
  v_incentive DECIMAL;
  v_pending_withdrawals DECIMAL;
BEGIN
  SELECT COALESCE(total_trips, 0) INTO v_total_trips FROM drivers WHERE id = p_driver_id;

  SELECT COUNT(*) INTO v_completed_trips
  FROM rides WHERE driver_id = p_driver_id AND status = 'completed';

  SELECT COUNT(*) INTO v_cancelled_by_driver
  FROM rides WHERE driver_id = p_driver_id AND status = 'cancelled' AND cancelled_by = 'driver';

  SELECT COUNT(*) INTO v_total_offers
  FROM ride_requests WHERE driver_id = p_driver_id;

  SELECT COUNT(*) INTO v_acceptance_count
  FROM ride_requests WHERE driver_id = p_driver_id AND status = 'accepted';

  SELECT COALESCE(rating, 0) INTO v_avg_rating FROM drivers WHERE id = p_driver_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
  FROM driver_earnings WHERE driver_id = p_driver_id
    AND created_at >= date_trunc('day', NOW());

  SELECT COALESCE(SUM(amount), 0) INTO v_week_earnings
  FROM driver_earnings WHERE driver_id = p_driver_id
    AND created_at >= date_trunc('week', NOW());

  SELECT COALESCE(SUM(amount), 0) INTO v_month_earnings
  FROM driver_earnings WHERE driver_id = p_driver_id
    AND created_at >= date_trunc('month', NOW());

  SELECT COALESCE(earnings_balance, 0) INTO v_balance FROM drivers WHERE id = p_driver_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_bonus
  FROM driver_earnings WHERE driver_id = p_driver_id AND type = 'bonus';

  SELECT COALESCE(SUM(amount), 0) INTO v_incentive
  FROM driver_earnings WHERE driver_id = p_driver_id AND type = 'incentive';

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests WHERE driver_id = p_driver_id AND status = 'pending';

  RETURN jsonb_build_object(
    'total_trips', v_total_trips,
    'completed_trips', v_completed_trips,
    'cancelled_trips', v_cancelled_by_driver,
    'rating', v_avg_rating,
    'acceptance_rate', CASE WHEN v_total_offers > 0 THEN ROUND(v_acceptance_count::DECIMAL / v_total_offers * 100, 1) ELSE 100 END,
    'cancellation_rate', CASE WHEN (v_completed_trips + v_cancelled_by_driver) > 0 THEN ROUND(v_cancelled_by_driver::DECIMAL / (v_completed_trips + v_cancelled_by_driver) * 100, 1) ELSE 0 END,
    'today_rides', (SELECT COUNT(*) FROM rides WHERE driver_id = p_driver_id AND status = 'completed' AND completed_at >= date_trunc('day', NOW())),
    'today_earnings', v_today_earnings,
    'week_earnings', v_week_earnings,
    'month_earnings', v_month_earnings,
    'balance', v_balance,
    'bonus_balance', v_bonus,
    'incentive_balance', v_incentive,
    'pending_withdrawals', v_pending_withdrawals,
    'currency', 'EGP'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 9. REALTIME: add driver_earnings and wallets to realtime publication
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE driver_earnings;
ALTER PUBLICATION supabase_realtime ADD TABLE wallets;
ALTER PUBLICATION supabase_realtime ADD TABLE withdrawal_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE driver_documents;
