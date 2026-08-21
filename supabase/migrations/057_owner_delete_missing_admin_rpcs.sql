-- ============================================================
-- MIGRATION 057: Owner direct deletion + missing admin RPCs (STEP 19)
--
-- Root cause discovered in the field audit (STEP 19):
--   1. Migration 040 REGRESSED decide_approval_request to campaign-only
--      ('Unsupported request type' for everything else). Migration 052
--      restored the full dispatcher, but if the live DB never received 052,
--      member-deletion approvals fail silently.
--   2. The Admin app calls RPCs that NEVER existed:
--        get_pending_deletions / approve_member_deletion / reject_member_deletion
--        get_admin_profile / get_all_admins
--      => AdminPendingDeletionsPage, AdminProfilePage, AdminHierarchyPage dead.
--   3. assign_admin_role / assign_admin_region were created with uuid params
--      (p_admin_id/p_region_id), but the app sends p_email/p_role/p_region
--      (text) => PostgREST "function not found". New email-based overloads.
--   4. Owner deletion ran through the approval pipeline (request -> approve)
--      which is fragile; the owner is the supreme authority and needs a
--      DIRECT deletion path for members AND admins.
--
-- This migration:
--   A. Re-asserts the FULL decide_approval_request dispatcher (052 version).
--   B. owner_delete_member  — owner-only DIRECT soft-delete (members + admins).
--   C. get_pending_deletions / approve_member_deletion / reject_member_deletion
--      — the AdminPendingDeletionsPage contract.
--   D. get_admin_profile / get_all_admins — profile + hierarchy pages.
--   E. assign_admin_role / assign_admin_region — email/name-based overloads.
--   F. admin_update_member_profile — Edit Profile admin action.
--   G. platform_kpi_summary — fixes "column t does not exist" (42703)
--      that broke every dashboard KPI call (bug from 050, kept in 052).
--
-- Security: SECURITY DEFINER + SET search_path; REVOKE-before-GRANT;
-- anon revoked everywhere; authenticated + service_role only.
-- Idempotent: CREATE OR REPLACE everywhere.
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- A. decide_approval_request — full dispatcher (052 re-assert)
--    Fixes the 040 regression for member_delete/member_ban and all
--    admin lifecycle types.
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.decide_approval_request(
  p_request_id uuid,
  p_decision text,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_request public.approval_requests%ROWTYPE;
  v_is_owner boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_decision NOT IN ('approve','reject') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;
  SELECT * INTO v_request FROM public.approval_requests a WHERE a.id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Approval request not found';
  END IF;
  IF v_request.state <> 'pending' THEN
    RAISE EXCEPTION 'Approval request already decided';
  END IF;
  IF v_request.request_type <> 'campaign_approve'
     AND NOT public._valid_approval_type(v_request.request_type) THEN
    RAISE EXCEPTION 'Unsupported request type';
  END IF;

  SELECT public._is_owner_uid(auth.uid()) INTO v_is_owner;

  IF v_request.requested_by = auth.uid() AND NOT v_is_owner THEN
    RAISE EXCEPTION 'Cannot decide your own request';
  END IF;

  IF NOT v_is_owner THEN
    IF v_request.required_approver IS NULL THEN
      RAISE EXCEPTION 'Not authorized to decide this request';
    END IF;
    IF v_request.required_approver <> auth.uid()
       AND NOT public.is_supervisor_of(auth.uid(), v_request.requested_by) THEN
      RAISE EXCEPTION 'Not authorized to decide this request';
    END IF;
  END IF;

  IF p_decision = 'reject'
     AND (p_reason IS NULL OR btrim(p_reason) = '') THEN
    RAISE EXCEPTION 'Rejection requires a reason';
  END IF;

  IF p_decision = 'approve' THEN
    PERFORM public._approval_apply(v_request, p_reason);
    UPDATE public.approval_requests
      SET state = 'approved', reason = p_reason,
          decided_by = auth.uid(), decided_at = now()
      WHERE id = p_request_id;
  ELSE
    UPDATE public.approval_requests
      SET state = 'rejected', reason = p_reason,
          decided_by = auth.uid(), decided_at = now()
      WHERE id = p_request_id;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    v_request.requested_by,
    CASE WHEN p_decision = 'approve' THEN 'Approval granted' ELSE 'Approval rejected' END,
    v_request.request_type || ' — ' || COALESCE(p_reason, ''),
    'approval',
    jsonb_build_object('request_id', p_request_id::text,
                       'decision', p_decision,
                       'request_type', v_request.request_type),
    '/admin/approvals',
    'approval-decide-' || p_request_id::text
  );

  PERFORM public.write_audit(
    'APPROVAL_DECIDED', 'approval_requests', p_request_id::text,
    jsonb_build_object('decision', p_decision,
                       'request_type', v_request.request_type,
                       'reason', p_reason));
END;
$$;

-- ════════════════════════════════════════════════════════════
-- B. owner_delete_member — owner-only DIRECT deletion
--    Members: soft-delete + anonymize via _member_exec_delete.
--    Admins:  deactivate first (admin lifecycle), then soft-delete.
--    Owner target: blocked by the executors below.
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.owner_delete_member(
  p_member_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Only the owner can delete accounts directly';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_member_id) THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_owner_uid(p_member_id) THEN
    RAISE EXCEPTION 'Cannot delete the owner account';
  END IF;

  -- Admins are managed through the admin lifecycle: revoke authority first
  -- (demotes role + deactivates the tree row), then soft-delete.
  IF EXISTS (
    SELECT 1 FROM public.admin_management
    WHERE admin_id = p_member_id AND is_active
  ) THEN
    PERFORM public._admin_exec_deactivate(auth.uid(), p_member_id, p_reason);
  END IF;

  PERFORM public._member_exec_delete(auth.uid(), p_member_id, p_reason);
END;
$$;

-- ════════════════════════════════════════════════════════════
-- C. Pending deletions center (AdminPendingDeletionsPage contract)
-- ════════════════════════════════════════════════════════════

-- Lists pending member_delete approval requests with member context.
-- Returns a JSON array (the app casts the result to List).
CREATE OR REPLACE FUNCTION public.get_pending_deletions()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rows jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', a.id::text,
           'member_email', COALESCE(u.email, ''),
           'member_name', COALESCE(u.full_name, ''),
           'requested_by', COALESCE(ru.email, ''),
           'reason', COALESCE(a.reason, ''),
           'created_at', a.created_at)
         ORDER BY a.created_at DESC), '[]'::jsonb)
    INTO v_rows
    FROM public.approval_requests a
    LEFT JOIN public.users u ON u.id = a.entity_id
    LEFT JOIN public.users ru ON ru.id = a.requested_by
   WHERE a.request_type = 'member_delete'
     AND a.state = 'pending';

  RETURN v_rows;
END;
$$;

-- Approve a member-deletion request (owner / required_approver / superior).
CREATE OR REPLACE FUNCTION public.approve_member_deletion(
  p_deletion_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_reason text;
BEGIN
  SELECT reason INTO v_reason
    FROM public.approval_requests
   WHERE id = p_deletion_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Deletion request not found';
  END IF;
  PERFORM public.decide_approval_request(
    p_deletion_id, 'approve', COALESCE(v_reason, 'Approved by admin')
  );
END;
$$;

-- Reject a member-deletion request (owner / required_approver / superior).
CREATE OR REPLACE FUNCTION public.reject_member_deletion(
  p_deletion_id uuid,
  p_reason text DEFAULT 'Rejected by admin'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.decide_approval_request(p_deletion_id, 'reject', p_reason);
END;
$$;

-- ════════════════════════════════════════════════════════════
-- D. Admin profile + hierarchy (AdminProfilePage / AdminHierarchyPage)
-- ════════════════════════════════════════════════════════════

-- Current admin's profile: role, region, earnings (best-effort).
CREATE OR REPLACE FUNCTION public.get_admin_profile(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_role text;
  v_region_name text;
  v_earnings numeric := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT id, role INTO v_uid, v_role
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  IF v_uid <> auth.uid() AND NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(NULLIF(r.name_en, ''), r.name_ar)
    INTO v_region_name
    FROM public.admin_region_assignments a
    LEFT JOIN public.regions r ON r.id = a.region_id
   WHERE a.admin_id = v_uid
   ORDER BY a.created_at DESC
   LIMIT 1;

  IF to_regclass('public.platform_commissions') IS NOT NULL THEN
    SELECT COALESCE(SUM(commission_amount), 0)
      INTO v_earnings
      FROM public.platform_commissions
     WHERE member_id = v_uid AND status = 'fulfilled';
  END IF;

  RETURN jsonb_build_object(
    'email', p_email,
    'role', v_role,
    'is_owner', public._is_owner_uid(v_uid),
    'region_name', v_region_name,
    'total_earnings', v_earnings
  );
END;
$$;

-- All admins (owner + tree) with region + supervisor context.
-- Returns a JSON array.
CREATE OR REPLACE FUNCTION public.get_all_admins()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rows jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'email', u.email,
           'role', u.role,
           'region_name', r.name_en,
           'is_active', COALESCE(m.is_active, true),
           'supervisor_email', su.email,
           'created_at', u.created_at)
         ORDER BY u.created_at), '[]'::jsonb)
    INTO v_rows
    FROM public.users u
    LEFT JOIN public.admin_management m ON m.admin_id = u.id
    LEFT JOIN public.users su ON su.id = m.supervisor_id
    LEFT JOIN LATERAL (
      SELECT rr.name_en
        FROM public.admin_region_assignments aa
        LEFT JOIN public.regions rr ON rr.id = aa.region_id
       WHERE aa.admin_id = u.id
       ORDER BY aa.created_at DESC
       LIMIT 1
    ) r ON true
   WHERE u.role IN ('owner','admin')
      OR m.admin_id IS NOT NULL;

  RETURN v_rows;
END;
$$;

-- ════════════════════════════════════════════════════════════
-- E. Email/name-based admin lifecycle overloads (app contract)
--    The app sends p_email + p_role / p_region (text). The 034 RPCs
--    expect uuids; these overloads resolve identifiers server-side.
-- ════════════════════════════════════════════════════════════

-- Assign (or create) an admin by email. Hierarchical UI roles
-- (country_admin/governorate_admin/center_admin/village_admin) all map to
-- the DB role 'admin'; hierarchy is expressed via supervisor/region scope.
CREATE OR REPLACE FUNCTION public.assign_admin_role(
  p_email text,
  p_role text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_db_role text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_role NOT IN ('admin','country_admin','governorate_admin','center_admin','village_admin') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  SELECT id INTO v_uid FROM public.users WHERE lower(email) = lower(btrim(p_email));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  v_db_role := CASE WHEN p_role IN ('country_admin','governorate_admin','center_admin','village_admin')
                    THEN 'admin' ELSE p_role END;

  IF EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = v_uid) THEN
    PERFORM public._admin_exec_role(auth.uid(), v_uid, v_db_role, COALESCE(p_reason, 'Role updated'));
  ELSE
    PERFORM public._admin_exec_create(auth.uid(), v_uid, NULL, NULL, 'descendants');
  END IF;
END;
$$;

-- Assign a region scope to an admin, resolving the region by name
-- (Arabic or English, case-insensitive).
CREATE OR REPLACE FUNCTION public.assign_admin_region(
  p_email text,
  p_region text,
  p_scope text DEFAULT 'descendants'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_region_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_region IS NULL OR btrim(p_region) = '' THEN
    RAISE EXCEPTION 'Region is required';
  END IF;
  SELECT id INTO v_uid FROM public.users WHERE lower(email) = lower(btrim(p_email));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  SELECT id INTO v_region_id
    FROM public.regions
   WHERE name_ar ILIKE btrim(p_region)
      OR name_en ILIKE btrim(p_region)
   ORDER BY is_active DESC, type = 'governorate' DESC
   LIMIT 1;
  IF v_region_id IS NULL THEN
    RAISE EXCEPTION 'Region not found';
  END IF;

  PERFORM public._admin_exec_region(auth.uid(), v_uid, v_region_id, p_scope);
END;
$$;

-- ════════════════════════════════════════════════════════════
-- F. admin_update_member_profile — Edit Profile action
--    Owner or admin with MEMBER_MODERATE over the member's region.
--    Only full_name / phone can be changed; role, account_status,
--    verification_status etc. stay behind their own RPCs
--    (users_guard_account_fields enforces that).
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.admin_update_member_profile(
  p_member_id uuid,
  p_full_name text DEFAULT NULL,
  p_phone text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_target_role text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT role INTO v_target_role FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF NOT public.has_permission('MEMBER_MODERATE', public._member_region_id(p_member_id)) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;
  IF p_full_name IS NULL AND p_phone IS NULL THEN
    RAISE EXCEPTION 'Nothing to update';
  END IF;

  UPDATE public.users
     SET full_name = COALESCE(NULLIF(btrim(p_full_name), ''), full_name),
         phone = COALESCE(NULLIF(btrim(p_phone), ''), phone),
         updated_at = now()
   WHERE id = p_member_id;

  PERFORM public.write_audit(
    'MEMBER_PROFILE_UPDATED',
    'users',
    p_member_id::text,
    jsonb_build_object(
      'full_name', p_full_name,
      'phone', p_phone
    )
  );
END;
$$;

-- ════════════════════════════════════════════════════════════
-- G. platform_kpi_summary — fix "column t does not exist"
--    Bug shipped in 050 AND kept in 052: merchants_by_type built
--    jsonb_build_object('type', t, ...) but the subquery aliases
--    the column as `type` (no `AS t`). Every dashboard KPI call
--    failed with 42703. Re-creates the function with the fix.
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.platform_kpi_summary(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL,
  p_region_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_result jsonb;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;

  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);

  SELECT jsonb_build_object(
    -- Members
    'total_users',         (SELECT count(*) FROM users),
    'customers',           (SELECT count(*) FROM users WHERE user_type = 'customer'),
    'providers',           (SELECT count(*) FROM users WHERE user_type = 'provider'),
    'delivery_users',      (SELECT count(*) FROM users WHERE user_type = 'delivery'),
    'merchant_users',      (SELECT count(*) FROM users WHERE user_type = 'merchant'),
    'driver_users',        (SELECT count(*) FROM users WHERE user_type = 'driver'),
    'new_users_period',    (SELECT count(*) FROM users WHERE created_at >= v_from AND created_at <= v_to),
    'pending_verification',(SELECT count(*) FROM users WHERE verification_status = 'pending'),
    'verified_members',    (SELECT count(*) FROM users WHERE verification_status = 'approved'),
    'rejected_members',    (SELECT count(*) FROM users WHERE verification_status = 'rejected'),
    'new_today',           (SELECT count(*) FROM users WHERE created_at >= date_trunc('day', v_now)),
    'new_this_week',       (SELECT count(*) FROM users WHERE created_at >= date_trunc('week', v_now)),
    'new_this_month',      (SELECT count(*) FROM users WHERE created_at >= date_trunc('month', v_now)),

    -- Drivers
    'total_drivers',       (SELECT count(*) FROM drivers),
    'online_drivers',      (SELECT count(*) FROM drivers WHERE is_online = true),
    'verified_drivers',    (SELECT count(*) FROM drivers WHERE is_verified = true),

    -- Merchants
    'total_merchants',     (SELECT count(*) FROM merchants),
    'active_merchants',    (SELECT count(*) FROM merchants WHERE status = 'active'),
    'merchants_by_type',   (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', type, 'count', c)), '[]'::jsonb)
      FROM (SELECT type, count(*) as c FROM merchants GROUP BY type) sub
    ),

    -- Orders
    'total_orders',        (SELECT count(*) FROM orders),
    'orders_today',        (SELECT count(*) FROM orders WHERE created_at >= date_trunc('day', v_now)),
    'orders_this_week',    (SELECT count(*) FROM orders WHERE created_at >= date_trunc('week', v_now)),
    'orders_this_month',   (SELECT count(*) FROM orders WHERE created_at >= date_trunc('month', v_now)),
    'completed_orders',    (SELECT count(*) FROM orders WHERE status = 'completed'),
    'pending_orders',      (SELECT count(*) FROM orders WHERE status = 'pending'),
    'cancelled_orders',    (SELECT count(*) FROM orders WHERE status = 'cancelled'),

    -- Rides & Deliveries
    'total_rides',         (SELECT count(*) FROM rides WHERE service_type = 'ride'),
    'completed_rides',     (SELECT count(*) FROM rides WHERE service_type = 'ride' AND status = 'completed'),
    'active_rides',        (SELECT count(*) FROM rides WHERE service_type = 'ride' AND status IN ('searching','matched','arrived','inTrip')),
    'total_deliveries',    (SELECT count(*) FROM rides WHERE service_type != 'ride'),
    'completed_deliveries',(SELECT count(*) FROM rides WHERE service_type != 'ride' AND status = 'completed'),
    'active_deliveries',   (SELECT count(*) FROM rides WHERE service_type != 'ride' AND status IN ('searching','matched','arrived','inTrip')),

    -- Service Bookings
    'total_service_bookings',  (SELECT count(*) FROM service_bookings),
    'completed_service_bookings',(SELECT count(*) FROM service_bookings WHERE status = 'completed'),

    -- Financial (conditional on permission)
    'total_gmv',           CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,
    'ride_gmv',            CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE service_type = 'ride' AND status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
    ELSE 0 END,
    'delivery_gmv',        CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE service_type != 'ride' AND status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
    ELSE 0 END,
    'service_gmv',         CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(final_price), 0) FROM service_bookings WHERE status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
    ELSE 0 END,
    'platform_commission', CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,
    'driver_earnings_total',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(amount), 0) FROM driver_earnings WHERE created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,
    'total_wallet_liability',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(balance), 0) FROM wallets)
    ELSE 0 END,
    'commission_7pct',     CASE WHEN v_has_revenue THEN
      public._commission_bucket_amount(v_from, v_to, 'provider')
    ELSE 0 END,
    'commission_3pct',     CASE WHEN v_has_revenue THEN
      public._commission_bucket_amount(v_from, v_to, 'merchant')
    ELSE 0 END,

    -- Risk
    'open_complaints',     (SELECT count(*) FROM complaints WHERE status NOT IN ('resolved','closed')),
    'escalated_complaints', (SELECT count(*) FROM complaints WHERE escalated_at IS NOT NULL AND status NOT IN ('resolved','closed')),
    'active_sanctions',    (SELECT count(*) FROM sanctions WHERE is_active = true),
    'sos_active',          (SELECT count(*) FROM sos_alerts WHERE status = 'active'),
    'pending_withdrawals', (SELECT count(*) FROM withdrawal_requests WHERE status = 'pending'),
    'payment_failures',    (SELECT count(*) FROM payment_transactions WHERE status = 'failed' AND created_at >= v_from AND created_at <= v_to),

    -- Period
    'date_from', v_from
  ) || jsonb_build_object('date_to', v_to) INTO v_result;

  RETURN v_result;
END;
$$;

-- ════════════════════════════════════════════════════════════
-- ACL CLOSES (REVOKE-before-GRANT everywhere)
-- ════════════════════════════════════════════════════════════

REVOKE ALL ON FUNCTION public.decide_approval_request(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.decide_approval_request(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.decide_approval_request(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_approval_request(uuid, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.owner_delete_member(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_delete_member(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.get_pending_deletions() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_pending_deletions() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_pending_deletions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_deletions() TO service_role;

REVOKE ALL ON FUNCTION public.approve_member_deletion(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_member_deletion(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.approve_member_deletion(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_member_deletion(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.reject_member_deletion(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_member_deletion(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.reject_member_deletion(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_member_deletion(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.get_admin_profile(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_admin_profile(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_admin_profile(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_profile(text) TO service_role;

REVOKE ALL ON FUNCTION public.get_all_admins() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_all_admins() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_all_admins() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_admins() TO service_role;

REVOKE ALL ON FUNCTION public.assign_admin_role(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_admin_role(text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assign_admin_role(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_admin_role(text, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.assign_admin_region(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_admin_region(text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assign_admin_region(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_admin_region(text, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.admin_update_member_profile(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_member_profile(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_update_member_profile(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_member_profile(uuid, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.platform_kpi_summary(timestamptz, timestamptz, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.platform_kpi_summary(timestamptz, timestamptz, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.platform_kpi_summary(timestamptz, timestamptz, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.platform_kpi_summary(timestamptz, timestamptz, uuid) TO service_role;