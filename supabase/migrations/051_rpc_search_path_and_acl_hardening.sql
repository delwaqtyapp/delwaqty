-- ============================================================================
-- 051_rpc_search_path_and_acl_hardening.sql
--
-- Sub-phase 2.7: Security hardening
--   1. ADD SET search_path = public, pg_temp to all legacy SECURITY DEFINER RPCs
--   2. ADD REVOKE/GRANT ACLs to RPCs that lack them
--   3. REVOKE anon access from platform_* (migration 050) admin-only RPCs
--   4. Apply 016 pattern everywhere
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- 1. Migration 005 RPCs — add search_path + REVOKE/GRANT
-- ──────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.get_user_role(uid UUID)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.get_user_merchant_id(uid UUID)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.is_admin(uid UUID)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.is_merchant_owner(merchant_uuid UUID)
  SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.get_user_role(uid UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_user_merchant_id(uid UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_admin(uid UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_merchant_owner(merchant_uuid UUID) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_user_role(uid UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_merchant_id(uid UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(uid UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_merchant_owner(merchant_uuid UUID) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- 2. Migration 010 RPCs — add search_path + REVOKE/GRANT
-- ──────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.submit_driver_onboarding(
  p_driver_id UUID, p_full_name TEXT, p_phone TEXT, p_national_id TEXT,
  p_address TEXT, p_profile_photo_url TEXT, p_onboarding_step INTEGER
) SET search_path = public, pg_temp;

ALTER FUNCTION public.complete_driver_onboarding(p_driver_id UUID)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.upsert_driver_document(
  p_driver_id UUID, p_doc_type TEXT, p_file_url TEXT,
  p_file_name TEXT, p_file_size INTEGER, p_expires_at DATE
) SET search_path = public, pg_temp;

ALTER FUNCTION public.get_driver_documents(p_driver_id UUID)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.add_driver_vehicle(
  p_driver_id UUID, p_category TEXT, p_make TEXT, p_model TEXT,
  p_year INTEGER, p_color TEXT, p_plate_number TEXT,
  p_seats INTEGER, p_photo_url TEXT
) SET search_path = public, pg_temp;

ALTER FUNCTION public.update_driver_vehicle(
  p_vehicle_id UUID, p_driver_id UUID, p_category TEXT, p_make TEXT,
  p_model TEXT, p_year INTEGER, p_color TEXT, p_plate_number TEXT,
  p_seats INTEGER, p_photo_url TEXT, p_is_active BOOLEAN
) SET search_path = public, pg_temp;

ALTER FUNCTION public.toggle_vehicle_active(p_vehicle_id UUID, p_driver_id UUID)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.get_driver_wallet_detail(p_driver_id UUID)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.get_driver_performance(p_driver_id UUID)
  SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.submit_driver_onboarding(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_driver_onboarding(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_driver_document(
  UUID, TEXT, TEXT, TEXT, INTEGER, DATE
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_driver_documents(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_driver_vehicle(
  UUID, TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, INTEGER, TEXT
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_driver_vehicle(
  UUID, UUID, TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, INTEGER, TEXT, BOOLEAN
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.toggle_vehicle_active(UUID, UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_driver_wallet_detail(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_driver_performance(UUID) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.submit_driver_onboarding(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_driver_onboarding(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_driver_document(
  UUID, TEXT, TEXT, TEXT, INTEGER, DATE
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_documents(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_driver_vehicle(
  UUID, TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, INTEGER, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_driver_vehicle(
  UUID, UUID, TEXT, TEXT, TEXT, INTEGER, TEXT, TEXT, INTEGER, TEXT, BOOLEAN
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_vehicle_active(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_wallet_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_performance(UUID) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- 3. Migration 012/029 Safety RPCs — add search_path
--    (REVOKE/GRANT already present from 029)
-- ──────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.trigger_sos_alert(
  p_ride_id UUID, p_latitude DOUBLE PRECISION, p_longitude DOUBLE PRECISION,
  p_address TEXT, p_alert_type TEXT
) SET search_path = public, pg_temp;

ALTER FUNCTION public.resolve_sos_alert(p_alert_id UUID, p_status TEXT)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.start_live_share(p_ride_id UUID, p_duration_minutes INTEGER)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.stop_live_share(p_session_id UUID)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.get_live_share_session(p_ride_id UUID)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.upsert_trusted_contact(
  p_name TEXT, p_phone TEXT, p_contact_id UUID, p_email TEXT,
  p_relationship TEXT, p_notify_on_ride BOOLEAN, p_notification_preference TEXT
) SET search_path = public, pg_temp;

ALTER FUNCTION public.delete_trusted_contact(p_contact_id UUID)
  SET search_path = public, pg_temp;

-- ──────────────────────────────────────────────────────────────────────────────
-- 4. Migration 029 orphan RPCs — add search_path
--    (REVOKE/GRANT already present from 029)
-- ──────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.get_peak_hours()
  SET search_path = public, pg_temp;

ALTER FUNCTION public.get_merchant_rating_summary(p_merchant_id UUID)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.increment_coupon_usage(p_coupon_code TEXT)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.get_admin_analytics(
  date_from TIMESTAMPTZ, date_to TIMESTAMPTZ
) SET search_path = public, pg_temp;

-- ──────────────────────────────────────────────────────────────────────────────
-- 5. Migration 021 trigger function — add search_path
-- ──────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.handle_new_user()
  SET search_path = public, pg_temp;

-- ──────────────────────────────────────────────────────────────────────────────
-- 6. Migration 050 platform_* RPCs — REVOKE anon (search_path already set)
--    These are admin-only financial intelligence functions.
--    Anon should NEVER be able to call them.
-- ──────────────────────────────────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION public.platform_kpi_summary(
  TIMESTAMPTZ, TIMESTAMPTZ, UUID
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_orders_timeseries(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_rides_timeseries(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_revenue_breakdown(
  TIMESTAMPTZ, TIMESTAMPTZ, UUID
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_service_performance(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_delivery_intelligence(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_merchant_intelligence(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_wallet_intelligence(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_provider_intelligence(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_commission_summary(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_complaint_summary(
  TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_transaction_ledger(
  TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID, TEXT, INTEGER, INTEGER
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_operational_alerts()
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_revenue_overview(
  TEXT, TEXT, DATE, DATE
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.platform_commission_for_reference(
  TEXT, UUID
) FROM PUBLIC, anon;

-- ──────────────────────────────────────────────────────────────────────────────
-- 7. Verification: list any remaining SECURITY DEFINER functions
--    that still lack SET search_path (informational, does not fail)
-- ──────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
      AND NOT EXISTS (
        SELECT 1 FROM pg_proc p2
        JOIN pg_namespace n2 ON p2.pronamespace = n2.oid
        WHERE n2.nspname = 'public'
          AND p2.proname = p.proname
          AND p2.proconfig @> ARRAY['search_path=public, pg_temp']
      )
  LOOP
    RAISE WARNING 'SECURITY DEFINER function without search_path: %(%)', r.proname, r.args;
  END LOOP;
END $$;
