-- ============================================================================
-- 066_owner_global_financial_audit.sql
-- Additive backend parity for PHASE 1 (Owner Global Financial Dashboard).
-- Read-only, owner-only audit views over regional_collections and
-- platform_settlements. No new tables; authz enforced inside each RPC.
-- Mirrors the conventions of 065 (SECURITY DEFINER, search_path, grants).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. PLATFORM COLLECTION AUDIT (all regions, owner only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_collection_audit()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total       numeric := 0;
  v_settled     numeric := 0;
  v_outstanding numeric := 0;
  v_today       numeric := 0;
  v_week        numeric := 0;
  v_month       numeric := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_owner_uid(auth.uid()) THEN
    RETURN NULL;
  END IF;

  SELECT
    COALESCE(SUM(amount), 0),
    COALESCE(SUM(amount) FILTER (WHERE status = 'settled'), 0),
    COALESCE(SUM(amount) FILTER (WHERE received_at >= date_trunc('day', now())), 0),
    COALESCE(SUM(amount) FILTER (WHERE received_at >= date_trunc('week', now())), 0),
    COALESCE(SUM(amount) FILTER (WHERE received_at >= date_trunc('month', now())), 0)
  INTO v_total, v_settled, v_today, v_week, v_month
  FROM public.regional_collections;

  v_outstanding := GREATEST(0, v_total - v_settled);

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'total', v_total, 'settled', v_settled, 'outstanding', v_outstanding,
      'today', v_today, 'week', v_week, 'month', v_month
    ),
    'by_region', COALESCE((
      SELECT jsonb_agg(r) FROM (
        SELECT jsonb_build_object(
          'region_id', c.region_id,
          'total', COALESCE(SUM(c.amount), 0),
          'settled', COALESCE(SUM(c.amount) FILTER (WHERE c.status = 'settled'), 0),
          'outstanding', GREATEST(0, COALESCE(SUM(c.amount), 0)
            - COALESCE(SUM(c.amount) FILTER (WHERE c.status = 'settled'), 0))
        ) AS r
        FROM public.regional_collections c
        GROUP BY c.region_id
        ORDER BY SUM(c.amount) DESC
      ) sub
    ), '[]'::jsonb),
    'rows', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id, 'admin_id', c.admin_id, 'region_id', c.region_id,
        'account_id', c.account_id, 'amount', c.amount, 'currency', c.currency,
        'reference', c.reference, 'status', c.status, 'received_at', c.received_at
      ))
      FROM (
        SELECT * FROM public.regional_collections ORDER BY received_at DESC LIMIT 200
      ) c
    ), '[]'::jsonb)
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. PLATFORM SETTLEMENT AUDIT (all regions, owner only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_settlement_audit()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total           numeric := 0;
  v_pending         numeric := 0;
  v_under_review    numeric := 0;
  v_approved        numeric := 0;
  v_rejected        numeric := 0;
  v_outstanding     numeric := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_owner_uid(auth.uid()) THEN
    RETURN NULL;
  END IF;

  SELECT
    COALESCE(SUM(amount), 0),
    COALESCE(SUM(amount) FILTER (WHERE status = 'pending'), 0),
    COALESCE(SUM(amount) FILTER (WHERE status = 'under_review'), 0),
    COALESCE(SUM(amount) FILTER (WHERE status = 'approved'), 0),
    COALESCE(SUM(amount) FILTER (WHERE status = 'rejected'), 0)
  INTO v_total, v_pending, v_under_review, v_approved, v_rejected
  FROM public.platform_settlements;

  v_outstanding := GREATEST(0, v_pending + v_under_review);

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'total', v_total, 'pending', v_pending, 'under_review', v_under_review,
      'approved', v_approved, 'rejected', v_rejected, 'outstanding', v_outstanding
    ),
    'by_region', COALESCE((
      SELECT jsonb_agg(r) FROM (
        SELECT jsonb_build_object(
          'region_id', s.region_id,
          'total', COALESCE(SUM(s.amount), 0),
          'pending', COALESCE(SUM(s.amount) FILTER (WHERE s.status = 'pending'), 0),
          'under_review', COALESCE(SUM(s.amount) FILTER (WHERE s.status = 'under_review'), 0),
          'approved', COALESCE(SUM(s.amount) FILTER (WHERE s.status = 'approved'), 0),
          'rejected', COALESCE(SUM(s.amount) FILTER (WHERE s.status = 'rejected'), 0)
        ) AS r
        FROM public.platform_settlements s
        GROUP BY s.region_id
        ORDER BY SUM(s.amount) DESC
      ) sub
    ), '[]'::jsonb),
    'rows', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', s.id, 'admin_id', s.admin_id, 'region_id', s.region_id,
        'amount', s.amount, 'currency', s.currency, 'status', s.status,
        'payment_method', s.payment_method, 'reference', s.reference,
        'created_at', s.created_at, 'reviewed_by', s.reviewed_by
      ))
      FROM (
        SELECT * FROM public.platform_settlements ORDER BY created_at DESC LIMIT 200
      ) s
    ), '[]'::jsonb)
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. GRANTS (authz enforced inside each RPC)
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.platform_collection_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_collection_audit() TO authenticated;

REVOKE ALL ON FUNCTION public.platform_settlement_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_settlement_audit() TO authenticated;
