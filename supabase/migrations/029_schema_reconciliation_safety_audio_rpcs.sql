-- ============================================================
-- Migration 029: Schema Reconciliation — Safety Platform + Audio Logs + Missing RPCs
-- ============================================================
-- Root cause: migrations 012 (safety platform) and 013 (service audio logs)
-- were never applied in full. 027 consolidated 017/023/024/025/026 only.
-- Live audit 2026-08-14 found missing: sos_alerts, live_share_sessions,
-- service_audio_logs tables, trusted_contacts extension columns,
-- rides.emergency_contact_id, all safety RPCs, audio storage bucket.
-- Additionally 4 RPCs referenced by the app exist in NO migration file
-- (get_admin_analytics, get_peak_hours, get_merchant_rating_summary,
-- increment_coupon_usage) — created here matching the exact shapes the
-- Dart code expects.
-- Security hardening follows migration 028: SECURITY INVOKER + granular
-- grants (REVOKE PUBLIC, GRANT authenticated) for every new RPC.

BEGIN;

-- >>> 012 safety platform: extend trusted_contacts <<<
ALTER TABLE trusted_contacts ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE trusted_contacts ADD COLUMN IF NOT EXISTS relationship TEXT
  CHECK (relationship IS NULL OR relationship IN ('family','friend','colleague','other'));
ALTER TABLE trusted_contacts ADD COLUMN IF NOT EXISTS notify_on_ride BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE trusted_contacts ADD COLUMN IF NOT EXISTS notification_preference TEXT NOT NULL DEFAULT 'both'
  CHECK (notification_preference IN ('sms','call','push','both'));

-- >>> 012 safety platform: SOS alerts <<<
CREATE TABLE IF NOT EXISTS sos_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL DEFAULT 'manual' CHECK (alert_type IN ('manual','automatic','timer')),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  address TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','escalated','resolved','falseAlarm')),
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

-- >>> 012 safety platform: live share sessions <<<
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

-- >>> 012 safety platform: extend rides <<<
ALTER TABLE rides ADD COLUMN IF NOT EXISTS is_shared_trip BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS emergency_contact_id UUID
  REFERENCES trusted_contacts(id) ON DELETE SET NULL;

-- >>> 012 safety platform: RPCs <<<
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

  INSERT INTO sos_alerts (ride_id, user_id, alert_type, latitude, longitude, address)
  VALUES (p_ride_id, v_user_id, p_alert_type, p_latitude, p_longitude, p_address)
  RETURNING id INTO v_alert_id;

  UPDATE rides SET is_shared_trip = true WHERE id = p_ride_id;

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

  UPDATE sos_alerts SET notified_contact_ids = v_contact_ids WHERE id = v_alert_id;

  RETURN jsonb_build_object(
    'success', true,
    'alert_id', v_alert_id,
    'notified_contacts', v_contacts,
    'ride_id', p_ride_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

  UPDATE live_share_sessions
  SET is_active = false
  WHERE ride_id = p_ride_id AND user_id = v_user_id AND is_active = true;

  v_token := encode(gen_random_bytes(16), 'hex');
  v_expires_at := NOW() + (p_duration_minutes || ' minutes')::INTERVAL;

  INSERT INTO live_share_sessions (ride_id, user_id, share_token, expires_at)
  VALUES (p_ride_id, v_user_id, v_token, v_expires_at)
  RETURNING id INTO v_session_id;

  UPDATE rides SET is_shared_trip = true WHERE id = p_ride_id;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'share_token', v_token,
    'expires_at', v_expires_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

CREATE OR REPLACE FUNCTION upsert_trusted_contact(
  p_name TEXT,
  p_phone TEXT,
  p_contact_id UUID DEFAULT NULL,
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

-- >>> 012 hardening: safety RPCs must not be PUBLIC <<<
REVOKE EXECUTE ON FUNCTION public.trigger_sos_alert(UUID, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.resolve_sos_alert(UUID, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.start_live_share(UUID, INTEGER) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stop_live_share(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_live_share_session(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_trusted_contact(TEXT, TEXT, UUID, TEXT, TEXT, BOOLEAN, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.delete_trusted_contact(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.trigger_sos_alert(UUID, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_sos_alert(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_live_share(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stop_live_share(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_share_session(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_trusted_contact(TEXT, TEXT, UUID, TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_trusted_contact(UUID) TO authenticated;

-- >>> 013 service audio logs: table <<<
CREATE TABLE IF NOT EXISTS service_audio_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  audio_url TEXT,
  duration INTEGER,
  status TEXT NOT NULL DEFAULT 'recording'
    CHECK (status IN ('recording', 'completed', 'failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE service_audio_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "customer own logs rw" ON service_audio_logs;
CREATE POLICY "customer own logs rw" ON service_audio_logs
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "provider own logs r" ON service_audio_logs;
CREATE POLICY "provider own logs r" ON service_audio_logs
  FOR SELECT
  USING (auth.uid() = provider_id);

DROP POLICY IF EXISTS "admin all logs r" ON service_audio_logs;
CREATE POLICY "admin all logs r" ON service_audio_logs
  FOR SELECT
  USING (auth.uid() IN (
    SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' IN ('admin', 'owner')
  ));

CREATE INDEX IF NOT EXISTS idx_service_audio_logs_order ON service_audio_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_service_audio_logs_user ON service_audio_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_service_audio_logs_provider ON service_audio_logs(provider_id);

-- >>> 013 service audio logs: storage <<<
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('service-audio-logs', 'service-audio-logs', true, 52428800, ARRAY['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/mpeg'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "audio logs upload" ON storage.objects;
CREATE POLICY "audio logs upload" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'service-audio-logs'
    AND auth.role() = 'authenticated'
  );

DROP POLICY IF EXISTS "audio logs read" ON storage.objects;
CREATE POLICY "audio logs read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'service-audio-logs');

-- >>> 012 indexes + realtime <<<
CREATE INDEX IF NOT EXISTS idx_sos_alerts_ride ON sos_alerts(ride_id);
CREATE INDEX IF NOT EXISTS idx_sos_alerts_user ON sos_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_sos_alerts_status ON sos_alerts(status);
CREATE INDEX IF NOT EXISTS idx_live_share_ride ON live_share_sessions(ride_id);
CREATE INDEX IF NOT EXISTS idx_live_share_token ON live_share_sessions(share_token);
CREATE INDEX IF NOT EXISTS idx_trusted_contacts_user ON trusted_contacts(user_id);

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'sos_alerts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sos_alerts;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'live_share_sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE live_share_sessions;
  END IF;
END $body$;

-- >>> Orphan RPCs (referenced by admin/review/coupon code, in no prior migration) <<<

-- get_peak_hours: returns rows with keys `hour` and `count` (matches fallback shape).
CREATE OR REPLACE FUNCTION get_peak_hours()
RETURNS TABLE(hour integer, count bigint)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH hour_counts AS (
    SELECT EXTRACT(HOUR FROM created_at)::integer AS hr, COUNT(*) AS cnt
    FROM rides
    WHERE created_at >= NOW() - INTERVAL '30 days'
    GROUP BY hr
  )
  SELECT hr, cnt
  FROM hour_counts
  ORDER BY cnt DESC;
END;
$$;

-- get_merchant_rating_summary: returns avg_rating + total_reviews for a merchant.
CREATE OR REPLACE FUNCTION get_merchant_rating_summary(p_merchant_id UUID)
RETURNS TABLE(avg_rating numeric, total_reviews bigint)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT ROUND(AVG(rating)::numeric, 2) AS avg_rating, COUNT(*)::bigint AS total_reviews
  FROM reviews
  WHERE merchant_id = p_merchant_id;
END;
$$;

-- increment_coupon_usage: bumps used_count for a coupon code within limit.
CREATE OR REPLACE FUNCTION increment_coupon_usage(p_coupon_code TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_id UUID;
  v_used INTEGER;
  v_limit INTEGER;
BEGIN
  SELECT id, used_count, usage_limit INTO v_id, v_used, v_limit
  FROM coupons
  WHERE code = p_coupon_code;

  IF v_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_not_found');
  END IF;

  IF v_limit IS NOT NULL AND v_used >= v_limit THEN
    RETURN jsonb_build_object('success', false, 'reason', 'usage_limit_reached');
  END IF;

  UPDATE coupons
  SET used_count = COALESCE(v_used, 0) + 1
  WHERE id = v_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- get_admin_analytics: single aggregate row filtered by date range.
CREATE OR REPLACE FUNCTION get_admin_analytics(
  date_from TIMESTAMPTZ DEFAULT NULL,
  date_to TIMESTAMPTZ DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_from TIMESTAMPTZ := COALESCE(date_from, NOW() - INTERVAL '30 days');
  v_to TIMESTAMPTZ := COALESCE(date_to, NOW());
  v_orders BIGINT;
  v_revenue NUMERIC;
  v_users BIGINT;
  v_drivers BIGINT;
  v_merchants BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_orders FROM rides WHERE created_at BETWEEN v_from AND v_to;
  SELECT COALESCE(SUM(fare), 0) INTO v_revenue FROM rides
    WHERE status = 'completed' AND created_at BETWEEN v_from AND v_to;
  SELECT COUNT(*) INTO v_users FROM users WHERE created_at BETWEEN v_from AND v_to;
  SELECT COUNT(*) INTO v_drivers FROM drivers WHERE created_at BETWEEN v_from AND v_to;
  SELECT COUNT(*) INTO v_merchants FROM merchants WHERE created_at BETWEEN v_from AND v_to;

  RETURN jsonb_build_object(
    'total_orders', v_orders,
    'total_revenue', v_revenue,
    'total_users', v_users,
    'total_drivers', v_drivers,
    'total_merchants', v_merchants
  );
END;
$$;

-- >>> Orphan RPC hardening: not PUBLIC by default <<<
REVOKE EXECUTE ON FUNCTION public.get_peak_hours() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_merchant_rating_summary(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.increment_coupon_usage(TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_admin_analytics(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_peak_hours() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_merchant_rating_summary(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_coupon_usage(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_analytics(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

COMMIT;