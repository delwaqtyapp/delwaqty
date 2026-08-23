-- 076_admin_direct_topup.sql
-- Secure, additive Direct Admin/ Owner Top-Up.
-- Credits an authoritative Delivery/Provider wallet without creating a
-- second wallet or ledger. Reuses the existing 065 financial architecture.
-- Regional scoping is derived from the target account's canonical region
-- (user_region_preferences via _member_region_id), never from client input.

CREATE OR REPLACE FUNCTION public.admin_direct_topup(
  p_account_type text,   -- 'delivery' | 'provider'
  p_account_id   uuid,
  p_amount       numeric,
  p_note         text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller    uuid := auth.uid();
  v_is_owner  boolean;
  v_region    uuid;
  v_wallet_id uuid;
  v_before    numeric;
  v_after     numeric;
  v_target    record;
  v_txn_id    uuid;
BEGIN
  -- 1. Authentication.
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;

  -- 2. Authorization: Owner globally, otherwise an Admin holding TOPUP_APPROVE.
  v_is_owner := public._is_owner_uid(v_caller);
  IF NOT v_is_owner AND NOT public.has_permission('TOPUP_APPROVE') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;

  -- 3. Target account must exist and be active.
  SELECT id, status INTO v_target
    FROM public.users WHERE id = p_account_id;
  IF v_target.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ACCOUNT_NOT_FOUND');
  END IF;
  IF v_target.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ACCOUNT_INACTIVE');
  END IF;

  -- 4. Amount sanity (never floating-point Dart authority; numeric server-side).
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  END IF;

  -- 5. Regional scoping for non-owner admins.
  --    Derived from the target's canonical region; never trusted client-side.
  v_region := public._member_region_id(p_account_id);
  IF NOT v_is_owner THEN
    IF v_region IS NULL THEN
      -- Cannot safely authorize a cross-region direct top-up without a
      -- known region. Restrict rather than silently grant global access.
      RETURN jsonb_build_object('ok', false, 'code', 'REGION_UNKNOWN');
    END IF;
    IF NOT public.is_admin_for_region(v_region) THEN
      RETURN jsonb_build_object('ok', false, 'code', 'REGION_FORBIDDEN');
    END IF;
  END IF;

  -- 6. Authoritative ledger credit (same path as approve_topup_request).
  v_wallet_id := public._ensure_wallet(p_account_id);
  SELECT balance INTO v_before FROM public.wallets WHERE id = v_wallet_id FOR UPDATE;
  v_after := COALESCE(v_before, 0) + p_amount;
  UPDATE public.wallets SET balance = v_after, updated_at = now()
   WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions
    (wallet_id, type, amount, reference_type, reference_id, description, balance_after)
  VALUES
    (v_wallet_id, 'credit', p_amount, 'admin_topup', v_caller,
     'Direct account top-up by admin', v_after)
  RETURNING id INTO v_txn_id;

  -- 7. Audit (actor, role, target, type, amount, balances, note).
  PERFORM public.write_audit(
    'ADMIN_DIRECT_TOPUP', 'wallets', v_wallet_id::text,
    jsonb_build_object(
      'actor', v_caller,
      'actor_role', CASE WHEN v_is_owner THEN 'owner' ELSE 'admin' END,
      'account_id', p_account_id,
      'account_type', p_account_type,
      'amount', p_amount,
      'balance_before', v_before,
      'balance_after', v_after,
      'transaction_id', v_txn_id,
      'note', p_note
    ));

  -- 8. Notify the funded account.
  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    p_account_id,
    'Account funded',
    'Your ' || coalesce(p_account_type, 'account') ||
      ' wallet was credited with ' || p_amount::text,
    'admin_topup',
    jsonb_build_object(
      'account_id', p_account_id,
      'account_type', p_account_type,
      'amount', p_amount,
      'transaction_id', v_txn_id
    ));

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK',
    'wallet_id', v_wallet_id,
    'transaction_id', v_txn_id,
    'balance_before', v_before,
    'balance_after', v_after,
    'amount', p_amount
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_direct_topup(text, uuid, numeric, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_direct_topup(text, uuid, numeric, text)
  TO authenticated, service_role;
