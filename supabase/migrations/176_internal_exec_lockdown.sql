-- 176_internal_exec_lockdown.sql
-- Bughunt F19 (second pass, CRITICAL): internal SECURITY DEFINER exec
-- functions were executable by anon/authenticated. Their authorization
-- checks validate a CALLER-SUPPLIED p_actor parameter, not the actual
-- caller, so any signed-in user could impersonate the owner. Live-verified:
-- a customer account called _member_exec_sanction with p_actor = owner uid
-- and an ACTIVE sanction row was created against a driver.
-- The legit paths are SECURITY DEFINER wrappers (admin_set_user_role,
-- issue_sanction, decide_approval_request, ...) which pass auth.uid()
-- themselves and do not need the caller to hold EXECUTE on the internals.
-- No shipped app code calls any of these directly (verified in lib/).
-- Triggers do not require EXECUTE grants. service_role keeps access.

-- Privilege-escalation core
REVOKE EXECUTE ON FUNCTION public._admin_exec_create(uuid, uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._admin_exec_deactivate(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._admin_exec_reactivate(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._admin_exec_region(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._admin_exec_role(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._admin_exec_supervisor(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._member_exec_delete(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._member_exec_sanction(uuid, uuid, text, text, integer, numeric, text, boolean) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._member_exec_revoke_sanction(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._approval_apply(approval_requests, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._enforce_member_status(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.run_member_engines(date) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._provision_business_target(uuid, text, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._sanction_status_for(text) FROM PUBLIC, anon, authenticated;

-- Delivery handoff internals (anon-callable)
REVOKE EXECUTE ON FUNCTION public._issue_delivery_handoff() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._redact_delivery_handoff() FROM PUBLIC, anon, authenticated;

-- Audit trail integrity: app users must not plant audit rows
REVOKE EXECUTE ON FUNCTION public.write_audit(text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.log_admin_action(text, text, text, jsonb, jsonb, text, text) FROM PUBLIC, anon, authenticated;

-- Notification/push trigger bodies and the settlement sweep (anon-callable)
REVOKE EXECUTE ON FUNCTION public.notify_order_events() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_notification_push() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._enqueue_push(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._settlement_escalation_sweep() FROM PUBLIC, anon, authenticated;
