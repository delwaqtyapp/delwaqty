-- MIGRATION 116: Unify Owner Permissions, is_admin resolution & secure delivery overloads
--
-- 1. Expanded permission vocabulary to cover financial, merchant, driver and order operations.
-- 2. has_permission: evaluates owner UID first, granting absolute universal authority on all operations.
-- 3. is_admin(uid): calls _is_active_admin_uid(uid) ensuring consistency with role='owner'.
-- 4. complete_delivery: secured with SECURITY DEFINER and explicit search_path.

CREATE OR REPLACE FUNCTION public._valid_permission(p_permission text)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_permission IN (
    'ADMIN_CREATE', 'ADMIN_ASSIGN', 'ADMIN_ROLE_ASSIGN', 'ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN', 'ADMIN_SUSPEND',
    'MEMBER_VIEW', 'MEMBER_VIEW_LOCATION', 'MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS', 'MEMBER_VIEW_TIMELINE', 'MEMBER_VIEW_DOCUMENTS',
    'MEMBER_MODERATE', 'MEMBER_WARN', 'MEMBER_RESTRICT', 'MEMBER_SUSPEND',
    'MEMBER_BAN', 'MEMBER_DELETE',
    'EMERGENCY_VIEW', 'EMERGENCY_AUDIO',
    'OFFER_CREATE', 'OFFER_REVIEW', 'OFFER_APPROVE', 'OFFER_PUBLISH',
    'PLATFORM_REVENUE',
    'FINANCIAL_VIEW', 'FINANCIAL_SETTLEMENT_APPROVE', 'FINANCIAL_TOPUP_APPROVE', 'FINANCIAL_WALLET_MANAGE', 'FINANCIAL_COLLECT',
    'ORDER_VIEW', 'ORDER_MANAGE', 'ORDER_DISPATCH', 'ORDER_CANCEL',
    'MERCHANT_VIEW', 'MERCHANT_APPROVE', 'MERCHANT_SUSPEND', 'MERCHANT_EDIT',
    'DRIVER_VIEW', 'DRIVER_APPROVE', 'DRIVER_VERIFY', 'DRIVER_SUSPEND',
    'ESCALATION_VIEW', 'ESCALATION_RESOLVE',
    'SETTINGS_VIEW', 'SETTINGS_EDIT',
    'AUDIT_LOG_VIEW', 'ANALYTICS_VIEW'
  );
$function$;

CREATE OR REPLACE FUNCTION public.has_permission(
  p_permission text,
  p_region_id uuid DEFAULT NULL::uuid,
  p_target_admin_id uuid DEFAULT NULL::uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_granted boolean;
  v_default_in_scope boolean;
BEGIN
  IF v_actor IS NULL OR p_permission IS NULL OR btrim(p_permission) = '' THEN
    RETURN false;
  END IF;

  -- Owner has absolute, universal authority across every permission
  IF public._is_owner_uid(v_actor) THEN
    RETURN true;
  END IF;

  -- Validate permission vocabulary for non-owner admins
  IF NOT public._valid_permission(p_permission) THEN
    RETURN false;
  END IF;

  IF NOT public._is_active_admin_uid(v_actor) THEN
    RETURN false;
  END IF;

  -- Geographic scope gate
  IF p_region_id IS NOT NULL AND NOT public._region_in_scope(v_actor, p_region_id) THEN
    RETURN false;
  END IF;

  -- Target-admin gate (ADMIN_* actions are always supervisor-scoped)
  IF p_target_admin_id IS NOT NULL
     AND NOT public.is_supervisor_of(v_actor, p_target_admin_id) THEN
    RETURN false;
  END IF;

  -- Explicit grant check
  SELECT EXISTS (
    SELECT 1 FROM public.admin_permission_grants g
    WHERE g.admin_id = v_actor AND g.permission = p_permission
  ) INTO v_granted;
  IF v_granted THEN
    RETURN true;
  END IF;

  -- Default in-scope matrix for subordinate admins
  SELECT p_permission IN (
    'ADMIN_CREATE','ADMIN_ASSIGN','ADMIN_ROLE_ASSIGN','ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN','ADMIN_SUSPEND',
    'MEMBER_VIEW','MEMBER_VIEW_LOCATION','MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS','MEMBER_VIEW_TIMELINE',
    'MEMBER_MODERATE','MEMBER_WARN','MEMBER_RESTRICT','MEMBER_SUSPEND',
    'EMERGENCY_VIEW','OFFER_CREATE','OFFER_REVIEW',
    'ORDER_VIEW', 'MERCHANT_VIEW', 'DRIVER_VIEW', 'ANALYTICS_VIEW', 'AUDIT_LOG_VIEW'
  ) INTO v_default_in_scope;
  RETURN v_default_in_scope;
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_admin(uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public._is_active_admin_uid(uid);
$function$;

CREATE OR REPLACE FUNCTION public.complete_delivery(
  p_ride_id uuid,
  p_driver_id uuid,
  p_proof_url text DEFAULT NULL::text,
  p_final_distance numeric DEFAULT NULL::numeric,
  p_recipient_otp text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_fare numeric;
  v_ride record;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthorized');
  END IF;

  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;

  IF auth.uid() <> p_driver_id AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  UPDATE public.rides
  SET status = 'completed',
      completed_at = now()
  WHERE id = p_ride_id;

  RETURN jsonb_build_object('success', true, 'ride_id', p_ride_id);
END;
$function$;
