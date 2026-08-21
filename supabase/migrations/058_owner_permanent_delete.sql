-- ============================================================
-- MIGRATION 058: owner_delete_member v2 — TRUE PERMANENT DELETE
--
-- Owner requirement (session 67): deleting an account must remove
-- it from the platform permanently, no return, and the owner must
-- NOT be asked for a reason (p_reason is now optional).
--
-- v1 (057) soft-deleted (anonymize + deactivate). v2 physically
-- removes the profile AND the auth identity so the account can
-- never sign in again.
--
-- FK strategy (verified against the live DB):
--   * CASCADE / SET NULL columns: handled by the database.
--   * NO ACTION / RESTRICT columns pointing at the deleted user
--     are cleaned explicitly below (campaigns, approvals, admin
--     management, commission rules, chat rooms, ...).
--   * SET NULL on NOT NULL columns (escalation_events.actor_id)
--     and NO ACTION references from other users' rows
--     (reviews.order_id, rides.driver_id) are cleared first.
--
-- Security: owner-only (same guard as v1), cannot delete the
-- owner account, SECURITY DEFINER + search_path, REVOKE-before-
-- GRANT (authenticated + service_role).
-- Idempotent: CREATE OR REPLACE.
-- ============================================================

CREATE OR REPLACE FUNCTION public.owner_delete_member(
  p_member_id uuid,
  p_reason text DEFAULT 'Deleted by owner'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role text;
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
  SELECT role INTO v_role FROM public.users WHERE id = p_member_id;
  IF v_role = 'owner' THEN
    RAISE EXCEPTION 'Cannot delete the owner account';
  END IF;

  PERFORM public.write_audit(
    'MEMBER_DELETED_PERMANENT',
    'users',
    p_member_id::text,
    jsonb_build_object(
      'reason', COALESCE(p_reason, 'Deleted by owner'),
      'deleted_by', auth.uid()::text,
      'deleted_role', v_role
    )
  );

  -- ── NO-ACTION / RESTRICT reference cleanup ──────────────────
  DELETE FROM public.approval_requests
   WHERE requested_by = p_member_id
      OR required_approver = p_member_id
      OR decided_by = p_member_id;
  DELETE FROM public.chat_escalations
   WHERE actor_id = p_member_id
      OR new_admin_id = p_member_id
      OR previous_admin_id = p_member_id;
  DELETE FROM public.admin_region_assignments WHERE created_by = p_member_id;
  DELETE FROM public.campaign_targets WHERE created_by = p_member_id;
  DELETE FROM public.campaign_reviews WHERE reviewer_id = p_member_id;
  DELETE FROM public.campaign_seen WHERE user_id = p_member_id;
  UPDATE public.campaigns
     SET created_by = NULL, proposed_by = NULL, updated_by = NULL
   WHERE created_by = p_member_id
      OR proposed_by = p_member_id
      OR updated_by = p_member_id;
  DELETE FROM public.admin_permission_grants WHERE granted_by = p_member_id;
  UPDATE public.commission_rules
     SET approved_by = NULL, created_by = NULL
   WHERE approved_by = p_member_id OR created_by = p_member_id;
  UPDATE public.platform_commissions
     SET created_by = NULL
   WHERE created_by = p_member_id;
  DELETE FROM public.platform_commissions WHERE member_id = p_member_id;
  UPDATE public.reviews
     SET order_id = NULL
   WHERE order_id IN (SELECT id FROM public.orders WHERE user_id = p_member_id);
  DELETE FROM public.orders WHERE user_id = p_member_id;
  DELETE FROM public.reviews WHERE user_id = p_member_id;
  DELETE FROM public.rides WHERE rider_id = p_member_id;
  DELETE FROM public.ride_ratings WHERE rater_id = p_member_id;
  DELETE FROM public.payment_transactions WHERE user_id = p_member_id;
  DELETE FROM public.merchant_profiles WHERE user_id = p_member_id;
  UPDATE public.merchants
     SET owner_user_id = NULL
   WHERE owner_user_id = p_member_id;
  UPDATE public.rides
     SET driver_id = NULL
   WHERE driver_id IN (SELECT id FROM public.drivers WHERE user_id = p_member_id);
  DELETE FROM public.drivers WHERE user_id = p_member_id;
  UPDATE public.chat_rooms
     SET assigned_admin_id = NULL, escalated_from_admin_id = NULL
   WHERE assigned_admin_id = p_member_id
      OR escalated_from_admin_id = p_member_id;
  DELETE FROM public.admin_management
   WHERE admin_id = p_member_id
      OR created_by = p_member_id
      OR supervisor_id = p_member_id;
  DELETE FROM public.escalation_events
   WHERE actor_id = p_member_id
      OR from_admin_id = p_member_id
      OR to_admin_id = p_member_id;

  -- ── Physical removal: profile, then auth identity ──────────
  DELETE FROM public.users WHERE id = p_member_id;
  DELETE FROM auth.users WHERE id = p_member_id;
END;
$$;

-- ════════════════════════════════════════════════════════════
-- ACL CLOSES
-- ════════════════════════════════════════════════════════════

REVOKE ALL ON FUNCTION public.owner_delete_member(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_delete_member(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid, text) TO service_role;