-- 458: admin queue for merchant payout requests.
-- merchant_request_payout / admin_review_payout already exist, but merchant_payout_requests
-- is readable only by its merchant owner, so an admin had no way to list what to review.
-- This adds a read-only, platform-global list RPC gated by the same check admin_review_payout
-- uses (_is_country_admin_uid). It exposes the merchant name and its current ledger balance.
-- No table, policy or grant on existing objects changes. Re-runnable.

CREATE OR REPLACE FUNCTION public.admin_list_payout_requests(
  p_status text DEFAULT 'pending', p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('all','pending','approved','rejected') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS');
  END IF;
  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'requests', coalesce((
    SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at) FROM (
      SELECT r.id, r.merchant_id, m.name AS merchant_name, r.amount, r.currency, r.status,
             r.created_at, r.reviewed_at, r.rejection_reason,
             (SELECT COALESCE(sum(CASE WHEN l.entry_type = 'credit' THEN l.amount ELSE -l.amount END), 0)
                FROM public.merchant_ledger l WHERE l.merchant_id = r.merchant_id) AS merchant_balance
        FROM public.merchant_payout_requests r
        JOIN public.merchants m ON m.id = r.merchant_id
       WHERE (p_status IS NULL OR p_status = 'all' OR r.status = p_status)
       ORDER BY r.created_at
       LIMIT least(greatest(coalesce(p_limit, 50), 1), 200)) x), '[]'::jsonb));
END $$;

REVOKE ALL ON FUNCTION public.admin_list_payout_requests(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_payout_requests(text, integer) TO authenticated;
