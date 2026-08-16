-- ============================================================
-- 035_member_management_moderation_deletion.sql
-- Phase 2.3 — Member management: moderation + deletion + profile (2.3C / D3/D4,
-- docs/HANDOFF/PHASE_2_3_DECISION_LOCK_REPORT.md §035, §8/§9/§15/§16/§22/§23
-- of the master member-management/support audit).
--
-- Scope (locked design):
--   1. users.date_of_birth / users.account_status / users.anonymized_at (D3/D4).
--   2. users_guard_account_fields — replaces 031 users_guard_role_change: role,
--      account_status, date_of_birth and anonymized_at are SERVER-managed fields.
--      Direct client writers (authenticated/anon) are rejected; SECURITY DEFINER
--      RPCs (current_user = postgres/service_role) are exempt. This also closes
--      the users_update_admin direct-UPDATE role-escalation gap (admin could
--      previously UPDATE any user's role via RLS with no WITH CHECK).
--   3. member_events — §15 timeline/audit trail (21-type CHECK vocabulary),
--      customer-safe own-read RLS + admin timeline RLS (has_permission + region).
--   4. sanctions additive columns (approving_admin_id, evidence_url,
--      action_status) + additive target_role vocabulary ('delivery') + composite
--      (target_user_id, created_at DESC) index.
--   5. Enforcement model: account_status is DERIVED from active sanctions via
--      _enforce_member_status (strictest wins); moderation RPCs + the 038 engine
--      are the only writers.
--   6. Sanction matrix: warning/fine → restricted, suspension → suspended,
--      temporary_ban/permanent_ban → banned. Approval-gated (M3):
--      temporary_ban + permanent_ban (also MEMBER_BAN grant-only, §6). Direct:
--      warning/fine/suspension.
--   7. Approval Center dispatch extended with member_ban + member_delete
--      (decider executes the SAME executors as the direct RPCs; _valid_approval_type
--      already covered both types from 034).
--   8. Deletion (D4): soft-delete + anonymize (PII → NULL, email →
--      deleted-<uuid>@anonymized.invalid), confirmation token = SHA-256 of the
--      member's normalized email, always owner-approved.
--   9. get_member_profile — permission-sectioned admin aggregate (no raw rows);
--      get_member_status (self + admin), get_member_timeline (keyset, self-safe),
--      update_member_dob (self + MEMBER_VIEW admin).
--
-- Security (030/031/033/034 lessons): REVOKE-before-GRANT; RPCs SECURITY DEFINER
-- + SET search_path = public, pg_temp; anon revoked everywhere; member_events
-- has no client INSERT/UPDATE/DELETE path (RPCs write as owner); new tables are
-- NOT added to supabase_realtime; no admin seeds.
--
-- Idempotent: IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS everywhere;
-- safe to re-run.
-- ============================================================

BEGIN;

-- ─── 1. USERS EXTENSIONS (D3/D4) ───────────────────────────────────────
-- account_status is DERIVED from active sanctions (moderation engine owns it).
-- anonymized_at records the deletion instant (D4).

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS date_of_birth date,
  ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS anonymized_at timestamp with time zone;

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_account_status_check' AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_account_status_check
      CHECK (account_status IN ('active','restricted','suspended','banned','deactivated'));
  END IF;
END
$do$;

-- ─── 2. SERVER-MANAGED FIELD GUARD (D3; replaces 031 role-only guard) ───
-- 031's users_guard_role_change only checked role writes and trusted is_admin()
-- without checking authority over the TARGET — any active admin could promote a
-- customer or demote another branch's admin via a direct UPDATE. The 034/035
-- lifecycle + moderation RPCs are the ONLY writers of role/account_status/
-- date_of_birth/anonymized_at; direct client writes are rejected outright.

DROP TRIGGER IF EXISTS users_guard_role_change ON public.users;
DROP FUNCTION IF EXISTS public.users_guard_role_change();

CREATE OR REPLACE FUNCTION public.users_guard_account_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- System context (trigger/service worker/cron, no JWT): allowed. SECURITY
  -- DEFINER RPCs run as the table owner (current_user = postgres/service_role)
  -- and are exempt via the role guard below.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF current_user IN ('authenticated', 'anon') THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Role is managed by the admin lifecycle RPCs';
    END IF;
    IF NEW.account_status IS DISTINCT FROM OLD.account_status THEN
      RAISE EXCEPTION 'Account status is managed by the moderation RPCs';
    END IF;
    IF NEW.date_of_birth IS DISTINCT FROM OLD.date_of_birth THEN
      RAISE EXCEPTION 'Date of birth must be updated via update_member_dob';
    END IF;
    IF NEW.anonymized_at IS DISTINCT FROM OLD.anonymized_at THEN
      RAISE EXCEPTION 'Anonymization is managed by the member deletion RPC';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_guard_account_fields ON public.users;
CREATE TRIGGER users_guard_account_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.users_guard_account_fields();

-- ─── 3. MEMBER EVENTS (timeline / audit trail, §15) ────────────────────

-- Member's canonical region (user_region_preferences, latest wins). Used by RLS
-- and the moderation RPCs for geographic scope. Defined before the member_events
-- RLS policy below references it.
CREATE OR REPLACE FUNCTION public._member_region_id(p_member_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT region_id FROM public.user_region_preferences
  WHERE user_id = p_member_id
  ORDER BY updated_at DESC
  LIMIT 1;
$$;

CREATE TABLE IF NOT EXISTS public.member_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  title text,
  payload jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT member_events_event_type_check CHECK (
    event_type IN (
      'account_created','login',
      'support_opened','support_resolved','support_assigned','support_escalated',
      'complaint_created','complaint_resolved','complaint_assigned','complaint_escalated',
      'moderation_action','suspension','ban',
      'sos','emergency_opened','emergency_resolved','emergency_admin_connected',
      'document_verified','birthday_reward','anniversary_reward',
      'account_deactivated'
    )
  )
);

CREATE INDEX IF NOT EXISTS member_events_user_created_idx
  ON public.member_events (user_id, created_at DESC);

ALTER TABLE public.member_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.member_events FROM PUBLIC;
REVOKE ALL ON TABLE public.member_events FROM anon;
GRANT SELECT ON TABLE public.member_events TO authenticated;
GRANT ALL ON TABLE public.member_events TO service_role;

-- Self-read: own events, customer-safe types only. Types that expose admin
-- identity / internal handling (support_assigned/escalated, complaint_assigned/
-- escalated, emergency_admin_connected) are never surfaced to the member.
DROP POLICY IF EXISTS member_events_own_read ON public.member_events;
CREATE POLICY member_events_own_read ON public.member_events
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id
    AND event_type IN (
      'account_created','login',
      'support_opened','support_resolved',
      'complaint_created','complaint_resolved',
      'moderation_action','suspension','ban',
      'sos','emergency_opened','emergency_resolved',
      'document_verified','birthday_reward','anniversary_reward',
      'account_deactivated'
    )
  );

-- Admin-read: MEMBER_VIEW_TIMELINE + geographic scope over the member's region.
DROP POLICY IF EXISTS member_events_admin_read ON public.member_events;
CREATE POLICY member_events_admin_read ON public.member_events
  FOR SELECT TO authenticated
  USING (
    public.has_permission('MEMBER_VIEW_TIMELINE', public._member_region_id(user_id))
  );

-- ─── 4. SANCTIONS ADDITIVE EXTENSIONS ──────────────────────────────────

ALTER TABLE public.sanctions
  ADD COLUMN IF NOT EXISTS approving_admin_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS evidence_url text,
  ADD COLUMN IF NOT EXISTS action_status text NOT NULL DEFAULT 'active';

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'sanctions_action_status_check' AND conrelid = 'public.sanctions'::regclass
  ) THEN
    ALTER TABLE public.sanctions
      ADD CONSTRAINT sanctions_action_status_check
      CHECK (action_status IN ('active','expired','revoked','completed'));
  END IF;
END
$do$;

-- Additive target_role vocabulary extension: delivery role members can be
-- sanctioned (the 035 RPCs block owner/admin targets before insert).
ALTER TABLE public.sanctions DROP CONSTRAINT IF EXISTS sanctions_target_role_check;
ALTER TABLE public.sanctions ADD CONSTRAINT sanctions_target_role_check
  CHECK (target_role IN ('customer','driver','merchant','provider','admin','delivery'));

CREATE INDEX IF NOT EXISTS sanctions_target_created_idx
  ON public.sanctions (target_user_id, created_at DESC);

-- ─── 5. INTERNAL HELPERS ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._valid_member_sanction_type(p_type text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_type IN ('warning','fine','suspension','temporary_ban','permanent_ban');
$$;

-- Sanction → account_status mapping (D4 matrix). warning/fine restrict.
CREATE OR REPLACE FUNCTION public._sanction_status_for(p_type text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE p_type
    WHEN 'warning' THEN 'restricted'
    WHEN 'fine' THEN 'restricted'
    WHEN 'suspension' THEN 'suspended'
    WHEN 'temporary_ban' THEN 'banned'
    WHEN 'permanent_ban' THEN 'banned'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public._sanction_strictness(p_status text)
RETURNS int
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE p_status
    WHEN 'active' THEN 0
    WHEN 'restricted' THEN 1
    WHEN 'suspended' THEN 2
    WHEN 'banned' THEN 3
    WHEN 'deactivated' THEN 4
    ELSE -1
  END;
$$;

-- M3: temporary/permanent bans always require owner approval (and MEMBER_BAN is
-- grant-only, so bans are double-gated). warning/fine/suspension are direct.
CREATE OR REPLACE FUNCTION public._sanction_requires_approval(p_type text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_type IN ('temporary_ban','permanent_ban');
$$;

-- Recomputes users.account_status from currently-applicable active sanctions
-- (strictest wins). Deactivated accounts are never auto-lifted.
CREATE OR REPLACE FUNCTION public._enforce_member_status(p_member_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_best text := 'active';
  v_deactivated boolean;
  r record;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = p_member_id AND account_status = 'deactivated'
  ) INTO v_deactivated;
  IF v_deactivated THEN
    RETURN;
  END IF;
  FOR r IN
    SELECT s.sanction_type
    FROM public.sanctions s
    WHERE s.target_user_id = p_member_id
      AND s.is_active
      AND s.action_status = 'active'
      AND (s.end_date IS NULL OR s.end_date >= now())
      AND public._valid_member_sanction_type(s.sanction_type)
  LOOP
    IF public._sanction_strictness(public._sanction_status_for(r.sanction_type))
       > public._sanction_strictness(v_best) THEN
      v_best := public._sanction_status_for(r.sanction_type);
    END IF;
  END LOOP;
  UPDATE public.users SET account_status = v_best WHERE id = p_member_id;
END;
$$;

-- ─── 6. EXECUTORS (single code path: direct RPCs + approval dispatcher) ──
-- Authority is validated by the CALLER (issue_sanction / revoke_sanction /
-- decide_approval_request). Executors enforce target-state invariants only, so a
-- decider who is the owner/superior but lacks the underlying grant can still
-- complete an approved action. All writes run as the table owner (SECURITY
-- DEFINER) → exempt from users_guard_account_fields.

CREATE OR REPLACE FUNCTION public._member_exec_sanction(
  p_actor uuid,
  p_member_id uuid,
  p_sanction_type text,
  p_reason text,
  p_duration_days int DEFAULT 0,
  p_amount numeric DEFAULT 0,
  p_evidence_url text DEFAULT NULL,
  p_via_approval boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role text;
  v_status text;
  v_sanction_id uuid;
  v_event_type text;
  v_title text;
  v_body text;
BEGIN
  IF NOT public._valid_member_sanction_type(p_sanction_type) THEN
    RAISE EXCEPTION 'Invalid sanction type';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;
  SELECT role, account_status INTO v_role, v_status
  FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF v_status = 'deactivated' THEN
    RAISE EXCEPTION 'Member account is deactivated';
  END IF;
  IF p_sanction_type = 'permanent_ban'
     AND EXISTS (
       SELECT 1 FROM public.sanctions
       WHERE target_user_id = p_member_id
         AND sanction_type = 'permanent_ban'
         AND is_active
         AND action_status = 'active'
     ) THEN
    RAISE EXCEPTION 'Member already has an active permanent ban';
  END IF;

  INSERT INTO public.sanctions
    (target_user_id, target_role, sanction_type, reason, amount, duration_days,
     end_date, evidence_url, approving_admin_id, issued_by)
  VALUES (
    p_member_id, v_role, p_sanction_type, p_reason, p_amount, p_duration_days,
    CASE WHEN p_duration_days > 0
         THEN now() + (p_duration_days || ' days')::interval
         ELSE NULL END,
    p_evidence_url,
    CASE WHEN p_via_approval THEN p_actor ELSE NULL END,
    p_actor
  )
  RETURNING id INTO v_sanction_id;

  PERFORM public._enforce_member_status(p_member_id);

  v_event_type := CASE p_sanction_type
    WHEN 'suspension' THEN 'suspension'
    WHEN 'temporary_ban' THEN 'ban'
    WHEN 'permanent_ban' THEN 'ban'
    ELSE 'moderation_action'
  END;
  v_title := CASE p_sanction_type
    WHEN 'permanent_ban' THEN 'Account permanently banned'
    WHEN 'temporary_ban' THEN 'Account temporarily banned'
    WHEN 'suspension' THEN 'Account suspended'
    WHEN 'fine' THEN 'Account fined'
    ELSE 'Account restricted'
  END;
  v_body := CASE p_sanction_type
    WHEN 'permanent_ban' THEN 'Your account has been permanently banned.'
    WHEN 'temporary_ban' THEN 'Your account has been temporarily banned.'
    WHEN 'suspension' THEN 'Your account has been suspended.'
    WHEN 'fine' THEN 'A fine has been applied to your account.'
    ELSE 'Your account has been restricted.'
  END;

  INSERT INTO public.member_events (user_id, event_type, title, payload)
  VALUES (p_member_id, v_event_type, v_title,
          jsonb_build_object('sanction_id', v_sanction_id::text,
                             'sanction_type', p_sanction_type,
                             'reason', p_reason));

  PERFORM public.write_audit(
    'SANCTION_ISSUED', 'sanctions', v_sanction_id::text,
    jsonb_build_object('actor', p_actor::text, 'member_id', p_member_id::text,
                       'sanction_type', p_sanction_type, 'reason', p_reason,
                       'via_approval', p_via_approval));

  -- Member-facing notification carries NO admin identity (title is neutral).
  INSERT INTO public.notifications (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    p_member_id, 'Moderation', v_body, 'moderation',
    jsonb_build_object('sanction_id', v_sanction_id::text,
                       'sanction_type', p_sanction_type),
    '/profile',
    'sanction-' || v_sanction_id::text
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

  RETURN v_sanction_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._member_exec_revoke_sanction(
  p_actor uuid,
  p_sanction_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_member_id uuid;
BEGIN
  SELECT target_user_id INTO v_member_id FROM public.sanctions WHERE id = p_sanction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sanction not found';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.sanctions WHERE id = p_sanction_id AND action_status = 'active'
  ) THEN
    RAISE EXCEPTION 'Sanction is not active';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;

  UPDATE public.sanctions
    SET action_status = 'revoked', is_active = false, updated_at = now()
    WHERE id = p_sanction_id;

  PERFORM public._enforce_member_status(v_member_id);

  INSERT INTO public.member_events (user_id, event_type, title, payload)
  VALUES (v_member_id, 'moderation_action', 'Sanction lifted',
          jsonb_build_object('sanction_id', p_sanction_id::text, 'reason', p_reason));

  PERFORM public.write_audit(
    'SANCTION_REVOKED', 'sanctions', p_sanction_id::text,
    jsonb_build_object('actor', p_actor::text, 'member_id', v_member_id::text,
                       'reason', p_reason));

  INSERT INTO public.notifications (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    v_member_id, 'Moderation', 'Your account status has been restored.', 'moderation',
    jsonb_build_object('sanction_id', p_sanction_id::text),
    '/profile',
    'sanction-revoke-' || p_sanction_id::text || '-' || gen_random_uuid()::text
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public._member_exec_delete(
  p_actor uuid,
  p_member_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
BEGIN
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;
  SELECT account_status INTO v_status FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF v_status = 'deactivated' THEN
    RAISE EXCEPTION 'Member account is already deactivated';
  END IF;

  -- D4 soft-delete + anonymization. email is released for re-registration and
  -- replaced by a stable, unique placeholder (FK-safe; anonymized_at marks it).
  UPDATE public.users SET
    account_status = 'deactivated',
    anonymized_at = now(),
    email = 'deleted-' || p_member_id::text || '@anonymized.invalid',
    full_name = NULL,
    phone = NULL,
    username = NULL,
    avatar_url = NULL,
    id_card_url = NULL,
    profile_photo_url = NULL,
    trade_license_url = NULL,
    driving_license_url = NULL
  WHERE id = p_member_id;

  INSERT INTO public.member_events (user_id, event_type, title, payload)
  VALUES (p_member_id, 'account_deactivated', 'Account deleted',
          jsonb_build_object('reason', p_reason));

  PERFORM public.write_audit(
    'MEMBER_DELETED', 'users', p_member_id::text,
    jsonb_build_object('actor', p_actor::text, 'reason', p_reason));
END;
$$;

-- ─── 7. PUBLIC MODERATION RPCS ──────────────────────────────────────────

-- Returns the sanction id (direct types) or the approval request id (bans).
CREATE OR REPLACE FUNCTION public.issue_sanction(
  p_member_id uuid,
  p_sanction_type text,
  p_reason text,
  p_duration_days int DEFAULT 0,
  p_amount numeric DEFAULT 0,
  p_evidence_url text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
  v_perm text;
  v_result uuid;
BEGIN
  IF NOT public._valid_member_sanction_type(p_sanction_type) THEN
    RAISE EXCEPTION 'Invalid sanction type';
  END IF;
  SELECT account_status INTO v_status FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF v_status = 'deactivated' THEN
    RAISE EXCEPTION 'Member account is deactivated';
  END IF;

  v_perm := CASE p_sanction_type
    WHEN 'warning' THEN 'MEMBER_WARN'
    WHEN 'fine' THEN 'MEMBER_RESTRICT'
    WHEN 'suspension' THEN 'MEMBER_SUSPEND'
    ELSE 'MEMBER_BAN'
  END;
  IF NOT public.has_permission(v_perm, public._member_region_id(p_member_id)) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;

  IF public._sanction_requires_approval(p_sanction_type) THEN
    v_result := public.submit_approval_request(
      'member_ban', 'member', p_member_id,
      jsonb_build_object('member_id', p_member_id::text,
                         'sanction_type', p_sanction_type,
                         'duration_days', p_duration_days,
                         'amount', p_amount,
                         'evidence_url', p_evidence_url,
                         'reason', p_reason),
      p_reason);
  ELSE
    v_result := public._member_exec_sanction(
      auth.uid(), p_member_id, p_sanction_type, p_reason,
      p_duration_days, p_amount, p_evidence_url, false);
  END IF;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_sanction(
  p_sanction_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_member_id uuid;
BEGIN
  SELECT target_user_id INTO v_member_id FROM public.sanctions WHERE id = p_sanction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sanction not found';
  END IF;
  IF NOT public.has_permission('MEMBER_MODERATE', public._member_region_id(v_member_id)) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;
  PERFORM public._member_exec_revoke_sanction(auth.uid(), p_sanction_id, p_reason);
END;
$$;

-- Deletion (D4). Returns the approval request id (always owner-approved).
CREATE OR REPLACE FUNCTION public.delete_member_account(
  p_member_id uuid,
  p_confirmation_token text,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
  v_email text;
  v_request_id uuid;
BEGIN
  SELECT account_status, email INTO v_status, v_email FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF v_status = 'deactivated' THEN
    RAISE EXCEPTION 'Member account is already deactivated';
  END IF;
  IF NOT public.has_permission('MEMBER_DELETE', public._member_region_id(p_member_id)) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;
  IF p_confirmation_token IS NULL
     OR p_confirmation_token <> 'DELETE-' || encode(sha256(lower(v_email)::bytea), 'hex') THEN
    RAISE EXCEPTION 'Invalid confirmation token';
  END IF;

  v_request_id := public.submit_approval_request(
    'member_delete', 'member', p_member_id,
    jsonb_build_object('member_id', p_member_id::text, 'reason', p_reason),
    p_reason);
  RETURN v_request_id;
END;
$$;

-- ─── 8. MEMBER SELF + PROFILE RPCS ──────────────────────────────────────

CREATE OR REPLACE FUNCTION public.update_member_dob(
  p_date_of_birth date,
  p_member_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_target uuid;
BEGIN
  v_target := COALESCE(p_member_id, auth.uid());
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_date_of_birth IS NOT NULL THEN
    IF p_date_of_birth > now()::date THEN
      RAISE EXCEPTION 'Date of birth cannot be in the future';
    END IF;
    IF p_date_of_birth < '1900-01-01'::date THEN
      RAISE EXCEPTION 'Date of birth is invalid';
    END IF;
  END IF;
  IF p_member_id IS NOT NULL
     AND p_member_id <> auth.uid()
     AND NOT public.has_permission('MEMBER_VIEW', public._member_region_id(p_member_id)) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;
  UPDATE public.users SET date_of_birth = p_date_of_birth WHERE id = v_target;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
END;
$$;

-- Status for the member themself or a MEMBER_VIEW admin.
CREATE OR REPLACE FUNCTION public.get_member_status(p_member_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
  v_ok boolean;
  v_sanctions jsonb;
BEGIN
  SELECT role, user_type, verification_status, account_status, created_at, updated_at
  INTO v_row
  FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  v_ok := (auth.uid() = p_member_id)
          OR public.has_permission('MEMBER_VIEW', public._member_region_id(p_member_id));
  IF NOT v_ok THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(jsonb_agg(
           jsonb_build_object('id', s.id::text, 'sanction_type', s.sanction_type,
                              'reason', s.reason, 'start_date', s.start_date,
                              'end_date', s.end_date)
           ORDER BY s.created_at DESC), '[]'::jsonb)
  INTO v_sanctions
  FROM public.sanctions s
  WHERE s.target_user_id = p_member_id
    AND s.is_active
    AND s.action_status = 'active';

  RETURN jsonb_build_object(
    'member_id', p_member_id::text,
    'role', v_row.role,
    'user_type', v_row.user_type,
    'verification_status', v_row.verification_status,
    'account_status', v_row.account_status,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at,
    'active_sanctions', v_sanctions);
END;
$$;

-- Permission-sectioned admin aggregate (no raw rows, §24). A section is
-- included ONLY when the viewer holds its permission + region scope.
CREATE OR REPLACE FUNCTION public.get_member_profile(p_member_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
  v_region uuid;
  v_loc boolean;
  v_docs boolean;
  v_support boolean;
  v_mod boolean;
  v_tl boolean;
  v_em boolean;
  v_region_name text;
  v_docs_row record;
  v_support_rows jsonb;
  v_mods jsonb;
  v_events jsonb;
  v_sos jsonb;
  v_result jsonb;
BEGIN
  SELECT role, user_type, verification_status, account_status, language, created_at, updated_at
  INTO v_row
  FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  v_region := public._member_region_id(p_member_id);
  IF NOT public.has_permission('MEMBER_VIEW', v_region) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;
  v_loc := public.has_permission('MEMBER_VIEW_LOCATION', v_region);
  v_docs := public.has_permission('MEMBER_VIEW_DOCUMENTS', v_region);
  v_support := public.has_permission('MEMBER_VIEW_CHAT_HISTORY', v_region);
  v_mod := public.has_permission('MEMBER_VIEW_COMPLAINTS', v_region)
           OR public.has_permission('MEMBER_MODERATE', v_region);
  v_tl := public.has_permission('MEMBER_VIEW_TIMELINE', v_region);
  v_em := public.has_permission('EMERGENCY_VIEW', v_region);

  v_result := jsonb_build_object(
    'member_id', p_member_id::text,
    'basic', jsonb_build_object(
      'role', v_row.role, 'user_type', v_row.user_type,
      'verification_status', v_row.verification_status,
      'account_status', v_row.account_status,
      'language', v_row.language,
      'created_at', v_row.created_at,
      'updated_at', v_row.updated_at));

  IF v_loc THEN
    SELECT r.name_en INTO v_region_name
    FROM public.user_region_preferences p
    LEFT JOIN public.regions r ON r.id = p.region_id
    WHERE p.user_id = p_member_id
    ORDER BY p.updated_at DESC
    LIMIT 1;
    v_result := v_result || jsonb_build_object(
      'location', jsonb_build_object('region_id', v_region, 'region_name', v_region_name));
  END IF;

  IF v_docs THEN
    SELECT id_card_url, trade_license_url, driving_license_url, profile_photo_url
    INTO v_docs_row
    FROM public.users WHERE id = p_member_id;
    v_result := v_result || jsonb_build_object(
      'documents', jsonb_build_object(
        'id_card_url', v_docs_row.id_card_url,
        'trade_license_url', v_docs_row.trade_license_url,
        'driving_license_url', v_docs_row.driving_license_url,
        'profile_photo_url', v_docs_row.profile_photo_url));
  END IF;

  -- Support-chat section lights up when support_rooms lands (master schema).
  IF v_support AND to_regclass('public.support_rooms') IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
             jsonb_build_object('room_id', sr.id::text, 'created_at', sr.created_at)
             ORDER BY sr.created_at DESC), '[]'::jsonb)
    INTO v_support_rows
    FROM public.support_rooms sr
    WHERE sr.customer_id = p_member_id;
    v_result := v_result || jsonb_build_object('support', v_support_rows);
  END IF;

  IF v_mod THEN
    v_mods := jsonb_build_object(
      'complaints',
      (SELECT count(*) FROM public.complaints c
       WHERE c.respondent_id = p_member_id OR c.complainant_id = p_member_id),
      'sanctions',
      (SELECT COALESCE(jsonb_agg(
               jsonb_build_object('sanction_type', s.sanction_type, 'reason', s.reason,
                                  'start_date', s.start_date, 'end_date', s.end_date,
                                  'action_status', s.action_status)
               ORDER BY s.created_at DESC), '[]'::jsonb)
       FROM public.sanctions s WHERE s.target_user_id = p_member_id));
    v_result := v_result || jsonb_build_object('moderation', v_mods);
  END IF;

  IF v_tl THEN
    v_events := (SELECT COALESCE(jsonb_agg(
                   jsonb_build_object('event_type', e.event_type, 'created_at', e.created_at)
                   ORDER BY e.created_at DESC), '[]'::jsonb)
                 FROM (SELECT e.event_type, e.created_at
                       FROM public.member_events e
                       WHERE e.user_id = p_member_id
                       ORDER BY e.created_at DESC LIMIT 10) e);
    v_result := v_result || jsonb_build_object('timeline_summary', v_events);
  END IF;

  IF v_em THEN
    v_sos := (SELECT COALESCE(jsonb_agg(
                jsonb_build_object('id', a.id::text, 'alert_type', a.alert_type,
                                   'status', a.status, 'created_at', a.created_at)
                ORDER BY a.created_at DESC), '[]'::jsonb)
              FROM (SELECT a.id, a.alert_type, a.status, a.created_at
                    FROM public.sos_alerts a
                    WHERE a.user_id = p_member_id
                    ORDER BY a.created_at DESC LIMIT 10) a);
    v_result := v_result || jsonb_build_object('emergency', v_sos);
  END IF;

  v_result := v_result || jsonb_build_object('access', jsonb_build_object(
    'location', v_loc, 'documents', v_docs, 'support', v_support,
    'moderation', v_mod, 'timeline', v_tl, 'emergency', v_em));
  RETURN v_result;
END;
$$;

-- Keyset-paginated timeline. Self sees customer-safe types only; admins see all.
CREATE OR REPLACE FUNCTION public.get_member_timeline(
  p_member_id uuid,
  p_before timestamp with time zone DEFAULT NULL,
  p_limit int DEFAULT 20
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_self boolean;
  v_admin boolean;
  v_rows jsonb;
BEGIN
  IF p_limit < 1 OR p_limit > 50 THEN
    RAISE EXCEPTION 'Invalid limit';
  END IF;
  v_self := auth.uid() = p_member_id;
  v_admin := public.has_permission('MEMBER_VIEW_TIMELINE', public._member_region_id(p_member_id));
  IF NOT (v_self OR v_admin) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(jsonb_agg(
           jsonb_build_object('event_type', e.event_type, 'title', e.title,
                              'payload', e.payload, 'created_at', e.created_at)
           ORDER BY e.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT e.event_type, e.title, e.payload, e.created_at
    FROM public.member_events e
    WHERE e.user_id = p_member_id
      AND (p_before IS NULL OR e.created_at < p_before)
      AND (v_self = false OR e.event_type IN (
            'account_created','login',
            'support_opened','support_resolved',
            'complaint_created','complaint_resolved',
            'moderation_action','suspension','ban',
            'sos','emergency_opened','emergency_resolved',
            'document_verified','birthday_reward','anniversary_reward',
            'account_deactivated'))
    ORDER BY e.created_at DESC
    LIMIT p_limit
  ) e;

  RETURN v_rows;
END;
$$;

-- ─── 9. APPROVAL CENTER DISPATCH EXTENSION (member types) ───────────────
-- _valid_approval_type already covers member_ban/member_delete (034). The
-- decider executes the same executors as the direct RPCs.

CREATE OR REPLACE FUNCTION public._approval_apply(
  p_request public.approval_requests,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payload jsonb;
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  v_payload := COALESCE(p_request.payload, '{}'::jsonb);

  CASE p_request.request_type
    WHEN 'campaign_approve' THEN
      SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_request.entity_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Campaign not found';
      END IF;
      IF v_campaign.status <> 'pending_review' THEN
        RAISE EXCEPTION 'Campaign is not pending review';
      END IF;
      IF NOT public.campaign_targets_authorized(v_campaign.id) THEN
        RAISE EXCEPTION 'Not authorized for this campaign region scope';
      END IF;
      UPDATE public.campaigns SET status = 'approved' WHERE id = v_campaign.id;
      INSERT INTO public.campaign_reviews
        (campaign_id, reviewer_id, action, previous_state, new_state, reason)
      VALUES (v_campaign.id, auth.uid(), 'approve', 'pending_review', 'approved', p_reason);

    WHEN 'admin_create' THEN
      PERFORM public._admin_exec_create(
        auth.uid(),
        (v_payload->>'user_id')::uuid,
        NULLIF(v_payload->>'supervisor_id', '')::uuid,
        NULLIF(v_payload->>'region_id', '')::uuid,
        COALESCE(v_payload->>'scope', 'descendants'));

    WHEN 'admin_role_change' THEN
      PERFORM public._admin_exec_role(
        auth.uid(),
        (v_payload->>'admin_id')::uuid,
        v_payload->>'new_role',
        COALESCE(p_reason, v_payload->>'reason'));

    WHEN 'admin_region_change' THEN
      PERFORM public._admin_exec_region(
        auth.uid(),
        (v_payload->>'admin_id')::uuid,
        (v_payload->>'region_id')::uuid,
        COALESCE(v_payload->>'scope', 'descendants'));

    WHEN 'admin_supervisor_change' THEN
      PERFORM public._admin_exec_supervisor(
        auth.uid(),
        (v_payload->>'admin_id')::uuid,
        (v_payload->>'new_supervisor_id')::uuid,
        COALESCE(p_reason, v_payload->>'reason'));

    WHEN 'admin_deactivate' THEN
      PERFORM public._admin_exec_deactivate(
        auth.uid(),
        (v_payload->>'admin_id')::uuid,
        COALESCE(p_reason, v_payload->>'reason'));

    WHEN 'member_ban' THEN
      PERFORM public._member_exec_sanction(
        auth.uid(),
        (v_payload->>'member_id')::uuid,
        v_payload->>'sanction_type',
        COALESCE(p_reason, v_payload->>'reason'),
        COALESCE((v_payload->>'duration_days')::int, 0),
        COALESCE((v_payload->>'amount')::numeric, 0),
        v_payload->>'evidence_url',
        true);

    WHEN 'member_delete' THEN
      PERFORM public._member_exec_delete(
        auth.uid(),
        (v_payload->>'member_id')::uuid,
        COALESCE(p_reason, v_payload->>'reason'));

    ELSE
      RAISE EXCEPTION 'Unsupported request type';
  END CASE;
END;
$$;

-- ─── 10. ACL CLOSES ─────────────────────────────────────────────────────
-- Internal helpers/executors: service_role only (anon revoked everywhere).
-- Public RPCs: authenticated + service_role. _member_region_id is also granted
-- to authenticated because the member_events admin-read RLS policy invokes it.

REVOKE ALL ON FUNCTION public.users_guard_account_fields() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.users_guard_account_fields() FROM anon;

REVOKE ALL ON FUNCTION public._member_region_id(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._member_region_id(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public._member_region_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._member_region_id(uuid) TO service_role;

REVOKE ALL ON FUNCTION public._valid_member_sanction_type(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._valid_member_sanction_type(text) FROM anon;
GRANT EXECUTE ON FUNCTION public._valid_member_sanction_type(text) TO service_role;

REVOKE ALL ON FUNCTION public._sanction_status_for(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._sanction_status_for(text) FROM anon;
GRANT EXECUTE ON FUNCTION public._sanction_status_for(text) TO service_role;

REVOKE ALL ON FUNCTION public._sanction_strictness(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._sanction_strictness(text) FROM anon;
GRANT EXECUTE ON FUNCTION public._sanction_strictness(text) TO service_role;

REVOKE ALL ON FUNCTION public._sanction_requires_approval(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._sanction_requires_approval(text) FROM anon;
GRANT EXECUTE ON FUNCTION public._sanction_requires_approval(text) TO service_role;

REVOKE ALL ON FUNCTION public._enforce_member_status(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._enforce_member_status(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public._enforce_member_status(uuid) TO service_role;

REVOKE ALL ON FUNCTION public._member_exec_sanction(uuid, uuid, text, text, int, numeric, text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._member_exec_sanction(uuid, uuid, text, text, int, numeric, text, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public._member_exec_sanction(uuid, uuid, text, text, int, numeric, text, boolean) TO service_role;

REVOKE ALL ON FUNCTION public._member_exec_revoke_sanction(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._member_exec_revoke_sanction(uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._member_exec_revoke_sanction(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public._member_exec_delete(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._member_exec_delete(uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._member_exec_delete(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.issue_sanction(uuid, text, text, int, numeric, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.issue_sanction(uuid, text, text, int, numeric, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.issue_sanction(uuid, text, text, int, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_sanction(uuid, text, text, int, numeric, text) TO service_role;

REVOKE ALL ON FUNCTION public.revoke_sanction(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revoke_sanction(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.revoke_sanction(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_sanction(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.delete_member_account(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_member_account(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_member_account(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_member_account(uuid, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.update_member_dob(date, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_member_dob(date, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_member_dob(date, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_member_dob(date, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_member_status(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_member_status(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_member_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_member_status(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_member_profile(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_member_profile(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_member_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_member_profile(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_member_timeline(uuid, timestamp with time zone, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_member_timeline(uuid, timestamp with time zone, int) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_member_timeline(uuid, timestamp with time zone, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_member_timeline(uuid, timestamp with time zone, int) TO service_role;

COMMIT;
