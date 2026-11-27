-- 457: customer refund requests with admin review and wallet credit.
-- Gap: prod had no way for a customer to ask for a refund on a delivered order
-- (cancel_order already refunds paid orders before delivery). This adds:
--   refund_requests          one open/approved request per order; read-only to clients
--   request_refund()         customer, own delivered+paid order, within 14 days
--   admin_review_refund()    approve (credits the wallet once) or reject (note required);
--                            needs financial permission 'review_refund' (owner always has it)
--   admin_list_refund_requests()
-- All writes go through the DEFINER RPCs; both actions write audit_log.
-- Re-runnable.

CREATE TABLE IF NOT EXISTS public.refund_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  reason_code text NOT NULL CHECK (reason_code IN
    ('missing_item','wrong_item','quality','late','damaged','other')),
  details text CHECK (details IS NULL OR char_length(details) <= 500),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  approved_amount numeric(12,2) CHECK (approved_amount IS NULL OR approved_amount > 0),
  review_note text CHECK (review_note IS NULL OR char_length(review_note) <= 500),
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS refund_requests_one_live_per_order
  ON public.refund_requests (order_id) WHERE status IN ('pending','approved');
CREATE INDEX IF NOT EXISTS refund_requests_user_idx ON public.refund_requests (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS refund_requests_status_idx ON public.refund_requests (status, created_at);

ALTER TABLE public.refund_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.refund_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.refund_requests TO authenticated;

DROP POLICY IF EXISTS refund_requests_select ON public.refund_requests;
CREATE POLICY refund_requests_select ON public.refund_requests
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()
         OR public.has_financial_permission(auth.uid(), 'review_refund'));

CREATE OR REPLACE FUNCTION public.request_refund(
  p_order_id uuid, p_reason_code text, p_details text DEFAULT NULL, p_amount numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_amount numeric;
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED'); END IF;
  IF p_reason_code IS NULL OR p_reason_code NOT IN
     ('missing_item','wrong_item','quality','late','damaged','other') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_REASON');
  END IF;
  IF p_details IS NOT NULL AND char_length(p_details) > 500 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'DETAILS_TOO_LONG');
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL OR v_order.user_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF v_order.status <> 'delivered' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_DELIVERED', 'status', v_order.status);
  END IF;
  IF v_order.payment_status <> 'paid' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_REFUNDABLE', 'payment_status', v_order.payment_status);
  END IF;
  IF v_order.created_at < now() - interval '14 days' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'WINDOW_EXPIRED');
  END IF;
  IF (SELECT count(*) FROM public.refund_requests WHERE order_id = p_order_id) >= 3 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'TOO_MANY_REQUESTS');
  END IF;
  IF EXISTS (SELECT 1 FROM public.refund_requests
              WHERE order_id = p_order_id AND status IN ('pending','approved')) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_REQUESTED');
  END IF;

  v_amount := round(coalesce(p_amount, v_order.total_amount), 2);
  IF v_amount IS NULL OR v_amount <= 0 OR v_amount > v_order.total_amount THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT', 'max', v_order.total_amount);
  END IF;

  INSERT INTO public.refund_requests (order_id, user_id, amount, reason_code, details)
  VALUES (p_order_id, v_uid, v_amount, p_reason_code, nullif(btrim(p_details), ''))
  RETURNING id INTO v_id;

  PERFORM public.write_audit('REFUND_REQUESTED', 'refund_requests', v_id::text,
    jsonb_build_object('order_id', p_order_id, 'amount', v_amount, 'reason_code', p_reason_code));

  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'request_id', v_id, 'amount', v_amount);
END $$;

CREATE OR REPLACE FUNCTION public.admin_review_refund(
  p_request_id uuid, p_approve boolean, p_note text DEFAULT NULL, p_amount numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_req public.refund_requests%rowtype;
  v_order public.orders%rowtype;
  v_amount numeric;
  v_credit jsonb;
BEGIN
  IF v_uid IS NULL OR NOT public.has_financial_permission(v_uid, 'review_refund') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_approve IS NULL THEN RETURN jsonb_build_object('ok', false, 'code', 'INVALID_REQUEST'); END IF;
  IF p_note IS NOT NULL AND char_length(p_note) > 500 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOTE_TOO_LONG');
  END IF;

  SELECT * INTO v_req FROM public.refund_requests WHERE id = p_request_id FOR UPDATE;
  IF v_req.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND'); END IF;
  IF v_req.user_id = v_uid THEN RETURN jsonb_build_object('ok', false, 'code', 'SELF_REVIEW_NOT_ALLOWED'); END IF;
  IF v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS', 'current_status', v_req.status);
  END IF;

  IF NOT p_approve THEN
    IF p_note IS NULL OR btrim(p_note) = '' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOTE_REQUIRED');
    END IF;
    UPDATE public.refund_requests
       SET status = 'rejected', review_note = btrim(p_note), reviewed_by = v_uid, reviewed_at = now()
     WHERE id = p_request_id;
    PERFORM public.write_audit('REFUND_REJECTED', 'refund_requests', p_request_id::text,
      jsonb_build_object('order_id', v_req.order_id, 'note', btrim(p_note)));
    INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
    VALUES (v_req.user_id, 'تم رفض طلب الاسترداد', btrim(p_note), 'order',
            jsonb_build_object('order_id', v_req.order_id, 'refund_request_id', p_request_id, 'status', 'rejected'), true);
    RETURN jsonb_build_object('ok', true, 'code', 'OK', 'status', 'rejected');
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = v_req.order_id FOR UPDATE;
  IF v_order.id IS NULL OR v_order.payment_status <> 'paid' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_REFUNDABLE');
  END IF;
  v_amount := round(coalesce(p_amount, v_req.amount), 2);
  IF v_amount <= 0 OR v_amount > v_order.total_amount THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT', 'max', v_order.total_amount);
  END IF;

  v_credit := public._wallet_credit(v_req.user_id, v_amount,
    'Refund for order ' || v_req.order_id::text, 'refund_request', p_request_id);
  IF coalesce((v_credit ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'REFUND_CREDIT_FAILED: %', v_credit;
  END IF;

  UPDATE public.refund_requests
     SET status = 'approved', approved_amount = v_amount, review_note = nullif(btrim(p_note), ''),
         reviewed_by = v_uid, reviewed_at = now()
   WHERE id = p_request_id;
  IF v_amount = v_order.total_amount THEN
    UPDATE public.orders SET payment_status = 'refunded', updated_at = now() WHERE id = v_order.id;
  END IF;

  PERFORM public.write_audit('REFUND_APPROVED', 'refund_requests', p_request_id::text,
    jsonb_build_object('order_id', v_req.order_id, 'amount', v_amount, 'requested', v_req.amount));
  INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
  VALUES (v_req.user_id, 'تم قبول طلب الاسترداد',
          'تمت إضافة ' || v_amount::text || ' ج.م إلى محفظتك.', 'order',
          jsonb_build_object('order_id', v_req.order_id, 'refund_request_id', p_request_id, 'status', 'approved'), true);
  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'status', 'approved',
                            'amount', v_amount, 'new_balance', v_credit -> 'new_balance');
END $$;

CREATE OR REPLACE FUNCTION public.admin_list_refund_requests(
  p_status text DEFAULT 'pending', p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_financial_permission(auth.uid(), 'review_refund') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'requests', coalesce((
    SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at) FROM (
      SELECT r.id, r.order_id, r.user_id, r.amount, r.reason_code, r.details, r.status,
             r.approved_amount, r.review_note, r.reviewed_at, r.created_at,
             o.merchant_name, o.total_amount AS order_total, o.payment_method
        FROM public.refund_requests r JOIN public.orders o ON o.id = r.order_id
       WHERE (p_status IS NULL OR p_status = 'all' OR r.status = p_status)
       ORDER BY r.created_at
       LIMIT least(greatest(coalesce(p_limit, 50), 1), 200)) x), '[]'::jsonb));
END $$;

REVOKE ALL ON FUNCTION public.request_refund(uuid, text, text, numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_review_refund(uuid, boolean, text, numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_refund_requests(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_refund(uuid, text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_refund(uuid, boolean, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_refund_requests(text, integer) TO authenticated;
