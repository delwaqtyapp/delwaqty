-- ============================================================
-- Migration 012: Safety Platform (SOS, Trusted Contacts, Live Share)
-- ============================================================
-- Extends existing trusted_contacts table (007).
-- Adds structured SOS alerts, live share sessions, and ride-level safety columns.
-- NO duplicate tables — reuses complaints for case tracking.

BEGIN;

-- --- Extend trusted_contacts ---------------------------------
ALTER TABLE trusted_contacts ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE trusted_contacts ADD COLUMN IF NOT EXISTS relationship TEXT
  CHECK (relationship IS NULL OR relationship IN ('family','friend','colleague','other'));
ALTER TABLE trusted_contacts ADD COLUMN IF NOT EXISTS notify_on_ride BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE trusted_contacts ADD COLUMN IF NOT EXISTS notification_preference TEXT NOT NULL DEFAULT 'both'
  CHECK (notification_preference IN ('sms','call','push','both'));

-- --- SOS alerts (structured emergency flow) ------------------
CREATE TABLE IF NOT EXISTS sos_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL DEFAULT 'manual' CHECK (alert_type IN ('manual','automatic','timer')),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  address TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','escalated','resolved','false_alarm')),
  notified_contact_ids UUID[] DEFAULT '{}',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);
ALTER TABLE sos_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sos alerts owner rw" ON sos_alerts;
CREATE POLICY "sos alerts owner rw" ON sos_alerts FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "sos alerts participant read" ON sos_alerts;
CREATE POLICY "sos alerts participant read" ON sos_alerts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rides r
      WHERE r.id = sos_alerts.ride_id
        AND (r.rider_id = auth.uid() OR r.driver_id = auth.uid())
    )
  );

-- --- Live share sessions (shareable trip link) ---------------
CREATE TABLE IF NOT EXISTS live_share_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  share_token TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE live_share_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "live share owner rw" ON live_share_sessions;
CREATE POLICY "live share owner rw" ON live_share_sessions FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "live share public read by token" ON live_share_sessions;
CREATE POLICY "live share public read by token" ON live_share_sessions FOR SELECT
  USING (is_active = true AND expires_at > NOW());

-- --- Extend rides with safety columns ------------------------
ALTER TABLE rides ADD COLUMN IF NOT EXISTS is_shared_trip BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS emergency_contact_id UUID
  REFERENCES trusted_contacts(id) ON DELETE SET NULL;

-- --- RPCs ----------------------------------------------------

-- Trigger SOS alert: creates alert + returns notified contacts
CREATE OR REPLACE FUNCTION trigger_sos_alert(
  p_ride_id UUID,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_address TEXT DEFAULT NULL,
  p_alert_type TEXT DEFAULT 'manual'
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_alert_id UUID;
  v_contacts JSONB;
  v_contact_ids UUID[];
  v_contact RECORD;
BEGIN
  v_user_id := auth.uid();

  -- Create the SOS alert
  INSERT INTO sos_alerts (ride_id, user_id, alert_type, latitude, longitude, address)
  VALUES (p_ride_id, v_user_id, p_alert_type, p_latitude, p_longitude, p_address)
  RETURNING id INTO v_alert_id;

  -- Mark ride as shared
  UPDATE rides SET is_shared_trip = true WHERE id = p_ride_id;

  -- Gather trusted contacts that want notifications
  v_contact_ids := '{}';
  v_contacts := '[]'::JSONB;

  FOR v_contact IN
    SELECT tc.id, tc.name, tc.phone, tc.notification_preference
    FROM trusted_contacts tc
    WHERE tc.user_id = v_user_id
      AND tc.notify_on_ride = true
  LOOP
    v_contact_ids := array_append(v_contact_ids, v_contact.id);
    v_contacts := v_contacts || jsonb_build_object(
      'id', v_contact.id,
      'name', v_contact.name,
      'phone', v_contact.phone,
      'preference', v_contact.notification_preference
    );
  END LOOP;

  -- Update alert with notified contacts
  UPDATE sos_alerts SET notified_contact_ids = v_contact_ids WHERE id = v_alert_id;

  RETURN jsonb_build_object(
    'success', true,
    'alert_id', v_alert_id,
    'notified_contacts', v_contacts,
    'ride_id', p_ride_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resolve SOS alert
CREATE OR REPLACE FUNCTION resolve_sos_alert(
  p_alert_id UUID,
  p_status TEXT DEFAULT 'resolved'
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  UPDATE sos_alerts
  SET status = p_status, resolved_at = NOW()
  WHERE id = p_alert_id
    AND user_id = v_user_id
    AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'alert_not_found_or_already_resolved');
  END IF;

  RETURN jsonb_build_object('success', true, 'alert_id', p_alert_id, 'status', p_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Start live share session
CREATE OR REPLACE FUNCTION start_live_share(
  p_ride_id UUID,
  p_duration_minutes INTEGER DEFAULT 60
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_session_id UUID;
  v_token TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid();

  -- Deactivate any existing active session for this ride by this user
  UPDATE live_share_sessions
  SET is_active = false
  WHERE ride_id = p_ride_id AND user_id = v_user_id AND is_active = true;

  -- Generate a unique share token
  v_token := encode(gen_random_bytes(16), 'hex');
  v_expires_at := NOW() + (p_duration_minutes || ' minutes')::INTERVAL;

  INSERT INTO live_share_sessions (ride_id, user_id, share_token, expires_at)
  VALUES (p_ride_id, v_user_id, v_token, v_expires_at)
  RETURNING id INTO v_session_id;

  -- Mark ride as shared
  UPDATE rides SET is_shared_trip = true WHERE id = p_ride_id;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'share_token', v_token,
    'expires_at', v_expires_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Stop live share session
CREATE OR REPLACE FUNCTION stop_live_share(
  p_session_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  UPDATE live_share_sessions
  SET is_active = false
  WHERE id = p_session_id AND user_id = v_user_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'session_not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get active live share session for a ride
CREATE OR REPLACE FUNCTION get_live_share_session(
  p_ride_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_session RECORD;
BEGIN
  SELECT id, share_token, expires_at, is_active, created_at
  INTO v_session
  FROM live_share_sessions
  WHERE ride_id = p_ride_id AND is_active = true AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'session_id', v_session.id,
    'share_token', v_session.share_token,
    'expires_at', v_session.expires_at,
    'is_active', v_session.is_active
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Upsert trusted contact
CREATE OR REPLACE FUNCTION upsert_trusted_contact(
  p_contact_id UUID DEFAULT NULL,
  p_name TEXT,
  p_phone TEXT,
  p_email TEXT DEFAULT NULL,
  p_relationship TEXT DEFAULT NULL,
  p_notify_on_ride BOOLEAN DEFAULT true,
  p_notification_preference TEXT DEFAULT 'both'
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_id UUID;
BEGIN
  v_user_id := auth.uid();

  IF p_contact_id IS NOT NULL THEN
    UPDATE trusted_contacts
    SET name = p_name, phone = p_phone, email = p_email,
        relationship = p_relationship, notify_on_ride = p_notify_on_ride,
        notification_preference = p_notification_preference
    WHERE id = p_contact_id AND user_id = v_user_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'reason', 'contact_not_found');
    END IF;
  ELSE
    INSERT INTO trusted_contacts (user_id, name, phone, email, relationship, notify_on_ride, notification_preference)
    VALUES (v_user_id, p_name, p_phone, p_email, p_relationship, p_notify_on_ride, p_notification_preference)
    RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'contact_id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete trusted contact
CREATE OR REPLACE FUNCTION delete_trusted_contact(
  p_contact_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  DELETE FROM trusted_contacts
  WHERE id = p_contact_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'contact_not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --- Indexes -------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_sos_alerts_ride ON sos_alerts(ride_id);
CREATE INDEX IF NOT EXISTS idx_sos_alerts_user ON sos_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_sos_alerts_status ON sos_alerts(status);
CREATE INDEX IF NOT EXISTS idx_live_share_ride ON live_share_sessions(ride_id);
CREATE INDEX IF NOT EXISTS idx_live_share_token ON live_share_sessions(share_token);
CREATE INDEX IF NOT EXISTS idx_trusted_contacts_user ON trusted_contacts(user_id);

-- --- Realtime ------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE sos_alerts;
ALTER PUBLICATION supabase_realtime ADD TABLE live_share_sessions;

COMMIT;
