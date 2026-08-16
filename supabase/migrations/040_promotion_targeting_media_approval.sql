-- ============================================================
-- 040_promotion_targeting_media_approval.sql
-- Phase 2 Promotion/Content/Campaign platform — migration 040
-- (owner authorized after 039 gate 🟢; ADR-059; PHASE_2_PROMOTION_IMPLEMENTATION_PLAN.md §3/§5/§6/§7)
--
-- Scope (targeting + audience + approval + lifecycle + media):
--   1. campaign_targets    — normalized many-to-many region targeting
--      (region_id NULL row = national/Egypt; multi-region = one campaign;
--      regional admin scope enforced server-side; owner global).
--   2. audience            — campaigns.target_roles array (039) validated via
--      campaign_validate_target_roles; no new table (minimal + sufficient).
--   3. approval_requests   — the ONE generic Approval Center (2.3 §19 contract,
--      created verbatim here; 2.3's 034 is amended to not recreate it).
--   4. campaign lifecycle RPCs — minimum secure API (submit / decide /
--      publish / pause / resume / archive / cancel / purge_media) + scope
--      helpers (campaign_can_target_region / campaign_targets_authorized).
--   5. campaign_media      — detail/gallery/thumbnail metadata (storage refs
--      only, no binary); campaign_banners stays the display-slot config.
--   6. campaign-media bucket — dedicated storage; private (RLS-gated published
--      read), admin/service upload with campaign ownership + scope validation.
--   7. Direct authenticated writes to campaign CONTENT (campaigns/banners/
--      media/targets) via RLS scope-gated policies; lifecycle STATE transitions
--      only via RPCs (trigger whitelist from 039 enforced server-side).
--   8. Orphan cleanup      — campaign_purge_media (terminal-state campaigns),
--      no background infra.
--
-- Security (016 pattern; 030/031/032/039 lessons):
--   * REVOKE-before-GRANT on every table touched. anon gets NOTHING except the
--     cta allowlist (039). authenticated DML is RLS-gated (is_admin() +
--     campaign_can_target_region / campaign_targets_authorized).
--   * SECURITY DEFINER + SET search_path = public, pg_temp everywhere;
--     REVOKE EXECUTE FROM PUBLIC, anon; GRANT authenticated + service_role.
--   * No DELETE grant on campaigns (archival only, audit preserved).
--   * approval_requests writes are RPC-only (no table DML grants).
--   * No new hierarchy: approval authority = existing is_admin() +
--     admin_region_assignments scope + owner global; required_approver NULL=owner.
--
-- Idempotent / additive / non-destructive. Does not modify 030/031/032/039.
-- No campaign/approval seeds (O6). No feed RPC (041). No analytics (042).
-- ============================================================

BEGIN;

-- ─── 1. campaign_targets (normalized region targeting) ────────

CREATE TABLE IF NOT EXISTS public.campaign_targets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  region_id   uuid REFERENCES public.regions(id) ON DELETE CASCADE,
  created_by  uuid REFERENCES public.users(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT campaign_targets_region_unique UNIQUE (campaign_id, region_id)
);

COMMENT ON TABLE public.campaign_targets IS
  'Normalized many-to-many campaign↔region targeting. A row with region_id NULL '
  '= national (Egypt). At most one national row per campaign (partial unique). '
  'Multi-region = multiple rows on the SAME campaign (no duplicated campaigns). '
  'Regional admins may only target their assigned region + authorized '
  'descendants (validated in RLS via campaign_can_target_region).';

-- At most one national target row per campaign (NULLs are distinct in the
-- composite UNIQUE above, so a partial unique index enforces the invariant).
CREATE UNIQUE INDEX IF NOT EXISTS campaign_targets_national_unique
  ON public.campaign_targets (campaign_id) WHERE region_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_campaign_targets_region
  ON public.campaign_targets (region_id);

ALTER TABLE public.campaign_targets ENABLE ROW LEVEL SECURITY;

-- ─── 2. campaign_media (detail/gallery/thumbnail metadata) ────

CREATE TABLE IF NOT EXISTS public.campaign_media (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  kind        text NOT NULL CHECK (kind IN ('thumbnail','detail_image','gallery_image')),
  image_path  text NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  integer NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.campaign_media IS
  'Generic media metadata for a campaign (thumbnail / detail image / gallery). '
  'Stores storage references only — never binary media in PostgreSQL. '
  'campaign_banners remains the display-slot config (placement/locale/CTA).';

CREATE INDEX IF NOT EXISTS idx_campaign_media_campaign
  ON public.campaign_media (campaign_id, sort_order);

ALTER TABLE public.campaign_media ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS campaign_media_set_updated_at ON public.campaign_media;
CREATE TRIGGER campaign_media_set_updated_at
  BEFORE UPDATE ON public.campaign_media
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ─── 3. approval_requests (generic Approval Center, 2.3 §19 verbatim) ────

CREATE TABLE IF NOT EXISTS public.approval_requests (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_type     text NOT NULL,
  entity_type      text NOT NULL,
  entity_id        uuid,
  payload          jsonb,
  requested_by     uuid NOT NULL REFERENCES public.users(id),
  required_approver uuid REFERENCES public.users(id),  -- null = owner
  state            text NOT NULL DEFAULT 'pending'
                   CHECK (state IN ('pending','approved','rejected','cancelled')),
  reason           text,
  decided_by       uuid REFERENCES public.users(id),
  decided_at       timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.approval_requests IS
  'Generic Approval Center (ADR-059: owned by promotion 040; 2.3 034 amended to '
  'not recreate it). campaign_approve requests flow through here. Decisions via '
  'decide_approval_request only; no client DML grants. required_approver NULL = '
  'owner. Approval history is never deleted.';

-- One pending request per (request_type, entity_id).
CREATE UNIQUE INDEX IF NOT EXISTS approval_requests_pending_unique
  ON public.approval_requests (request_type, entity_id) WHERE state = 'pending';

CREATE INDEX IF NOT EXISTS idx_approval_requests_entity
  ON public.approval_requests (entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_approval_requests_state_approver
  ON public.approval_requests (state, required_approver);

ALTER TABLE public.approval_requests ENABLE ROW LEVEL SECURITY;

-- ─── 4. scope helpers (SECURITY DEFINER, 016 pattern) ─────────

-- True when the caller may target a region (NULL = national/global):
--   owner → any region + national; admin with NO region assignments → global;
--   admin with assignments → assigned region + authorized descendants only.
CREATE OR REPLACE FUNCTION public.campaign_can_target_region(p_region_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.is_admin()
    AND (
      NOT EXISTS (
        SELECT 1 FROM public.admin_region_assignments a
        WHERE a.admin_id = auth.uid()
      )
      OR public.is_admin_for_region(p_region_id)
    );
$$;

-- True when the caller has authority over ALL of the campaign's targets
-- (used by RLS policies + RPCs). Empty target set = vacuously true.
CREATE OR REPLACE FUNCTION public.campaign_targets_authorized(p_campaign_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.is_admin()
    AND NOT EXISTS (
      SELECT 1 FROM public.campaign_targets t
      WHERE t.campaign_id = p_campaign_id
        AND NOT public.campaign_can_target_region(t.region_id)
    );
$$;

-- ─── 5. campaign creator audit trigger ────────────────────────
-- Forces status='draft' on INSERT (client inserts always start in draft;
-- the 039 guard trigger only fires on UPDATE, so without this a client
-- insert could bypass the approval lifecycle and land straight in
-- 'published'). Lifecycle state transitions stay RPC-only thereafter.

CREATE OR REPLACE FUNCTION public.campaigns_set_creator()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.status := 'draft';
    NEW.created_by := COALESCE(NEW.created_by, auth.uid());
    NEW.proposed_by := COALESCE(NEW.proposed_by, auth.uid());
  ELSE
    IF auth.uid() IS NOT NULL THEN
      NEW.updated_by := auth.uid();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS campaigns_set_creator ON public.campaigns;
CREATE TRIGGER campaigns_set_creator
  BEFORE INSERT OR UPDATE ON public.campaigns
  FOR EACH ROW
  EXECUTE FUNCTION public.campaigns_set_creator();

-- ─── 6. RLS write policies (content writes) ───────────────────

-- campaigns: admins may create; updates require admin + scope over ALL targets.
DROP POLICY IF EXISTS "campaigns admin insert" ON public.campaigns;
CREATE POLICY "campaigns admin insert" ON public.campaigns
  FOR INSERT WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "campaigns admin update" ON public.campaigns;
CREATE POLICY "campaigns admin update" ON public.campaigns
  FOR UPDATE USING (public.is_admin() AND public.campaign_targets_authorized(id))
  WITH CHECK (public.is_admin() AND public.campaign_targets_authorized(id));

-- campaign_banners (banners of a scoped campaign).
DROP POLICY IF EXISTS "campaign_banners admin insert" ON public.campaign_banners;
CREATE POLICY "campaign_banners admin insert" ON public.campaign_banners
  FOR INSERT WITH CHECK (public.is_admin() AND public.campaign_targets_authorized(campaign_id));

DROP POLICY IF EXISTS "campaign_banners admin update" ON public.campaign_banners;
CREATE POLICY "campaign_banners admin update" ON public.campaign_banners
  FOR UPDATE USING (public.is_admin() AND public.campaign_targets_authorized(campaign_id))
  WITH CHECK (public.is_admin() AND public.campaign_targets_authorized(campaign_id));

DROP POLICY IF EXISTS "campaign_banners admin delete" ON public.campaign_banners;
CREATE POLICY "campaign_banners admin delete" ON public.campaign_banners
  FOR DELETE USING (public.is_admin() AND public.campaign_targets_authorized(campaign_id));

-- campaign_media.
DROP POLICY IF EXISTS "campaign_media admin select" ON public.campaign_media;
CREATE POLICY "campaign_media admin select" ON public.campaign_media
  FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "campaign_media admin insert" ON public.campaign_media;
CREATE POLICY "campaign_media admin insert" ON public.campaign_media
  FOR INSERT WITH CHECK (public.is_admin() AND public.campaign_targets_authorized(campaign_id));

DROP POLICY IF EXISTS "campaign_media admin update" ON public.campaign_media;
CREATE POLICY "campaign_media admin update" ON public.campaign_media
  FOR UPDATE USING (public.is_admin() AND public.campaign_targets_authorized(campaign_id))
  WITH CHECK (public.is_admin() AND public.campaign_targets_authorized(campaign_id));

DROP POLICY IF EXISTS "campaign_media admin delete" ON public.campaign_media;
CREATE POLICY "campaign_media admin delete" ON public.campaign_media
  FOR DELETE USING (public.is_admin() AND public.campaign_targets_authorized(campaign_id));

-- campaign_targets: SELECT admin; INSERT gated by region scope; DELETE gated by
-- campaign scope; no UPDATE (targets are replaced via delete+insert).
DROP POLICY IF EXISTS "campaign_targets admin select" ON public.campaign_targets;
CREATE POLICY "campaign_targets admin select" ON public.campaign_targets
  FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "campaign_targets admin insert" ON public.campaign_targets;
CREATE POLICY "campaign_targets admin insert" ON public.campaign_targets
  FOR INSERT WITH CHECK (public.is_admin() AND public.campaign_can_target_region(region_id));

DROP POLICY IF EXISTS "campaign_targets admin delete" ON public.campaign_targets;
CREATE POLICY "campaign_targets admin delete" ON public.campaign_targets
  FOR DELETE USING (public.is_admin() AND public.campaign_targets_authorized(campaign_id));

-- approval_requests: admin manage (Approval Center reads + RPC writes bypass
-- RLS); requester may read own rows. No client INSERT/UPDATE/DELETE grants —
-- writes are RPC-only.
DROP POLICY IF EXISTS "approval_requests admin all" ON public.approval_requests;
CREATE POLICY "approval_requests admin all" ON public.approval_requests
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "approval_requests requester select" ON public.approval_requests;
CREATE POLICY "approval_requests requester select" ON public.approval_requests
  FOR SELECT USING (requested_by = auth.uid());

-- ─── 7. lifecycle RPCs (minimum secure API) ───────────────────

-- SUBMIT: draft|rejected → pending_review; creates the generic approval request.
CREATE OR REPLACE FUNCTION public.campaign_submit(p_campaign_id uuid, p_reason text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
  v_request_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;
  IF v_campaign.status NOT IN ('draft','rejected') THEN
    RAISE EXCEPTION 'Only draft or rejected campaigns can be submitted';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.campaign_targets t WHERE t.campaign_id = p_campaign_id
  ) THEN
    RAISE EXCEPTION 'Campaign must have at least one targeting region';
  END IF;
  IF NOT public.campaign_validate_benefit(v_campaign.benefit) THEN
    RAISE EXCEPTION 'Invalid campaign benefit';
  END IF;
  IF NOT public.campaign_validate_target_roles(v_campaign.target_roles) THEN
    RAISE EXCEPTION 'Invalid campaign audience roles';
  END IF;

  IF v_campaign.status = 'rejected' THEN
    UPDATE public.campaigns SET status = 'draft' WHERE id = p_campaign_id;
  END IF;

  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'submit',
          v_campaign.status, 'pending_review', p_reason);

  UPDATE public.campaigns SET status = 'pending_review' WHERE id = p_campaign_id;

  INSERT INTO public.approval_requests
    (request_type, entity_type, entity_id, payload, requested_by, required_approver)
  VALUES (
    'campaign_approve', 'campaign', p_campaign_id,
    jsonb_build_object(
      'campaign_id', p_campaign_id,
      'code', v_campaign.code,
      'name_ar', v_campaign.name_ar,
      'name_en', v_campaign.name_en,
      'campaign_type', v_campaign.campaign_type,
      'priority', v_campaign.priority,
      'reason', p_reason,
      'targets', COALESCE((
        SELECT jsonb_agg(t.region_id ORDER BY t.created_at)
        FROM public.campaign_targets t WHERE t.campaign_id = p_campaign_id), '[]'::jsonb)
    ),
    auth.uid(),
    NULL
  )
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

-- DECIDE: the single approval-center decision RPC (2.3 §19 signature).
-- Dispatches request_type='campaign_approve'. Self-approval blocked unless the
-- requester is the owner. Rejection requires a reason. Decider must have
-- authority over the campaign's targets (cross-region approval blocked).
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
  v_campaign public.campaigns%ROWTYPE;
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
  IF v_request.request_type <> 'campaign_approve' THEN
    RAISE EXCEPTION 'Unsupported request type';
  END IF;

  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = v_request.entity_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF v_campaign.status <> 'pending_review' THEN
    RAISE EXCEPTION 'Campaign is not pending review';
  END IF;
  IF NOT public.campaign_targets_authorized(v_campaign.id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'owner')
    INTO v_is_owner;

  IF v_request.requested_by = auth.uid() AND NOT v_is_owner THEN
    RAISE EXCEPTION 'Cannot decide your own request';
  END IF;

  IF p_decision = 'reject' AND (p_reason IS NULL OR btrim(p_reason) = '') THEN
    RAISE EXCEPTION 'Rejection requires a reason';
  END IF;

  IF p_decision = 'approve' THEN
    UPDATE public.campaigns SET status = 'approved' WHERE id = v_campaign.id;
    INSERT INTO public.campaign_reviews
      (campaign_id, reviewer_id, action, previous_state, new_state, reason)
    VALUES (v_campaign.id, auth.uid(), 'approve', 'pending_review', 'approved', p_reason);
    UPDATE public.approval_requests
      SET state = 'approved', reason = p_reason,
          decided_by = auth.uid(), decided_at = now()
      WHERE id = p_request_id;
    INSERT INTO public.notifications (user_id, title, body, type, deep_link, idempotency_key)
    VALUES (v_request.requested_by,
            'تمت الموافقة على الحملة',
            'الحملة: ' || v_campaign.name_ar,
            'promotion',
            '/campaign/' || v_campaign.id::text,
            'campaign-approve-' || p_request_id::text);
  ELSE
    UPDATE public.campaigns SET status = 'rejected' WHERE id = v_campaign.id;
    INSERT INTO public.campaign_reviews
      (campaign_id, reviewer_id, action, previous_state, new_state, reason)
    VALUES (v_campaign.id, auth.uid(), 'reject', 'pending_review', 'rejected', p_reason);
    UPDATE public.approval_requests
      SET state = 'rejected', reason = p_reason,
          decided_by = auth.uid(), decided_at = now()
      WHERE id = p_request_id;
    INSERT INTO public.notifications (user_id, title, body, type, deep_link, idempotency_key)
    VALUES (v_request.requested_by,
            'تم رفض الحملة',
            'الحملة: ' || v_campaign.name_ar || ' — ' || p_reason,
            'promotion',
            '/campaign/' || v_campaign.id::text,
            'campaign-reject-' || p_request_id::text);
  END IF;
END;
$$;

-- PUBLISH: approved|scheduled → published (or scheduled when starts_at is in the
-- future). Global/national campaigns require global authority. Window enforced.
CREATE OR REPLACE FUNCTION public.campaign_publish(p_campaign_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
  v_has_national boolean;
  v_is_owner boolean;
  v_scoped boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;
  IF v_campaign.status NOT IN ('approved','scheduled') THEN
    RAISE EXCEPTION 'Campaign must be approved or scheduled to publish';
  END IF;
  IF v_campaign.ends_at IS NOT NULL AND v_campaign.ends_at <= now() THEN
    RAISE EXCEPTION 'Campaign window has expired';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.campaign_targets t
    WHERE t.campaign_id = p_campaign_id AND t.region_id IS NULL
  ) INTO v_has_national;

  IF v_has_national THEN
    SELECT EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'owner')
      INTO v_is_owner;
    SELECT EXISTS (
      SELECT 1 FROM public.admin_region_assignments a WHERE a.admin_id = auth.uid()
    ) INTO v_scoped;
    IF NOT v_is_owner AND v_scoped THEN
      RAISE EXCEPTION 'Only global authority can publish a national campaign';
    END IF;
  END IF;

  IF v_campaign.starts_at IS NOT NULL AND v_campaign.starts_at > now() THEN
    UPDATE public.campaigns SET status = 'scheduled' WHERE id = p_campaign_id;
    INSERT INTO public.campaign_reviews
      (campaign_id, reviewer_id, action, previous_state, new_state, reason)
    VALUES (p_campaign_id, auth.uid(), 'publish', v_campaign.status, 'scheduled', NULL);
    RETURN 'scheduled';
  ELSE
    UPDATE public.campaigns SET status = 'published', published_at = now()
    WHERE id = p_campaign_id;
    INSERT INTO public.campaign_reviews
      (campaign_id, reviewer_id, action, previous_state, new_state, reason)
    VALUES (p_campaign_id, auth.uid(), 'publish', v_campaign.status, 'published', NULL);
    RETURN 'published';
  END IF;
END;
$$;

-- PAUSE: published → paused.
CREATE OR REPLACE FUNCTION public.campaign_pause(p_campaign_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;
  IF v_campaign.status <> 'published' THEN
    RAISE EXCEPTION 'Only published campaigns can be paused';
  END IF;
  UPDATE public.campaigns SET status = 'paused' WHERE id = p_campaign_id;
  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'pause', 'published', 'paused', p_reason);
END;
$$;

-- RESUME: paused → published (window still valid).
CREATE OR REPLACE FUNCTION public.campaign_resume(p_campaign_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;
  IF v_campaign.status <> 'paused' THEN
    RAISE EXCEPTION 'Only paused campaigns can be resumed';
  END IF;
  IF v_campaign.ends_at IS NOT NULL AND v_campaign.ends_at <= now() THEN
    RAISE EXCEPTION 'Campaign window has expired';
  END IF;
  UPDATE public.campaigns SET status = 'published', published_at = now()
  WHERE id = p_campaign_id;
  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'resume', 'paused', 'published', NULL);
END;
$$;

-- ARCHIVE: terminal-ward states → archived (audit preserved).
CREATE OR REPLACE FUNCTION public.campaign_archive(p_campaign_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;
  IF v_campaign.status NOT IN ('published','paused','expired','cancelled','rejected') THEN
    RAISE EXCEPTION 'Campaign cannot be archived from current state';
  END IF;
  UPDATE public.campaigns SET status = 'archived', archived_at = now()
  WHERE id = p_campaign_id;
  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'archive', v_campaign.status, 'archived', p_reason);
END;
$$;

-- CANCEL: pre-publish states → cancelled; pending approval request cancelled.
CREATE OR REPLACE FUNCTION public.campaign_cancel(p_campaign_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
  v_is_creator boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  SELECT (v_campaign.proposed_by = auth.uid()) INTO v_is_creator;
  IF NOT v_is_creator AND NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign';
  END IF;
  IF v_campaign.status NOT IN ('draft','pending_review','approved','scheduled') THEN
    RAISE EXCEPTION 'Campaign cannot be cancelled from current state';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Cancellation requires a reason';
  END IF;
  UPDATE public.campaigns SET status = 'cancelled' WHERE id = p_campaign_id;
  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'cancel', v_campaign.status, 'cancelled', p_reason);
  UPDATE public.approval_requests
    SET state = 'cancelled', reason = COALESCE(reason, p_reason), decided_at = now()
  WHERE request_type = 'campaign_approve' AND entity_id = p_campaign_id AND state = 'pending';
END;
$$;

-- ORPHAN CLEANUP: purge storage objects + deactivate media metadata for a
-- terminal-state campaign. Audit metadata (banners/media rows) is preserved.
CREATE OR REPLACE FUNCTION public.campaign_purge_media(p_campaign_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.campaigns c
    WHERE c.id = p_campaign_id
      AND c.status IN ('archived','cancelled','rejected')
  ) THEN
    RAISE EXCEPTION 'Campaign must be in a terminal state to purge media';
  END IF;
  -- storage.protect_delete() blocks direct SQL DELETE unless the GUC is set.
  PERFORM set_config('storage.allow_delete_query', 'true', true);
  DELETE FROM storage.objects
  WHERE bucket_id = 'campaign-media'
    AND public.campaign_id_from_storage_path(name) = p_campaign_id;
  PERFORM set_config('storage.allow_delete_query', 'false', true);
  UPDATE public.campaign_media SET is_active = false WHERE campaign_id = p_campaign_id;
  UPDATE public.campaign_banners SET is_active = false WHERE campaign_id = p_campaign_id;
END;
$$;

-- ─── 8. storage helpers (campaign-media ownership) ────────────

-- Extracts campaign_id from an object path `campaigns/<campaign_id>/<file>`.
CREATE OR REPLACE FUNCTION public.campaign_id_from_storage_path(p_name text)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN (storage.foldername(p_name))[2] ~
         '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    THEN (storage.foldername(p_name))[2]::uuid
    ELSE NULL
  END;
$$;

-- Published media is readable (unpublished never leaks).
CREATE OR REPLACE FUNCTION public.campaign_published_for_storage(p_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.campaigns c
    WHERE c.id = public.campaign_id_from_storage_path(p_name)
      AND c.status = 'published'
  );
$$;

-- Write-side storage check: admin + real campaign + scope over all targets.
CREATE OR REPLACE FUNCTION public.campaign_scoped_for_storage(p_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.is_admin()
    AND public.campaign_id_from_storage_path(p_name) IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.campaigns c
      WHERE c.id = public.campaign_id_from_storage_path(p_name)
    )
    AND public.campaign_targets_authorized(public.campaign_id_from_storage_path(p_name));
$$;

-- ─── 9. campaign-media storage bucket + policies ──────────────
-- Private bucket (published media readable via policy; unpublished never
-- exposed). Upload/update/delete: authenticated admin with campaign scope.
-- service_role bypasses RLS. anon: nothing. Strict MIME + size at bucket level.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('campaign-media', 'campaign-media', false, 5242880,
        ARRAY['image/png','image/jpeg','image/webp'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "campaign media published read" ON storage.objects;
CREATE POLICY "campaign media published read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'campaign-media' AND public.campaign_published_for_storage(name)
  );

DROP POLICY IF EXISTS "campaign media admin upload" ON storage.objects;
CREATE POLICY "campaign media admin upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'campaign-media' AND public.campaign_scoped_for_storage(name)
  );

DROP POLICY IF EXISTS "campaign media admin update" ON storage.objects;
CREATE POLICY "campaign media admin update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'campaign-media' AND public.campaign_scoped_for_storage(name))
  WITH CHECK (bucket_id = 'campaign-media' AND public.campaign_scoped_for_storage(name));

DROP POLICY IF EXISTS "campaign media admin delete" ON storage.objects;
CREATE POLICY "campaign media admin delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'campaign-media' AND public.campaign_scoped_for_storage(name));

-- ─── 10. grants (REVOKE-before-GRANT) ─────────────────────────

REVOKE ALL ON public.campaign_targets FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.campaign_targets TO authenticated;

REVOKE ALL ON public.campaign_media FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.campaign_media TO authenticated;

REVOKE ALL ON public.approval_requests FROM anon, authenticated;
GRANT SELECT ON public.approval_requests TO authenticated;

REVOKE ALL ON public.campaigns FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.campaigns TO authenticated;

REVOKE ALL ON public.campaign_banners FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.campaign_banners TO authenticated;

-- ─── 11. function ACLs (016 pattern) ──────────────────────────

REVOKE ALL ON FUNCTION public.campaign_can_target_region(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_can_target_region(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_can_target_region(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_targets_authorized(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_targets_authorized(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_targets_authorized(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_submit(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_submit(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_submit(uuid, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.decide_approval_request(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.decide_approval_request(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.decide_approval_request(uuid, text, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_publish(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_publish(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_publish(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_pause(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_pause(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_pause(uuid, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_resume(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_resume(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_resume(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_archive(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_archive(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_archive(uuid, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_cancel(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_cancel(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_cancel(uuid, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_purge_media(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_purge_media(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_purge_media(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_id_from_storage_path(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_id_from_storage_path(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_id_from_storage_path(text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_published_for_storage(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_published_for_storage(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_published_for_storage(text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.campaign_scoped_for_storage(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_scoped_for_storage(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_scoped_for_storage(text)
  TO authenticated, service_role;

COMMIT;
