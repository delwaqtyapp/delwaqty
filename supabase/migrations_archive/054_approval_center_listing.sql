-- MIGRATION 054: Approval Center listing RPC (STEP 18)
--
-- The decide flow (052) restored submitted approvals, but there was no
-- admin RPC to LIST them — the app builds the Approval Center from this.
-- Decision authority still lives in decide_approval_request (owner /
-- required_approver / superior); this is a read-only, admin-gated listing.

CREATE OR REPLACE FUNCTION public.list_approval_requests(
  p_state text DEFAULT 'pending',
  p_limit int DEFAULT 100
)
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
    RETURN NULL;
  END IF;
  IF p_state NOT IN ('pending', 'approved', 'rejected', 'all') THEN
    RAISE EXCEPTION 'Invalid state';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', a.id::text,
           'request_type', a.request_type,
           'entity_type', a.entity_type,
           'entity_id', a.entity_id::text,
           'payload', a.payload,
           'requested_by', a.requested_by::text,
           'required_approver', a.required_approver::text,
           'state', a.state,
           'reason', a.reason,
           'decided_by', a.decided_by::text,
           'created_at', a.created_at)
         ), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT * FROM public.approval_requests a
       WHERE p_state = 'all' OR a.state = p_state
       ORDER BY a.created_at DESC
       LIMIT GREATEST(1, p_limit)
    ) a;

  RETURN jsonb_build_object('requests', v_rows);
END;
$$;

REVOKE ALL ON FUNCTION public.list_approval_requests(text, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_approval_requests(text, int) FROM anon;
GRANT EXECUTE ON FUNCTION public.list_approval_requests(text, int) TO authenticated;