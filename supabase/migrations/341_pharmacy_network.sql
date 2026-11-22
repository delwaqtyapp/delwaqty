-- 341 (owner binding spec): inter-pharmacy shortage network.
-- A pharmacy missing an item requests it from another pharmacy; the lending
-- pharmacy logs the out-transfer; each PAIR keeps a running balance (what
-- each owes the other); settlement per deal is بدل (item swap) OR cash.
-- Messages between pharmacies in Arabic; profiles show address + mobile.

CREATE TABLE public.pharmacy_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_a uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  pharmacy_b uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','blocked')),
  created_by uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (pharmacy_a < pharmacy_b),
  UNIQUE (pharmacy_a, pharmacy_b)
);
ALTER TABLE public.pharmacy_links ENABLE ROW LEVEL SECURITY;
CREATE POLICY pharmacy_links_member ON public.pharmacy_links FOR ALL TO authenticated
  USING (public.is_merchant_owner(pharmacy_a) OR public.is_merchant_owner(pharmacy_b) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(pharmacy_a) OR public.is_merchant_owner(pharmacy_b) OR public.is_admin());

CREATE TABLE public.pharmacy_transfer_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id uuid NOT NULL REFERENCES public.pharmacy_links(id) ON DELETE CASCADE,
  requesting_merchant uuid NOT NULL REFERENCES public.merchants(id),
  lending_merchant uuid NOT NULL REFERENCES public.merchants(id),
  drug_catalog_id uuid REFERENCES public.drug_catalog(id),
  item_name text NOT NULL,
  qty numeric(10,3) NOT NULL CHECK (qty > 0),
  agreed_cash_value numeric(12,2),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','accepted','rejected','handed_over','settled','cancelled')),
  request_note text,
  created_offline_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.pharmacy_transfer_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY pharmacy_transfer_member ON public.pharmacy_transfer_requests FOR ALL TO authenticated
  USING (public.is_merchant_owner(requesting_merchant) OR public.is_merchant_owner(lending_merchant) OR public.is_admin())
  WITH CHECK (public.is_merchant_owner(requesting_merchant) OR public.is_merchant_owner(lending_merchant) OR public.is_admin());

-- Pairwise running balance ledger. Positive amount = first pharmacy (by the
-- link's a/b order) owes the second; negative = the reverse. Settlement
-- entries (بدل swap or cash) bring it back toward zero.
CREATE TABLE public.pharmacy_transfer_ledger (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  link_id uuid NOT NULL REFERENCES public.pharmacy_links(id) ON DELETE CASCADE,
  transfer_id uuid REFERENCES public.pharmacy_transfer_requests(id) ON DELETE SET NULL,
  client_op_id uuid,
  entry_type text NOT NULL CHECK (entry_type IN ('borrow','settle_swap','settle_cash','adjustment')),
  item_desc text,
  qty numeric(10,3),
  cash_amount numeric(12,2) NOT NULL DEFAULT 0,
  note text,
  created_by uuid REFERENCES public.users(id),
  created_offline_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (link_id, client_op_id)
);
ALTER TABLE public.pharmacy_transfer_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY pharmacy_ledger_member ON public.pharmacy_transfer_ledger FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.pharmacy_links k WHERE k.id = link_id
                 AND (public.is_merchant_owner(k.pharmacy_a) OR public.is_merchant_owner(k.pharmacy_b) OR public.is_admin())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.pharmacy_links k WHERE k.id = link_id
                 AND (public.is_merchant_owner(k.pharmacy_a) OR public.is_merchant_owner(k.pharmacy_b) OR public.is_admin())));

CREATE TABLE public.pharmacy_messages (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  link_id uuid NOT NULL REFERENCES public.pharmacy_links(id) ON DELETE CASCADE,
  transfer_id uuid REFERENCES public.pharmacy_transfer_requests(id) ON DELETE SET NULL,
  sender_merchant uuid NOT NULL REFERENCES public.merchants(id),
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.pharmacy_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY pharmacy_messages_member ON public.pharmacy_messages FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.pharmacy_links k WHERE k.id = link_id
                 AND (public.is_merchant_owner(k.pharmacy_a) OR public.is_merchant_owner(k.pharmacy_b) OR public.is_admin())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.pharmacy_links k WHERE k.id = link_id
                 AND (public.is_merchant_owner(k.pharmacy_a) OR public.is_merchant_owner(k.pharmacy_b) OR public.is_admin())));

-- Directory: pharmacies see each other's address + mobile to coordinate.
CREATE OR REPLACE FUNCTION public.pharmacy_directory(p_merchant_id uuid)
 RETURNS TABLE(merchant_id uuid, name text, name_ar text, address text, phone text,
               link_id uuid, link_status text, balance numeric)
 LANGUAGE plpgsql STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN QUERY
    SELECT m.id, m.name, NULLIF('', ''), m.address, m.phone,
           k.id, k.status,
           COALESCE((SELECT sum(CASE
               WHEN (k.pharmacy_a = p_merchant_id) THEN l.cash_amount
               ELSE -l.cash_amount END)
             FROM public.pharmacy_transfer_ledger l WHERE l.link_id = k.id), 0)
      FROM public.pharmacy_links k
      JOIN public.merchants m ON m.id = CASE WHEN k.pharmacy_a = p_merchant_id THEN k.pharmacy_b ELSE k.pharmacy_a END
     WHERE (k.pharmacy_a = p_merchant_id OR k.pharmacy_b = p_merchant_id)
       AND k.status = 'active';
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_directory(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.pharmacy_link_create(p_merchant_id uuid, p_other_merchant_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_a uuid; v_b uuid; v_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_merchant_id = p_other_merchant_id THEN RAISE EXCEPTION 'cannot link self'; END IF;
  v_a := LEAST(p_merchant_id, p_other_merchant_id);
  v_b := GREATEST(p_merchant_id, p_other_merchant_id);
  INSERT INTO public.pharmacy_links (pharmacy_a, pharmacy_b, created_by)
  VALUES (v_a, v_b, v_uid)
  ON CONFLICT (pharmacy_a, pharmacy_b) DO UPDATE SET status = 'active'
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'link_id', v_id);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_link_create(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.pharmacy_transfer_request(
  p_link_id uuid, p_item_name text, p_qty numeric,
  p_drug_catalog_id uuid DEFAULT NULL, p_note text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_link record;
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_link FROM public.pharmacy_links WHERE id = p_link_id AND status = 'active';
  IF NOT FOUND THEN RAISE EXCEPTION 'LINK_NOT_FOUND'; END IF;
  IF NOT (public.is_admin() OR public.is_merchant_owner(v_link.pharmacy_a) OR public.is_merchant_owner(v_link.pharmacy_b)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  INSERT INTO public.pharmacy_transfer_requests
    (link_id, requesting_merchant, lending_merchant, drug_catalog_id, item_name, qty, request_note)
  SELECT p_link_id, m.id,
         CASE WHEN m.id = v_link.pharmacy_a THEN v_link.pharmacy_b ELSE v_link.pharmacy_a END,
         p_drug_catalog_id, p_item_name, p_qty, p_note
    FROM public.merchants m
   WHERE (m.id = v_link.pharmacy_a OR m.id = v_link.pharmacy_b)
     AND public.is_merchant_owner(m.id)
   ORDER BY m.id LIMIT 1
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'transfer_id', v_id);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_transfer_request(uuid, text, numeric, uuid, text) TO authenticated;

-- Lender responds (accept/reject), then logs the handover which writes the
-- borrow ledger entry; settlement adds a بدل-swap or cash entry per deal.
CREATE OR REPLACE FUNCTION public.pharmacy_transfer_respond(p_transfer_id uuid, p_accept boolean, p_cash_value numeric DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT (public.is_admin() OR public.is_merchant_owner(v_t.lending_merchant)) THEN
    RAISE EXCEPTION 'Only the lending pharmacy responds';
  END IF;
  IF v_t.status <> 'requested' THEN RETURN jsonb_build_object('ok', false, 'reason', 'ALREADY_ANSWERED'); END IF;
  UPDATE public.pharmacy_transfer_requests
     SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
         agreed_cash_value = CASE WHEN p_accept THEN COALESCE(p_cash_value, agreed_cash_value) END,
         updated_at = now()
   WHERE id = p_transfer_id;
  RETURN jsonb_build_object('ok', true, 'status', CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_transfer_respond(uuid, boolean, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.pharmacy_transfer_handover(p_transfer_id uuid, p_cash_value numeric DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
  v_sign integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT (public.is_admin() OR public.is_merchant_owner(v_t.lending_merchant)) THEN
    RAISE EXCEPTION 'Only the lending pharmacy logs the handover';
  END IF;
  IF v_t.status <> 'accepted' THEN RETURN jsonb_build_object('ok', false, 'reason', 'NOT_ACCEPTED'); END IF;
  UPDATE public.pharmacy_transfer_requests SET status = 'handed_over',
         agreed_cash_value = COALESCE(p_cash_value, agreed_cash_value), updated_at = now()
   WHERE id = p_transfer_id;
  -- Borrow: requester owes lender. cash_amount positive = pharmacy_a owes b.
  SELECT CASE WHEN v_t.requesting_merchant = k.pharmacy_a THEN 1 ELSE -1 END
    INTO v_sign FROM public.pharmacy_links k WHERE k.id = v_t.link_id;
  INSERT INTO public.pharmacy_transfer_ledger
    (link_id, transfer_id, entry_type, item_desc, qty, cash_amount, created_by)
  VALUES (v_t.link_id, p_transfer_id, 'borrow', v_t.item_name, v_t.qty,
          v_sign * COALESCE(p_cash_value, v_t.agreed_cash_value, 0), v_uid);
  RETURN jsonb_build_object('ok', true, 'status', 'handed_over');
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_transfer_handover(uuid, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.pharmacy_transfer_settle(
  p_transfer_id uuid, p_mode text, p_cash_amount numeric DEFAULT NULL, p_swap_desc text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
  v_sign integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_mode NOT IN ('swap','cash') THEN RAISE EXCEPTION 'mode must be swap or cash'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT (public.is_admin() OR public.is_merchant_owner(v_t.requesting_merchant) OR public.is_merchant_owner(v_t.lending_merchant)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_t.status <> 'handed_over' THEN RETURN jsonb_build_object('ok', false, 'reason', 'NOT_HANDED_OVER'); END IF;
  SELECT CASE WHEN v_t.requesting_merchant = k.pharmacy_a THEN 1 ELSE -1 END
    INTO v_sign FROM public.pharmacy_links k WHERE k.id = v_t.link_id;
  INSERT INTO public.pharmacy_transfer_ledger
    (link_id, transfer_id, entry_type, item_desc, cash_amount, note, created_by)
  VALUES (v_t.link_id, p_transfer_id,
          CASE WHEN p_mode = 'swap' THEN 'settle_swap' ELSE 'settle_cash' END,
          COALESCE(p_swap_desc, v_t.item_name),
          -v_sign * COALESCE(p_cash_amount, v_t.agreed_cash_value, 0),
          CASE WHEN p_mode = 'swap' THEN 'تسوية بدل' ELSE 'تسوية نقدية' END, v_uid);
  UPDATE public.pharmacy_transfer_requests SET status = 'settled', updated_at = now() WHERE id = p_transfer_id;
  RETURN jsonb_build_object('ok', true, 'status', 'settled');
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_transfer_settle(uuid, text, numeric, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.pharmacy_message_send(p_link_id uuid, p_body text, p_transfer_id uuid DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_sender uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF btrim(COALESCE(p_body,'')) = '' THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;
  SELECT k.pharmacy_a INTO v_sender FROM public.pharmacy_links k
   WHERE k.id = p_link_id AND public.is_merchant_owner(k.pharmacy_a);
  IF v_sender IS NULL THEN
    SELECT k.pharmacy_b INTO v_sender FROM public.pharmacy_links k
     WHERE k.id = p_link_id AND public.is_merchant_owner(k.pharmacy_b);
  END IF;
  IF v_sender IS NULL AND NOT public.is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.pharmacy_messages (link_id, transfer_id, sender_merchant, body)
  VALUES (p_link_id, p_transfer_id, v_sender, p_body);
  RETURN jsonb_build_object('ok', true);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.pharmacy_message_send(uuid, text, uuid) TO authenticated;
