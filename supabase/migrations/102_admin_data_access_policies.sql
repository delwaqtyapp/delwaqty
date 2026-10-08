-- ============================================================
-- 102_admin_data_access_policies.sql
-- Give the admin console real read/write access to the operational
-- tables it manages.
--
-- PROBLEM (verified against the live pg_policies on 2026-10-02):
--   * orders   -> only "users can view own orders" + "merchants can
--                 view orders for their merchant". There was NO admin
--                 policy, so /admin/orders always rendered the empty
--                 state and every status update silently wrote 0 rows
--                 while the UI reported success.
--   * drivers  -> only own-profile + "active drivers viewable by all".
--                 Same silent failure for /admin/drivers.
--   * rides    -> participant read only, so /admin/deliveries was
--                 permanently empty and status updates no-op'd.
--   * verification_attempts had admin read/review policies, so that
--     one was fine.
--
-- All policies below reuse the EXISTING admin identity helper
-- (public._is_active_admin_uid) rather than introducing a new notion
-- of "who is an admin" — a single source of truth for authorization.
--
-- Scope: admins see ALL rows regardless of region. Region-scoped
-- admins are NOT restricted here because the admin console is the
-- platform back office; region scoping for the driver/merchant apps
-- is enforced by their own policies, untouched.
-- ============================================================

-- ─── orders ──────────────────────────────────────────────────

DROP POLICY IF EXISTS "Admins can view all orders" ON public.orders;
CREATE POLICY "Admins can view all orders" ON public.orders
  FOR SELECT TO authenticated
  USING (public._is_active_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "Admins can update any order" ON public.orders;
CREATE POLICY "Admins can update any order" ON public.orders
  FOR UPDATE TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

-- ─── drivers ─────────────────────────────────────────────────

DROP POLICY IF EXISTS "Admins can view all drivers" ON public.drivers;
CREATE POLICY "Admins can view all drivers" ON public.drivers
  FOR SELECT TO authenticated
  USING (public._is_active_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "Admins can update any driver" ON public.drivers;
CREATE POLICY "Admins can update any driver" ON public.drivers
  FOR UPDATE TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

-- ─── rides (the courier-delivery table the admin console reads) ─

DROP POLICY IF EXISTS "Admins can view all rides" ON public.rides;
CREATE POLICY "Admins can view all rides" ON public.rides
  FOR SELECT TO authenticated
  USING (public._is_active_admin_uid(auth.uid()));

DROP POLICY IF EXISTS "Admins can update any ride" ON public.rides;
CREATE POLICY "Admins can update any ride" ON public.rides
  FOR UPDATE TO authenticated
  USING (public._is_active_admin_uid(auth.uid()))
  WITH CHECK (public._is_active_admin_uid(auth.uid()));

-- ─── count_table_rows RPC ────────────────────────────────────
-- getDashboardMetrics called an RPC that does not exist in any
-- migration, so the dashboard silently returned an all-zero metrics
-- object (and the analytics page rendered a confident "EGP 0.00").

-- The previous definition was an UNSECURITY-DEFINER plpgsql that
-- interpolated its argument straight into EXECUTE format(...) and had
-- NO authorization check, so any authenticated caller could count any
-- table in the public schema. Same signature (the app already calls
-- table_name), now admin-only and whitelisted.

DROP FUNCTION IF EXISTS public.count_table_rows(text);

CREATE FUNCTION public.count_table_rows(table_name text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  row_count integer;
BEGIN
  IF NOT public._is_active_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  -- Whitelist: never interpolate an arbitrary identifier into SQL.
  IF table_name NOT IN (
    'users', 'orders', 'merchants', 'products', 'drivers', 'rides',
    'service_providers', 'service_bookings', 'reviews', 'wallets',
    'categories', 'catalog_categories', 'complaints', 'chat_rooms',
    'notifications', 'driver_locations'
  ) THEN
    RAISE EXCEPTION 'unknown table %', table_name;
  END IF;

  EXECUTE format('SELECT count(*) FROM public.%I', table_name) INTO row_count;
  RETURN row_count;
END;
$$;

REVOKE ALL ON FUNCTION public.count_table_rows(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.count_table_rows(text) TO authenticated;