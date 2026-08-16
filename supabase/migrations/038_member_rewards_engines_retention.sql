-- ============================================================
-- 038_member_rewards_engines_retention.sql
-- Phase 2.3 — Member rewards + engines + retention (2.3F / M1 + M4,
-- docs/HANDOFF/PHASE_2_3_DECISION_LOCK_REPORT.md §16/038, §4/M1, §4/M4,
-- §14/§16/§17/§25 of the master member-management/support audit).
--
-- Scope (locked design):
--   1. member_rewards — idempotent reward ledger (D7/M4). UNIQUE
--      (user_id, reward_type, period_key) → double-run = no-op (R9).
--   2. platform_settings.rewards — jsonb config (M4): reward content is
--      CONFIG-DRIVEN, never hardcoded. Free-delivery benefit is granted ONLY
--      when business enables it (promotions.free_delivery_enabled, same gate
--      as 039 campaign_validate_benefit).
--   3. run_member_engines(p_run_date) — birthday + anniversary reward
--      issuance (idempotent), campaign expiry (published→expired via the 039
--      lifecycle whitelist) and retention purge (per migration map §16/038).
--      Service-only (scheduler/edge function / app-open best-effort, C6).
--   4. apply_retention_policies() — configurable purge per retention_policies
--      (M1 defaults: location 90d, member_events 5y, audit 7y, sanctions 7y,
--      chat 2y, audio metadata 2y, notifications 1y, campaigns 5y). Location
--      rows hard-deleted; audit rows ARCHIVED-then-purged (never silently
--      destroyed, §25). Every purge is audited (write_audit).
--   5. retention_policies — config table (M1). Engine guards absent tables
--      with to_regclass (036/037 were absorbed into the promotion platform,
--      so emergency_audio_sessions / regional_offers do not exist live).
--
-- Dependencies: 035 (DOB/account_status/member_events, member_events CHECK
-- already covers birthday_reward/anniversary_reward), 039 (campaigns +
-- campaigns_guard_status_change published→expired whitelist), 026
-- (notifications deep_link/idempotency_key).
--
-- Security (030/031/033/034/035 lessons): REVOKE-before-GRANT; RPCs SECURITY
-- DEFINER + SET search_path = public, pg_temp; anon revoked everywhere;
-- engines service_role-only (no client execution); member_rewards has NO
-- client INSERT/UPDATE/DELETE path (engine writes as owner); new tables NOT
-- added to supabase_realtime; no data seeds.
--
-- Idempotent: IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS everywhere;
-- safe to re-run.
-- ============================================================

BEGIN;

-- ─── 1. PLATFORM SETTINGS REWARDS CONFIG (M4) ─────────────────────────
-- Content = config, not code. Shape (admin-managed via platform_settings):
--   rewards: {
--     "birthday": {
--       "enabled": true,
--       "title_en": "Happy Birthday {{name}}!",
--       "title_ar": "عيد ميلاد سعيد {{name}}!",
--       "body_en": "...", "body_ar": "...",
--       "deep_link": "/profile",
--       "benefit": {"kind":"none"},
--       "campaign_id": null
--     },
--     "anniversary": { ... same shape ... }
--   }
-- absent / {} = engine no-op for that type.

ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS rewards jsonb NOT NULL DEFAULT '{}'::jsonb;

-- ─── 2. member_rewards (idempotent reward ledger, D7/M4/R9) ─────────────

CREATE TABLE IF NOT EXISTS public.member_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reward_type text NOT NULL CHECK (reward_type IN ('birthday','anniversary')),
  period_key text NOT NULL,
  benefit jsonb NOT NULL DEFAULT '{"kind":"none"}'::jsonb,
  campaign_id uuid REFERENCES public.campaigns(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'granted'
    CHECK (status IN ('granted','claimed','expired')),
  notified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT member_rewards_unique UNIQUE (user_id, reward_type, period_key)
);

COMMENT ON TABLE public.member_rewards IS
  'Idempotent reward ledger (birthday/anniversary). Duplicate prevention via '
  'UNIQUE(user_id, reward_type, period_key); engine writes only.';

CREATE INDEX IF NOT EXISTS member_rewards_user_period_idx
  ON public.member_rewards (user_id, period_key);

ALTER TABLE public.member_rewards ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.member_rewards FROM PUBLIC;
REVOKE ALL ON TABLE public.member_rewards FROM anon;
GRANT SELECT ON TABLE public.member_rewards TO authenticated;
GRANT ALL ON TABLE public.member_rewards TO service_role;

-- User reads own rewards.
DROP POLICY IF EXISTS member_rewards_own_read ON public.member_rewards;
CREATE POLICY member_rewards_own_read ON public.member_rewards
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- Admin reads rewards for members within MEMBER_VIEW + region scope.
DROP POLICY IF EXISTS member_rewards_admin_read ON public.member_rewards;
CREATE POLICY member_rewards_admin_read ON public.member_rewards
  FOR SELECT TO authenticated
  USING (
    public.has_permission('MEMBER_VIEW', public._member_region_id(user_id))
  );

-- ─── 3. retention_policies (config, M1) ────────────────────────────────
-- Defaults from §25/missing-decision M1. Never purges ACTIVE sanctions;
-- campaign purge touches ARCHIVED campaigns only; absent tables skipped.

CREATE TABLE IF NOT EXISTS public.retention_policies (
  domain text PRIMARY KEY,
  retention_days int NOT NULL CHECK (retention_days >= 0),
  enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.retention_policies IS
  'Configurable retention (M1). apply_retention_policies() purges per row; '
  'admin-managed (is_admin RLS).';

CREATE INDEX IF NOT EXISTS retention_policies_enabled_idx
  ON public.retention_policies (enabled);

ALTER TABLE public.retention_policies ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.retention_policies FROM PUBLIC;
REVOKE ALL ON TABLE public.retention_policies FROM anon;
GRANT SELECT ON TABLE public.retention_policies TO authenticated;
GRANT ALL ON TABLE public.retention_policies TO service_role;

DROP POLICY IF EXISTS retention_policies_admin_all ON public.retention_policies;
CREATE POLICY retention_policies_admin_all ON public.retention_policies
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- M1 defaults (idempotent seed; re-runs never overwrite admin tuning).
INSERT INTO public.retention_policies (domain, retention_days, enabled)
SELECT x.domain, x.retention_days, true
FROM (VALUES
  ('location_updates',        90),
  ('driver_locations',        90),
  ('member_events',         1825),  -- 5y
  ('activity_logs',         2555),  -- 7y (legal)
  ('sanctions',             2555),  -- 7y (active rows never purged)
  ('chat_messages',          730),  -- 2y
  ('emergency_audio_sessions', 730), -- 2y (metadata; table optional/live-absent)
  ('notifications',          365),  -- 1y
  ('campaigns',             1825)   -- lifecycle + 5y audit (archived only)
) AS x(domain, retention_days)
WHERE NOT EXISTS (SELECT 1 FROM public.retention_policies p WHERE p.domain = x.domain);

-- ─── 4. INTERNAL HELPERS (service_role only) ───────────────────────────

-- Reward config for a type from platform_settings (never hardcoded).
CREATE OR REPLACE FUNCTION public._reward_config(p_reward_type text)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    (SELECT ps.rewards -> p_reward_type
     FROM public.platform_settings ps WHERE ps.id = 'default'),
    '{}'::jsonb);
$$;

-- Benefit vocabulary + free-delivery gate (business approval, M4). Mirrors
-- 039 campaign_validate_benefit: free_delivery requires
-- platform_settings.promotions->free_delivery_enabled = true.
CREATE OR REPLACE FUNCTION public._reward_benefit_valid(p_benefit jsonb)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_kind text;
  v_free_delivery_enabled boolean;
BEGIN
  IF p_benefit IS NULL OR p_benefit = '{}'::jsonb THEN
    RETURN true;
  END IF;
  v_kind := p_benefit ->> 'kind';
  IF v_kind IS NULL OR v_kind NOT IN
     ('none','coupon','promo_code','offer','code_copy','free_delivery') THEN
    RETURN false;
  END IF;
  IF v_kind = 'free_delivery' THEN
    SELECT (to_jsonb(ps) #>> '{promotions,free_delivery_enabled}') = 'true'
      INTO v_free_delivery_enabled
      FROM public.platform_settings ps
      WHERE ps.id = 'default';
    RETURN COALESCE(v_free_delivery_enabled, false);
  END IF;
  RETURN true;
END;
$$;

-- ─── 4a. AUDIT WRITE HARDENING (service-context) ────────────────────────
-- write_audit (033) inserts auth.uid()::text, but the engines run in SERVICE
-- context (scheduler / edge function, no JWT) where auth.uid() is NULL and
-- activity_logs.user_id is NOT NULL → the audit itself crashed the purge.
-- Root-cause fix: record a stable system actor when no authenticated user is
-- present. Signature + ACL unchanged (CREATE OR REPLACE preserves grants);
-- the user_id is TEXT (no FK), so 'system' is a safe sentinel.

CREATE OR REPLACE FUNCTION public.write_audit(
  p_action text,
  p_resource text,
  p_resource_id text DEFAULT NULL,
  p_details jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.activity_logs
    (user_id, action, resource, resource_id, details, timestamp)
  VALUES (
    COALESCE(auth.uid()::text, 'system'),
    p_action,
    p_resource,
    p_resource_id,
    p_details,
    now()
  );
END;
$$;

-- ─── 5. apply_retention_policies() ─────────────────────────────────────
-- Config-driven purge. Location rows hard-deleted; audit rows ARCHIVED then
-- purged (activity_logs_archive keeps them — never silently destroyed).
-- Returns a per-domain count summary; every purge is audited.
CREATE OR REPLACE FUNCTION public.apply_retention_policies()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_policy record;
  v_cutoff timestamptz;
  v_count int;
  v_archived int;
  v_result jsonb := '{}'::jsonb;
  v_entry jsonb;
BEGIN
  FOR v_policy IN
    SELECT domain, retention_days FROM public.retention_policies
    WHERE enabled AND retention_days > 0
    ORDER BY domain
  LOOP
    v_cutoff := now() - make_interval(days => v_policy.retention_days);
    v_count := 0;
    v_archived := 0;

    CASE v_policy.domain
      WHEN 'location_updates' THEN
        IF to_regclass('public.location_updates') IS NOT NULL THEN
          DELETE FROM public.location_updates WHERE recorded_at < v_cutoff;
          GET DIAGNOSTICS v_count = ROW_COUNT;
        END IF;
      WHEN 'driver_locations' THEN
        IF to_regclass('public.driver_locations') IS NOT NULL THEN
          DELETE FROM public.driver_locations WHERE updated_at < v_cutoff;
          GET DIAGNOSTICS v_count = ROW_COUNT;
        END IF;
      WHEN 'member_events' THEN
        DELETE FROM public.member_events WHERE created_at < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'chat_messages' THEN
        DELETE FROM public.chat_messages WHERE created_at < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'notifications' THEN
        DELETE FROM public.notifications WHERE created_at < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'sanctions' THEN
        -- legal/evidence ledger: never purge ACTIVE rows, only closed ones.
        DELETE FROM public.sanctions
        WHERE created_at < v_cutoff AND action_status <> 'active';
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'emergency_audio_sessions' THEN
        -- metadata only; table optional (not live — 036 absorbed).
        IF to_regclass('public.emergency_audio_sessions') IS NOT NULL THEN
          DELETE FROM public.emergency_audio_sessions
          WHERE created_at < v_cutoff AND status IN ('ended','cancelled');
          GET DIAGNOSTICS v_count = ROW_COUNT;
        END IF;
      WHEN 'campaigns' THEN
        -- archived rows only; live campaigns are never purged.
        DELETE FROM public.campaigns
        WHERE archived_at IS NOT NULL AND archived_at < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'activity_logs' THEN
        -- archive-then-purge (audit rows survive, never silently destroyed).
        IF to_regclass('public.activity_logs_archive') IS NULL THEN
          CREATE TABLE public.activity_logs_archive (LIKE public.activity_logs);
          ALTER TABLE public.activity_logs_archive
            ADD COLUMN IF NOT EXISTS archived_at timestamptz DEFAULT now();
          ALTER TABLE public.activity_logs_archive ENABLE ROW LEVEL SECURITY;
          REVOKE ALL ON TABLE public.activity_logs_archive FROM PUBLIC;
          REVOKE ALL ON TABLE public.activity_logs_archive FROM anon;
          REVOKE ALL ON TABLE public.activity_logs_archive FROM authenticated;
          GRANT ALL ON TABLE public.activity_logs_archive TO service_role;
          DROP POLICY IF EXISTS activity_logs_archive_admin_select
            ON public.activity_logs_archive;
          CREATE POLICY activity_logs_archive_admin_select
            ON public.activity_logs_archive
            FOR SELECT TO authenticated
            USING (public.is_admin());
        END IF;
        INSERT INTO public.activity_logs_archive
          (id, user_id, action, resource, resource_id, details, ip_address,
           user_agent, timestamp, archived_at)
        SELECT id, user_id, action, resource, resource_id, details, ip_address,
               user_agent, timestamp, now()
        FROM public.activity_logs
        WHERE timestamp < v_cutoff;
        GET DIAGNOSTICS v_archived = ROW_COUNT;
        DELETE FROM public.activity_logs WHERE timestamp < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      ELSE
        CONTINUE;
    END CASE;

    IF v_count > 0 OR v_archived > 0 THEN
      PERFORM public.write_audit(
        'RETENTION_PURGED', v_policy.domain, NULL,
        jsonb_build_object('domain', v_policy.domain, 'purged', v_count,
                           'archived', v_archived));
      v_entry := jsonb_build_object('purged', v_count, 'archived', v_archived);
      v_result := v_result || jsonb_build_object(v_policy.domain, v_entry);
    END IF;
  END LOOP;
  RETURN v_result;
END;
$$;

-- ─── 6. run_member_engines(p_run_date) — birthday/anniversary + expiry ──
-- Idempotent (UNIQUE constraint + ON CONFLICT DO NOTHING + idempotency keys).
-- Service-only (scheduler / edge function / app-open best-effort, C6).
CREATE OR REPLACE FUNCTION public.run_member_engines(
  p_run_date date DEFAULT current_date
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
  v_retention jsonb;
BEGIN
  -- ── birthday pass ────────────────────────────────────────────────
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
    v_config := public._reward_config('birthday');
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
                'benefit', v_benefit));

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

  -- ── anniversary pass ─────────────────────────────────────────────
  FOR v_user IN
    SELECT u.id, u.full_name, u.language, u.created_at
    FROM public.users u
    WHERE u.account_status = 'active'
      AND u.created_at IS NOT NULL
      AND EXTRACT(year FROM p_run_date) > EXTRACT(year FROM u.created_at)
      AND EXTRACT(month FROM u.created_at) = EXTRACT(month FROM p_run_date)
      AND EXTRACT(day FROM u.created_at) = EXTRACT(day FROM p_run_date)
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
    v_config := public._reward_config('anniversary');
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
                                 'years', v_years, 'benefit', v_benefit));

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

  -- ── campaign expiry (offer expiry equivalent; 039 whitelist allows
  --    published→expired) ────────────────────────────────────────────
  UPDATE public.campaigns SET status = 'expired'
  WHERE status = 'published'
    AND ends_at IS NOT NULL
    AND ends_at < now();
  GET DIAGNOSTICS v_campaigns_expired = ROW_COUNT;

  -- ── retention purge (same schedule; §16/038) ──────────────────────
  v_retention := public.apply_retention_policies();

  RETURN jsonb_build_object(
    'run_date', p_run_date::text,
    'birthday_granted', v_birthday_granted,
    'anniversary_granted', v_anniversary_granted,
    'skipped', v_skipped,
    'campaigns_expired', v_campaigns_expired,
    'retention', v_retention);
END;
$$;

-- ─── 7. ACL CLOSES ─────────────────────────────────────────────────────
-- Internal helpers + engines: service_role ONLY (no client execution; the
-- engine is a scheduler/edge-function surface per §26/038). anon revoked.

REVOKE ALL ON FUNCTION public._reward_config(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._reward_config(text) FROM anon;
GRANT EXECUTE ON FUNCTION public._reward_config(text) TO service_role;

REVOKE ALL ON FUNCTION public._reward_benefit_valid(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._reward_benefit_valid(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public._reward_benefit_valid(jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.run_member_engines(date) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.run_member_engines(date) FROM anon;
REVOKE ALL ON FUNCTION public.run_member_engines(date) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.run_member_engines(date) TO service_role;

REVOKE ALL ON FUNCTION public.apply_retention_policies() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_retention_policies() FROM anon;
REVOKE ALL ON FUNCTION public.apply_retention_policies() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.apply_retention_policies() TO service_role;

COMMIT;
