-- ============================================================================
-- 061_security_hardening_privileged_helpers.sql
-- Additive security hardening. No destructive operations.
--
-- Scope (per master release audit Phase A/B/C/D):
--   1. Close the confirmed search_path gap on trigger/notification helpers.
--   2. Lock privileged INTERNAL SECURITY DEFINER helpers so they are NOT
--      executable by anon / PUBLIC (Postgres default grants EXECUTE to PUBLIC),
--      leaving only service_role able to call them. These helpers are only ever
--      invoked by other SECURITY DEFINER functions or the service_role key,
--      never directly by the Flutter client.
--
-- NOTE: This migration was authored from static analysis of the migrations
-- directory (no live DB available in the build environment). Before applying to
-- production, review on a staging database: a wrong function signature will
-- abort the migration. Signatures were taken verbatim from the CREATE FUNCTION
-- statements in migrations 034/035/038/040/041/042/045/048/057.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. search_path hardening (confirmed gaps)
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.set_updated_at() SET search_path = public, pg_temp;
ALTER FUNCTION public.deactivate_stale_tokens(stale_interval INTERVAL) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_unread_notification_count(p_user_id UUID) SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------------
-- 2. Privileged internal helpers -> service_role only (revoke anon/PUBLIC)
--    Each is already GRANTed to service_role in its defining migration; the
--    GRANT below is idempotent and preserves that contract.
-- ---------------------------------------------------------------------------

-- Admin management escalation internals (034)
ALTER FUNCTION public._is_owner_uid(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public._is_active_admin_uid(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public._region_in_scope(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public._valid_permission(text) SET search_path = public, pg_temp;
ALTER FUNCTION public._valid_approval_type(text) SET search_path = public, pg_temp;
ALTER FUNCTION public._admin_exec_create(uuid, uuid, uuid, uuid, text) SET search_path = public, pg_temp;
ALTER FUNCTION public._admin_exec_role(uuid, uuid, text, text) SET search_path = public, pg_temp;
ALTER FUNCTION public._admin_exec_region(uuid, uuid, uuid, text) SET search_path = public, pg_temp;
ALTER FUNCTION public._admin_exec_supervisor(uuid, uuid, uuid, text) SET search_path = public, pg_temp;
ALTER FUNCTION public._admin_exec_deactivate(uuid, uuid, text) SET search_path = public, pg_temp;
ALTER FUNCTION public._approval_apply(public.approval_requests, text) SET search_path = public, pg_temp;

-- Member moderation internals (035)
ALTER FUNCTION public._valid_member_sanction_type(text) SET search_path = public, pg_temp;
ALTER FUNCTION public._sanction_status_for(text) SET search_path = public, pg_temp;
ALTER FUNCTION public._sanction_strictness(text) SET search_path = public, pg_temp;
ALTER FUNCTION public._sanction_requires_approval(text) SET search_path = public, pg_temp;
ALTER FUNCTION public._enforce_member_status(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public._member_exec_sanction(uuid, uuid, text, text, integer, numeric, text, boolean) SET search_path = public, pg_temp;
ALTER FUNCTION public._member_exec_revoke_sanction(uuid, uuid, text) SET search_path = public, pg_temp;
ALTER FUNCTION public._member_exec_delete(uuid, uuid, text) SET search_path = public, pg_temp;

-- Rewards internals (038 / 045 overloads)
ALTER FUNCTION public._reward_config(text) SET search_path = public, pg_temp;
ALTER FUNCTION public._reward_config(text, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public._reward_benefit_valid(jsonb) SET search_path = public, pg_temp;
ALTER FUNCTION public.run_member_engines(date) SET search_path = public, pg_temp;

-- Campaign / notification / support internals (040/041/042/048)
ALTER FUNCTION public._campaign_region_visible(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.cleanup_invalid_token(text) SET search_path = public, pg_temp;
ALTER FUNCTION public._enqueue_push(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.resolve_support_admin(uuid, boolean, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.chat_rooms_auto_route() SET search_path = public, pg_temp;
ALTER FUNCTION public.chat_rooms_fixup_update() SET search_path = public, pg_temp;
ALTER FUNCTION public.complaints_fixup_update() SET search_path = public, pg_temp;
ALTER FUNCTION public.write_audit(text, text, text, jsonb) SET search_path = public, pg_temp;

-- Revoke anon / PUBLIC execution on the internal helpers above (keep service_role).
-- PUBLIC revoke is safe: none of these are called by the anon or authenticated
-- Flutter client (they are only invoked by other SECURITY DEFINER functions or
-- the service_role key).
DO $$
DECLARE
  fns text[] := ARRAY[
    'public._is_owner_uid(uuid)',
    'public._is_active_admin_uid(uuid)',
    'public._region_in_scope(uuid, uuid)',
    'public._valid_permission(text)',
    'public._valid_approval_type(text)',
    'public._admin_exec_create(uuid, uuid, uuid, uuid, text)',
    'public._admin_exec_role(uuid, uuid, text, text)',
    'public._admin_exec_region(uuid, uuid, uuid, text)',
    'public._admin_exec_supervisor(uuid, uuid, uuid, text)',
    'public._admin_exec_deactivate(uuid, uuid, text)',
    'public._approval_apply(public.approval_requests, text)',
    'public._valid_member_sanction_type(text)',
    'public._sanction_status_for(text)',
    'public._sanction_strictness(text)',
    'public._sanction_requires_approval(text)',
    'public._enforce_member_status(uuid)',
    'public._member_exec_sanction(uuid, uuid, text, text, integer, numeric, text, boolean)',
    'public._member_exec_revoke_sanction(uuid, uuid, text)',
    'public._member_exec_delete(uuid, uuid, text)',
    'public._reward_config(text)',
    'public._reward_config(text, uuid)',
    'public._reward_benefit_valid(jsonb)',
    'public.run_member_engines(date)',
    'public._campaign_region_visible(uuid, uuid)',
    'public.cleanup_invalid_token(text)',
    'public._enqueue_push(uuid)',
    'public.resolve_support_admin(uuid, boolean, uuid)',
    'public.chat_rooms_auto_route()',
    'public.chat_rooms_fixup_update()',
    'public.complaints_fixup_update()',
    'public.write_audit(text, text, text, jsonb)'
  ];
  fn text;
BEGIN
  FOREACH fn IN ARRAY fns LOOP
    BEGIN
      EXECUTE 'REVOKE EXECUTE ON FUNCTION ' || fn || ' FROM PUBLIC, anon;';
      EXECUTE 'GRANT EXECUTE ON FUNCTION ' || fn || ' TO service_role;';
    EXCEPTION WHEN undefined_function THEN
      -- Signature drift between analysis and live DB: skip, review manually.
      RAISE NOTICE '061: skipped (undefined_function) %', fn;
    END;
  END LOOP;
END $$;
