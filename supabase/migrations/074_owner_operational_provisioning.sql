-- 074_owner_operational_provisioning.sql
-- Additive. Makes the global Owner a first-class operational identity for
-- Customer + Delivery + Provider + Admin using the SAME auth.uid().
--
-- Strategy (no duplicate Auth user, no email-based authorization):
--   * get_my_capabilities() already returns the operational contexts derived
--     from rows in users / drivers / service_providers / merchants. The Owner
--     (users.role='owner') only lacks drivers / service_providers rows, so the
--     Delivery / Provider apps (which gate on those rows) block the Owner.
--   * ensure_owner_operational_contexts() is an OWNER-ONLY, IDEMPOTENT RPC that
--     guarantees the Owner has the required operational rows, marked
--     owner-operated. It never creates a new Auth user and never duplicates.
--
-- All authorization remains server-side; this only materializes the rows that
-- the existing capability resolver already trusts.

-- Extend the capability resolver with explicit context flags (derived, not new
-- sources of truth). can_use_* = the context is available to this identity.
CREATE OR REPLACE FUNCTION public.get_my_capabilities()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'customer', EXISTS(SELECT 1 FROM users WHERE id = auth.uid()),
    'driver',   EXISTS(SELECT 1 FROM drivers WHERE user_id = auth.uid()),
    'provider', EXISTS(SELECT 1 FROM service_providers WHERE user_id = auth.uid()),
    'merchant', EXISTS(SELECT 1 FROM merchants WHERE owner_user_id = auth.uid()),
    'admin',    EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','owner')),
    'owner',    EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'owner'),
    'can_use_customer', EXISTS(SELECT 1 FROM users WHERE id = auth.uid()),
    'can_use_delivery',  EXISTS(SELECT 1 FROM drivers WHERE user_id = auth.uid())
                          OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'owner'),
    'can_use_provider',  EXISTS(SELECT 1 FROM service_providers WHERE user_id = auth.uid())
                          OR EXISTS(SELECT 1 FROM merchants WHERE owner_user_id = auth.uid())
                          OR EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'owner'),
    'can_use_admin',     EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','owner'))
  );
$$;

REVOKE ALL ON FUNCTION public.get_my_capabilities() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_capabilities() TO authenticated;

-- Idempotent, owner-only provisioning of operational contexts.
CREATE OR REPLACE FUNCTION public.ensure_owner_operational_contexts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_role text;
  v_result jsonb := '{}'::jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = v_uid;
  IF v_role <> 'owner' THEN
    RAISE EXCEPTION 'forbidden: only the platform owner may provision owner contexts';
  END IF;

  -- Delivery operational identity (owner-operated).
  IF NOT EXISTS (SELECT 1 FROM drivers WHERE user_id = v_uid) THEN
    INSERT INTO public.drivers (user_id, full_name, status, onboarding_completed, verification_status, rating, total_deliveries)
    VALUES (v_uid, COALESCE((SELECT full_name FROM users WHERE id = v_uid), 'Owner'), 'online', true, 'verified', 5.0, 0);
    v_result := v_result || jsonb_build_object('delivery', 'created');
  ELSE
    v_result := v_result || jsonb_build_object('delivery', 'exists');
  END IF;

  -- Provider operational identity (owner-operated).
  IF NOT EXISTS (SELECT 1 FROM service_providers WHERE user_id = v_uid) THEN
    INSERT INTO public.service_providers (user_id, name, category_type, is_verified)
    VALUES (v_uid, COALESCE((SELECT full_name FROM users WHERE id = v_uid), 'Owner'), 'home_services', true);
    v_result := v_result || jsonb_build_object('provider', 'created');
  ELSE
    v_result := v_result || jsonb_build_object('provider', 'exists');
  END IF;

  PERFORM public.log_admin_action('OWNER_CONTEXT_PROVISION', 'owner', v_uid::text,
    NULL, v_result, 'Idempotent owner operational context provisioning', 'GLOBAL');

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_owner_operational_contexts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_owner_operational_contexts() TO authenticated;
