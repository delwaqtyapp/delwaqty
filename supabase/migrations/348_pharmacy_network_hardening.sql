-- 348: review #29 - pharmacy network hardening. Ledger and requests were
-- FOR ALL to either side: any linked pharmacy could rewrite requests or
-- balances. Now: tables are read-only for members (SELECT policies + revoked
-- DML), all changes flow through the RPCs, and settlement requires the other
-- side's confirmation (pharmacy_transfer_settle proposes;
-- pharmacy_transfer_settle_confirm lands the ledger entry).


-- Review #29: direct table access becomes read-only for members; all writes
-- flow through the SECURITY DEFINER RPCs above (respond/handover/settle/
-- settle_confirm/message_send). The ledger is immutable (no UPDATE/DELETE).
ALTER TABLE public.pharmacy_transfer_requests
  ADD COLUMN IF NOT EXISTS settle_mode text,
  ADD COLUMN IF NOT EXISTS settle_cash_amount numeric(12,2),
  ADD COLUMN IF NOT EXISTS settle_swap_desc text,
  ADD COLUMN IF NOT EXISTS settle_proposed_by uuid;
ALTER TABLE public.pharmacy_transfer_requests DROP CONSTRAINT IF EXISTS pharmacy_transfer_requests_status_check;
ALTER TABLE public.pharmacy_transfer_requests
  ADD CONSTRAINT pharmacy_transfer_requests_status_check
  CHECK (status IN ('requested','accepted','rejected','handed_over','settlement_pending','settled','cancelled'));

DROP POLICY IF EXISTS pharmacy_links_member ON public.pharmacy_links;
CREATE POLICY pharmacy_links_read ON public.pharmacy_links FOR SELECT TO authenticated
  USING (public.is_merchant_owner(pharmacy_a) OR public.is_merchant_owner(pharmacy_b) OR public.is_admin());

DROP POLICY IF EXISTS pharmacy_transfer_member ON public.pharmacy_transfer_requests;
CREATE POLICY pharmacy_transfer_read ON public.pharmacy_transfer_requests FOR SELECT TO authenticated
  USING (public.is_merchant_owner(requesting_merchant) OR public.is_merchant_owner(lending_merchant) OR public.is_admin());

DROP POLICY IF EXISTS pharmacy_ledger_member ON public.pharmacy_transfer_ledger;
CREATE POLICY pharmacy_ledger_read ON public.pharmacy_transfer_ledger FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.pharmacy_links k WHERE k.id = link_id
                 AND (public.is_merchant_owner(k.pharmacy_a) OR public.is_merchant_owner(k.pharmacy_b) OR public.is_admin())));

DROP POLICY IF EXISTS pharmacy_messages_member ON public.pharmacy_messages;
CREATE POLICY pharmacy_messages_read ON public.pharmacy_messages FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.pharmacy_links k WHERE k.id = link_id
                 AND (public.is_merchant_owner(k.pharmacy_a) OR public.is_merchant_owner(k.pharmacy_b) OR public.is_admin())));

REVOKE INSERT, UPDATE, DELETE ON public.pharmacy_links FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.pharmacy_transfer_requests FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.pharmacy_transfer_ledger FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.pharmacy_messages FROM anon, authenticated;
GRANT SELECT ON public.pharmacy_links TO authenticated;
GRANT SELECT ON public.pharmacy_transfer_requests TO authenticated;
GRANT SELECT ON public.pharmacy_transfer_ledger TO authenticated;
GRANT SELECT ON public.pharmacy_messages TO authenticated;

CREATE OR REPLACE FUNCTION public.pharmacy_transfer_settle(
  p_transfer_id uuid, p_mode text, p_cash_amount numeric DEFAULT NULL, p_swap_desc text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_mode NOT IN ('swap','cash') THEN RAISE EXCEPTION 'mode must be swap or cash'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT (public.is_admin() OR public.is_merchant_owner(v_t.requesting_merchant) OR public.is_merchant_owner(v_t.lending_merchant)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_t.status <> 'handed_over' THEN RETURN jsonb_build_object('ok', false, 'reason', 'NOT_HANDED_OVER'); END IF;
  -- Review #29: settlement is proposed by one side and only lands in the
  -- ledger after the OTHER side confirms (pharmacy_transfer_settle_confirm).
  UPDATE public.pharmacy_transfer_requests
     SET status = 'settlement_pending',
         settle_mode = p_mode,
         settle_cash_amount = COALESCE(p_cash_amount, agreed_cash_value),
         settle_swap_desc = p_swap_desc,
         settle_proposed_by = v_uid,
         updated_at = now()
   WHERE id = p_transfer_id;
  RETURN jsonb_build_object('ok', true, 'status', 'settlement_pending');
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_transfer_settle(uuid, text, numeric, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.pharmacy_transfer_settle_confirm(p_transfer_id uuid, p_accept boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
  v_sign integer;
  v_proposer_side uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT (public.is_admin() OR public.is_merchant_owner(v_t.requesting_merchant) OR public.is_merchant_owner(v_t.lending_merchant)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_t.status <> 'settlement_pending' THEN RETURN jsonb_build_object('ok', false, 'reason', 'NO_PENDING_SETTLEMENT'); END IF;
  -- The OTHER side must confirm: proposer's merchant vs confirmer's.
  IF v_t.settle_proposed_by IS NOT NULL AND v_t.settle_proposed_by = v_uid AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'OTHER_SIDE_MUST_CONFIRM');
  END IF;
  IF NOT p_accept THEN
    UPDATE public.pharmacy_transfer_requests
       SET status = 'handed_over', settle_mode = NULL, settle_cash_amount = NULL,
           settle_swap_desc = NULL, settle_proposed_by = NULL, updated_at = now()
     WHERE id = p_transfer_id;
    RETURN jsonb_build_object('ok', true, 'status', 'handed_over');
  END IF;
  SELECT CASE WHEN v_t.requesting_merchant = k.pharmacy_a THEN 1 ELSE -1 END
    INTO v_sign FROM public.pharmacy_links k WHERE k.id = v_t.link_id;
  INSERT INTO public.pharmacy_transfer_ledger
    (link_id, transfer_id, entry_type, item_desc, cash_amount, note, created_by)
  VALUES (v_t.link_id, p_transfer_id,
          CASE WHEN v_t.settle_mode = 'swap' THEN 'settle_swap' ELSE 'settle_cash' END,
          COALESCE(v_t.settle_swap_desc, v_t.item_name),
          -v_sign * COALESCE(v_t.settle_cash_amount, 0),
          CASE WHEN v_t.settle_mode = 'swap' THEN 'تسوية بدل' ELSE 'تسوية نقدية' END, v_uid);
  UPDATE public.pharmacy_transfer_requests SET status = 'settled', updated_at = now() WHERE id = p_transfer_id;
  RETURN jsonb_build_object('ok', true, 'status', 'settled');
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_transfer_settle_confirm(uuid, boolean) TO authenticated;
