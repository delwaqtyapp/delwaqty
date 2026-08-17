-- ============================================================
-- 045_rewards_config_approvals_region.sql
-- Step 10 — production-hardening of the member reward engine
-- (docs/HANDOFF/STEP_10_BIRTHDAY_ANNIVERSARY_REWARDS.md).
--
-- Extends migration 038 (member_rewards / run_member_engines) WITHOUT
-- creating a duplicate system. Additive and idempotent.
--
-- Scope (locked design):
--   1. platform_settings.promotions — restores the jsonb column the
--      free-delivery gate already reads (038/039 reference it but it was
--      never created). Without it, _reward_benefit_valid silently returns
--      false for kind=free_delivery (dead config).
--   2. _reward_config(reward_type, region_id) — REGION-AWARE config with
--      global fallback. Shape: rewards.{type} = global default;
--      rewards.regions.{region_id}.{type} = regional override. Engine picks
--      the regional override when the member has a region preference, else
--      falls back to the global default.
--   3. run_member_engines(date) — Cairo timezone default run-date; per-user
--      region resolution feeding the region-aware config; config-driven
--      expiry pass (granted -> expired once valid_days elapses); audit.
--   4. Reward config edits flow through the EXISTING approval_requests
--      pipeline: new approval type 'reward_config_change' (034 vocabulary),
--      new RPC request_reward_config_change (owner = global; in-scope admin =
--      regional), applied by _approval_apply via _reward_config_exec.
--   5. ACL closes: engine stays service_role-only; the new RPC is
--      authenticated-only (authorization gates inside); anon revoked
--      everywhere; engines not added to supabase_realtime.
--
-- Security (030/031/034/038 lessons): REVOKE-before-GRANT; SECURITY DEFINER
-- + SET search_path = public, pg_temp; no client INSERT/UPDATE on
-- platform_settings beyond the approved RPC; no hardcoded business rules
-- (validity, content, benefit are all config-driven).
--
-- Idempotent: IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS everywhere;
-- safe to re-run.
-- ============================================================

BEGIN;

-- ─── 1. promotions column (free-delivery gate) ─────────────────────────
-- The rewards engine and campaign validation read
-- platform_settings.promotions->free_delivery_enabled. The column was
-- referenced but never created; add it additively. Empty object = disabled
-- (safe posture; admins enable it explicitly).
ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS promotions jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.platform_settings.promotions IS
  'Promotion platform toggles (free_delivery_enabled). Gate for benefit '
  'kind=free_delivery in rewards and campaigns.';

-- seed so the gate reads a real value (false until an admin opts in)
UPDATE public.platform_settings
SET promotions = jsonb_build_object('free_delivery_enabled', false)
WHERE id = 'default' AND COALESCE(promotions, '{}'::jsonb) = '{}'::jsonb;

-- ─── 2. REGION-AWARE REWARD CONFIG ─────────────────────────────────────
-- Resolution order for (reward_type, region_id):
--   rewards.regions.{region_id}.{reward_type}
--     -> rewards.{reward_type}
--     -> '{}' (engine no-op)
-- Signature gains a trailing defaulted param -> old callers still compile.
CREATE OR REPLACE FUNCTION public._reward_config(
  p_reward_type text,
  p_region_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    CASE WHEN p_region_id IS NOT NULL THEN
      (SELECT ps.rewards #> ARRAY['regions', p_region_id::text, p_reward_type]
       FROM public.platform_settings ps WHERE ps.id = 'default')
    END,
    (SELECT ps.rewards -> p_reward_type
     FROM public.platform_settings ps WHERE ps.id = 'default'),
    '{}'::jsonb);
$$;

-- ─── 3. run_member_engines — Cairo TZ + region config + expiry ─────────
CREATE OR REPLACE FUNCTION public.run_member_engines(
  p_run_date date DEFAULT (now() AT TIME ZONE 'Africa/Cairo')::date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user record;
  v_config jsonb;
  v_benefit jsonb;
  v_campaign_id uuid;
  v_deep_link text;
  v_title text;
  v_body text;
  v_lang text;
  v_years int;
  v_birthday_granted int := 0;
  v_anniversary_granted int := 0;
  v_skipped int := 0;
  v_campaigns_expired int := 0;
  v_rewards_expired int := 0;
  v_region_id uuid;
  v_retention jsonb;
BEGIN
  -- ── birthday pass (region-aware config; idempotent ledger) ────────
  FOR v_user IN
    SELECT u.id, u.full_name, u.language
    FROM public.users u
    WHERE u.account_status = 'active'
      AND u.date_of_birth IS NOT NULL
      AND EXTRACT(month FROM u.date_of_birth) = EXTRACT(month FROM p_run_date)
      AND EXTRACT(day FROM u.date_of_birth) = EXTRACT(day FROM p_run_date)
      AND u.role IN ('customer','provider','driver','delivery','merchant')
      AND NOT EXISTS (
        SELECT 1 FROM public.member_rewards mr
        WHERE mr.user_id = u.id
          AND mr.reward_type = 'birthday'
          AND mr.period_key =
              'birthday:' || EXTRACT(year FROM p_run_date)::int
      )
  LOOP
    SELECT public._member_region_id(v_user.id) INTO v_region_id;
    v_config := public._reward_config('birthday', v_region_id);
    IF COALESCE((v_config ->> 'enabled')::boolean, false) = false THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;
    v_benefit := COALESCE(v_config -> 'benefit', '{"kind":"none"}'::jsonb);
    IF NOT public._reward_benefit_valid(v_benefit) THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;
    v_campaign_id := NULL;
    IF v_config ? 'campaign_id' THEN
      BEGIN
        SELECT c.id INTO v_campaign_id
        FROM public.campaigns c
        WHERE c.id = (v_config ->> 'campaign_id')::uuid;
      EXCEPTION WHEN others THEN
        v_campaign_id := NULL;
      END;
    END IF;

    INSERT INTO public.member_rewards
      (user_id, reward_type, period_key, benefit, campaign_id, status, notified_at)
    VALUES (
      v_user.id, 'birthday',
      'birthday:' || EXTRACT(year FROM p_run_date)::int,
      v_benefit, v_campaign_id, 'granted', now()
    )
    ON CONFLICT (user_id, reward_type, period_key) DO NOTHING;

    IF FOUND THEN
      v_birthday_granted := v_birthday_granted + 1;
      v_lang := COALESCE(v_user.language, 'en');
      IF v_lang = 'ar' THEN
        v_title := COALESCE(v_config ->> 'title_ar', v_config ->> 'title_en', '');
        v_body := COALESCE(v_config ->> 'body_ar', v_config ->> 'body_en', '');
      ELSE
        v_title := COALESCE(v_config ->> 'title_en', v_config ->> 'title_ar', '');
        v_body := COALESCE(v_config ->> 'body_en', v_config ->> 'body_ar', '');
      END IF;
      v_title := replace(v_title, '{{name}}',
                         COALESCE(v_user.full_name, ''));
      v_body := replace(v_body, '{{name}}',
                        COALESCE(v_user.full_name, ''));
      v_deep_link := COALESCE(v_config ->> 'deep_link', '/profile');

      INSERT INTO public.member_events (user_id, event_type, title, payload)
      VALUES (v_user.id, 'birthday_reward', 'Birthday reward',
              jsonb_build_object(
                'period_key', 'birthday:' || EXTRACT(year FROM p_run_date)::int,
                'benefit', v_benefit,
                'region_id', v_region_id));

      INSERT INTO public.notifications
        (user_id, title, body, type, data, deep_link, idempotency_key)
      VALUES (
        v_user.id, v_title, v_body, 'reward',
        jsonb_build_object('reward_type', 'birthday',
                           'period_key', 'birthday:' || EXTRACT(year FROM p_run_date)::int),
        v_deep_link,
        'reward-birthday-' || EXTRACT(year FROM p_run_date)::int || '-' || v_user.id::text
      )
      ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    END IF;
  END LOOP;

  -- ── anniversary pass (region-aware config; idempotent ledger) ──────
  FOR v_user IN
    SELECT u.id, u.full_name, u.language, u.created_at
    FROM public.users u
    WHERE u.account_status = 'active'
      AND u.created_at IS NOT NULL
      AND EXTRACT(year FROM p_run_date) > EXTRACT(year FROM (u.created_at AT TIME ZONE 'Africa/Cairo'))
      AND EXTRACT(month FROM (u.created_at AT TIME ZONE 'Africa/Cairo')) =
          EXTRACT(month FROM p_run_date)
      AND EXTRACT(day FROM (u.created_at AT TIME ZONE 'Africa/Cairo')) =
          EXTRACT(day FROM p_run_date)
      AND u.role IN ('customer','provider','driver','delivery','merchant')
      AND NOT EXISTS (
        SELECT 1 FROM public.member_rewards mr
        WHERE mr.user_id = u.id
          AND mr.reward_type = 'anniversary'
          AND mr.period_key =
              'anniversary:' || (EXTRACT(year FROM p_run_date)::int
                                 - EXTRACT(year FROM u.created_at)::int)
      )
  LOOP
    SELECT public._member_region_id(v_user.id) INTO v_region_id;
    v_config := public._reward_config('anniversary', v_region_id);
    IF COALESCE((v_config ->> 'enabled')::boolean, false) = false THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;
    v_benefit := COALESCE(v_config -> 'benefit', '{"kind":"none"}'::jsonb);
    IF NOT public._reward_benefit_valid(v_benefit) THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;
    v_years := EXTRACT(year FROM p_run_date)::int
               - EXTRACT(year FROM v_user.created_at)::int;
    v_campaign_id := NULL;
    IF v_config ? 'campaign_id' THEN
      BEGIN
        SELECT c.id INTO v_campaign_id
        FROM public.campaigns c
        WHERE c.id = (v_config ->> 'campaign_id')::uuid;
      EXCEPTION WHEN others THEN
        v_campaign_id := NULL;
      END;
    END IF;

    INSERT INTO public.member_rewards
      (user_id, reward_type, period_key, benefit, campaign_id, status, notified_at)
    VALUES (v_user.id, 'anniversary', 'anniversary:' || v_years,
            v_benefit, v_campaign_id, 'granted', now())
    ON CONFLICT (user_id, reward_type, period_key) DO NOTHING;

    IF FOUND THEN
      v_anniversary_granted := v_anniversary_granted + 1;
      v_lang := COALESCE(v_user.language, 'en');
      IF v_lang = 'ar' THEN
        v_title := COALESCE(v_config ->> 'title_ar', v_config ->> 'title_en', '');
        v_body := COALESCE(v_config ->> 'body_ar', v_config ->> 'body_en', '');
      ELSE
        v_title := COALESCE(v_config ->> 'title_en', v_config ->> 'title_ar', '');
        v_body := COALESCE(v_config ->> 'body_en', v_config ->> 'body_ar', '');
      END IF;
      v_title := replace(replace(v_title, '{{name}}',
                                 COALESCE(v_user.full_name, '')),
                         '{{years}}', v_years::text);
      v_body := replace(replace(v_body, '{{name}}',
                                COALESCE(v_user.full_name, '')),
                        '{{years}}', v_years::text);
      v_deep_link := COALESCE(v_config ->> 'deep_link', '/profile');

      INSERT INTO public.member_events (user_id, event_type, title, payload)
      VALUES (v_user.id, 'anniversary_reward', 'Anniversary reward',
              jsonb_build_object('period_key', 'anniversary:' || v_years,
                                 'years', v_years, 'benefit', v_benefit,
                                 'region_id', v_region_id));

      INSERT INTO public.notifications
        (user_id, title, body, type, data, deep_link, idempotency_key)
      VALUES (
        v_user.id, v_title, v_body, 'reward',
        jsonb_build_object('reward_type', 'anniversary',
                           'period_key', 'anniversary:' || v_years,
                           'years', v_years),
        v_deep_link,
        'reward-anniversary-' || v_years || '-' || v_user.id::text
      )
      ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    END IF;
  END LOOP;

  -- ── config-driven reward expiry (granted -> expired) ────────────────
  -- valid_days lives in the reward config (global or regional override);
  -- absent/missing => rewards never auto-expire. No hardcoded windows.
  UPDATE public.member_rewards mr
  SET status = 'expired'
  WHERE mr.status = 'granted'
    AND (
      SELECT COALESCE(NULLIF(public._reward_config(
          mr.reward_type, public._member_region_id(mr.user_id)) ->> 'valid_days', '')::int, 0)
    ) > 0
    AND mr.created_at < now() - make_interval(days => (
      SELECT COALESCE(NULLIF(public._reward_config(
          mr.reward_type, public._member_region_id(mr.user_id)) ->> 'valid_days', '')::int, 0)
    ));
  GET DIAGNOSTICS v_rewards_expired = ROW_COUNT;

  -- ── campaign expiry (039 whitelist: published -> expired) ───────────
  UPDATE public.campaigns SET status = 'expired'
  WHERE status = 'published'
    AND ends_at IS NOT NULL
    AND ends_at < now();
  GET DIAGNOSTICS v_campaigns_expired = ROW_COUNT;

  IF v_rewards_expired > 0 THEN
    PERFORM public.write_audit(
      'REWARDS_EXPIRED', 'member_rewards', NULL,
      jsonb_build_object('expired', v_rewards_expired));
  END IF;

  -- ── retention purge ────────────────────────────────────────────────
  v_retention := public.apply_retention_policies();

  RETURN jsonb_build_object(
    'run_date', p_run_date::text,
    'birthday_granted', v_birthday_granted,
    'anniversary_granted', v_anniversary_granted,
    'skipped', v_skipped,
    'rewards_expired', v_rewards_expired,
    'campaigns_expired', v_campaigns_expired,
    'retention', v_retention);
END;
$$;

-- ─── 4. REWARD CONFIG THROUGH THE APPROVAL PIPELINE ────────────────────
-- 4a. Extend the 034 approval-type vocabulary (idempotent re-declare).
CREATE OR REPLACE FUNCTION public._valid_approval_type(p_type text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_type IN (
    'admin_create','admin_role_change','admin_region_change',
    'admin_supervisor_change','admin_deactivate',
    'campaign_approve','member_ban','member_delete',
    'offer_approve','offer_publish','reward_config_change'
  );
$$;

-- 4b. Apply an approved reward-config change (internal; called by
-- _approval_apply when a reward_config_change request is approved).
--   * global (region_id NULL): owner-only decider.
--   * regional (region_id set): decider must be an admin with the region in
--     scope (034 has_permission / _region_in_scope semantics).
--   * benefit shape re-validated at apply time (never trust the payload).
CREATE OR REPLACE FUNCTION public._reward_config_exec(
  p_actor uuid,
  p_region_id uuid,
  p_reward_type text,
  p_config jsonb,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_enabled boolean;
  v_benefit jsonb;
  v_path text[];
BEGIN
  IF p_reward_type NOT IN ('birthday','anniversary') THEN
    RAISE EXCEPTION 'Invalid reward type';
  END IF;
  v_benefit := COALESCE(p_config -> 'benefit', '{"kind":"none"}'::jsonb);
  IF NOT public._reward_benefit_valid(v_benefit) THEN
    RAISE EXCEPTION 'Invalid reward benefit';
  END IF;
  v_enabled := COALESCE((p_config ->> 'enabled')::boolean, false);

  IF p_region_id IS NULL THEN
    IF NOT public._is_owner_uid(p_actor) THEN
      RAISE EXCEPTION 'Only owner can change global reward config';
    END IF;
    v_path := ARRAY[p_reward_type];
  ELSE
    IF NOT public._region_in_scope(p_actor, p_region_id) THEN
      RAISE EXCEPTION 'Not authorized for this region';
    END IF;
    v_path := ARRAY['regions', p_region_id::text, p_reward_type];
  END IF;

  UPDATE public.platform_settings
  SET rewards = jsonb_set(
        COALESCE(rewards, '{}'::jsonb),
        v_path,
        COALESCE(p_config, '{}'::jsonb),
        true),
      updated_at = now()
  WHERE id = 'default';

  PERFORM public.write_audit(
    'REWARD_CONFIG_CHANGED', 'platform_settings', 'default',
    jsonb_build_object('reward_type', p_reward_type,
                       'region_id', p_region_id,
                       'enabled', v_enabled,
                       'reason', p_reason));
END;
$$;

-- 4c. Wire the new type into the single approval dispatcher (034).
CREATE OR REPLACE FUNCTION public._approval_apply(p_request approval_requests, p_reason text)
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

    WHEN 'reward_config_change' THEN
      PERFORM public._reward_config_exec(
        auth.uid(),
        NULLIF(v_payload->>'region_id', '')::uuid,
        v_payload->>'reward_type',
        v_payload->'config',
        COALESCE(p_reason, v_payload->>'reason'));

    ELSE
      RAISE EXCEPTION 'Unsupported request type';
  END CASE;
END;
$$;

-- 4d. Submit a reward-config change for approval (admin surface).
--   * p_region_id NULL  -> global config; OWNER-only can request.
--   * p_region_id set   -> regional override; in-scope admin can request
--     (decider = the region admin's superior / owner chain via decide_*).
-- Benefit shape + enabled flag validated BEFORE a request is created.
CREATE OR REPLACE FUNCTION public.request_reward_config_change(
  p_reward_type text,
  p_config jsonb,
  p_region_id uuid DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_benefit jsonb;
  v_entity_id uuid;
  v_admin_user uuid := auth.uid();
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_reward_type NOT IN ('birthday','anniversary') THEN
    RAISE EXCEPTION 'Invalid reward type';
  END IF;
  IF p_config IS NULL OR p_config = '{}'::jsonb THEN
    RAISE EXCEPTION 'Empty reward config';
  END IF;
  IF COALESCE((p_config ->> 'enabled')::boolean, false) IS NULL THEN
    RAISE EXCEPTION 'Missing enabled flag';
  END IF;
  v_benefit := COALESCE(p_config -> 'benefit', '{"kind":"none"}'::jsonb);
  IF NOT public._reward_benefit_valid(v_benefit) THEN
    RAISE EXCEPTION 'Invalid reward benefit';
  END IF;

  IF p_region_id IS NULL THEN
    IF NOT public._is_owner_uid(v_admin_user) THEN
      RAISE EXCEPTION 'Only owner can request global reward config changes';
    END IF;
    v_entity_id := '00000000-0000-0000-0000-000000000000';
  ELSE
    IF NOT public._region_in_scope(v_admin_user, p_region_id) THEN
      RAISE EXCEPTION 'Not authorized for this region';
    END IF;
    v_entity_id := p_region_id;
  END IF;

  RETURN public.submit_approval_request(
    'reward_config_change',
    'platform_settings',
    v_entity_id,
    jsonb_build_object(
      'reward_type', p_reward_type,
      'region_id', p_region_id,
      'config', p_config),
    p_reason,
    NULL);
END;
$$;

-- ─── 5. ACL CLOSES ─────────────────────────────────────────────────────
-- Engine + internal helpers: service_role ONLY (unchanged posture). The
-- new admin RPC: authenticated users only (is_admin / owner / region-scope
-- gates inside). anon revoked everywhere.

REVOKE ALL ON FUNCTION public._reward_config(text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._reward_config(text, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public._reward_config(text, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.run_member_engines(date) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.run_member_engines(date) FROM anon;
REVOKE ALL ON FUNCTION public.run_member_engines(date) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.run_member_engines(date) TO service_role;

REVOKE ALL ON FUNCTION public._reward_config_exec(uuid, uuid, text, jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._reward_config_exec(uuid, uuid, text, jsonb, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._reward_config_exec(uuid, uuid, text, jsonb, text) TO service_role;

REVOKE ALL ON FUNCTION public._approval_apply(public.approval_requests, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._approval_apply(public.approval_requests, text) FROM anon;
REVOKE ALL ON FUNCTION public._approval_apply(public.approval_requests, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public._approval_apply(public.approval_requests, text) TO service_role;

-- New admin RPC: authenticated can invoke; gates live inside.
REVOKE ALL ON FUNCTION public.request_reward_config_change(text, jsonb, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.request_reward_config_change(text, jsonb, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.request_reward_config_change(text, jsonb, uuid, text) TO authenticated;

-- _valid_approval_type: widen ACL for the vocabulary check at the edge.
REVOKE ALL ON FUNCTION public._valid_approval_type(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._valid_approval_type(text) FROM anon;
GRANT EXECUTE ON FUNCTION public._valid_approval_type(text) TO authenticated;

COMMIT;