-- Migration 120: Fix Top-Up & Wallet Ledger jsonb_agg ORDER BY 42803 Bugs + Support Chat Numbering & RPCs
--
-- 1. Fixes PostgreSQL 42803 ("must appear in the GROUP BY clause") in:
--    - `get_my_topup_requests()`
--    - `list_all_topup_requests(p_status text)`
--    - `list_all_wallet_ledger()`
--    - `list_platform_receiving_accounts()`
--    by moving `ORDER BY` inside `jsonb_agg(... ORDER BY ...)`.
-- 2. Marks `next_chat_reference()` as VOLATILE (since it calls `nextval`),
--    backfills any missing `reference_number` on `public.chat_rooms` (`DWQ-1001`, ...),
--    and adds `get_support_room_contact(p_room_id uuid)` so participants & admins can
--    reach each other via in-app chat, call alert, or direct phone/WhatsApp.

-- ─── 1. Fix Financial jsonb_agg ORDER BY Bugs ────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_my_topup_requests()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'requests',
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'amount', amount,
          'currency', currency,
          'status', status,
          'payment_method', payment_method,
          'transfer_reference', transfer_reference,
          'proof_path', proof_path,
          'receiver', receiver_wallet_snapshot,
          'created_at', created_at,
          'reviewed_at', reviewed_at,
          'rejection_reason', rejection_reason
        )
        ORDER BY created_at DESC
      )
      FROM public.topup_requests
      WHERE account_id = v_uid
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_all_topup_requests(p_status text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_owner_uid(auth.uid()) THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'requests',
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', t.id,
          'account_id', t.account_id,
          'region_id', t.region_id,
          'amount', t.amount,
          'currency', t.currency,
          'status', t.status,
          'payment_method', t.payment_method,
          'transfer_reference', t.transfer_reference,
          'proof_path', t.proof_path,
          'message', t.message,
          'receiver', t.receiver_wallet_snapshot,
          'created_at', t.created_at,
          'reviewed_by', t.reviewed_by,
          'reviewed_at', t.reviewed_at,
          'rejection_reason', t.rejection_reason
        )
        ORDER BY t.created_at DESC
      )
      FROM public.topup_requests t
      WHERE (p_status IS NULL OR t.status = p_status)
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_all_wallet_ledger()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_owner_uid(auth.uid()) THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'transactions',
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', wt.id,
          'wallet_id', wt.wallet_id,
          'type', wt.type,
          'amount', wt.amount,
          'reference_type', wt.reference_type,
          'reference_id', wt.reference_id,
          'description', wt.description,
          'balance_after', wt.balance_after,
          'created_at', wt.created_at
        )
        ORDER BY wt.created_at DESC
      )
      FROM public.wallet_transactions wt
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_platform_receiving_accounts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'accounts',
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'method_type', method_type,
          'display_name', display_name,
          'account_name', account_name,
          'account_number', account_number,
          'wallet_number', wallet_number,
          'instructions', instructions,
          'is_active', is_active
        )
        ORDER BY created_at
      )
      FROM public.platform_receiving_accounts
    ), '[]'::jsonb)
  );
END;
$$;

-- ─── 2. Support Chat Reference Numbering & Contact Helper ────────────────────

CREATE SEQUENCE IF NOT EXISTS public.chat_reference_seq START WITH 1001;

CREATE OR REPLACE FUNCTION public.next_chat_reference()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN 'DWQ-' || nextval('public.chat_reference_seq')::text;
END;
$$;

ALTER TABLE public.chat_rooms
  ALTER COLUMN reference_number SET DEFAULT public.next_chat_reference();

UPDATE public.chat_rooms
   SET reference_number = public.next_chat_reference()
 WHERE reference_number IS NULL OR btrim(reference_number) = '';

-- Ensure any authenticated participant or admin can inspect counterparty contact info for a room
CREATE OR REPLACE FUNCTION public.get_support_room_contact(p_room_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_room public.chat_rooms%ROWTYPE;
  v_other_id uuid;
  v_user record;
  v_support_phone text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF NOT (v_uid = ANY(v_room.participant_ids) OR public.is_admin()) THEN
    RETURN NULL;
  END IF;

  -- Pick counterparty (non-self participant, or assigned admin if user is caller)
  SELECT pid INTO v_other_id
    FROM unnest(v_room.participant_ids) AS pid
   WHERE pid <> v_uid
   LIMIT 1;

  IF v_other_id IS NULL AND v_room.assigned_admin_id IS NOT NULL AND v_room.assigned_admin_id <> v_uid THEN
    v_other_id := v_room.assigned_admin_id;
  END IF;

  IF v_other_id IS NOT NULL THEN
    SELECT id, full_name, phone, role INTO v_user
      FROM public.users
     WHERE id = v_other_id;
  END IF;

  SELECT support_phone INTO v_support_phone
    FROM public.platform_settings
   WHERE id = 'default';

  RETURN jsonb_build_object(
    'reference_number', v_room.reference_number,
    'other_user_id', v_other_id,
    'other_name', v_user.full_name,
    'other_phone', COALESCE(NULLIF(btrim(v_user.phone), ''), v_support_phone),
    'other_role', v_user.role,
    'support_phone', v_support_phone
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_support_room_contact(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_support_room_contact(uuid) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
