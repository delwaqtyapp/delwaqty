-- ============================================================
-- 106_wallet_atomic_rpcs.sql
-- The wallet was fully client-authoritative:
--   * `wallets_update_own` (added in 101) let any authenticated user
--     PATCH their own `balance` to any value;
--   * topUp() credited the balance directly from the app with no
--     payment gateway and no proof — free money on demand;
--   * pay() read the balance, subtracted in Dart and wrote it back
--     (TOCTOU) so two concurrent payments could both succeed;
--   * the ledger INSERT had NO insert policy, so the balance moved and
--     the audit row failed with RLS 42501 — money moved with no trace.
--
-- This migration moves all three operations behind atomic
-- SECURITY DEFINER RPCs, removes the client's ability to write the
-- balance directly, and gives the ledger its own insert policy so an
-- audit row always exists.
-- ============================================================

-- ─── 1. remove the client's ability to write the balance ───────

DROP POLICY IF EXISTS wallets_update_own ON public.wallets;
REVOKE UPDATE (balance) ON public.wallets FROM authenticated;

-- ─── 2. ledger insert policy (an audit row per balance change) ──

DROP POLICY IF EXISTS "Users insert own wallet transactions"
  ON public.wallet_transactions;
CREATE POLICY "Users insert own wallet transactions"
  ON public.wallet_transactions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ─── 3. atomic top-up ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.wallet_topup(
  p_amount numeric,
  p_method text DEFAULT 'manual',
  p_reference text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_wallet public.wallets%ROWTYPE;
  v_new_balance numeric;
  v_tx_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  -- Idempotency: a retried request must never credit twice.
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_tx_id
      FROM public.wallet_transactions
     WHERE user_id = v_uid
       AND reference_id = 'topup:' || p_idempotency_key
     LIMIT 1;
    IF v_tx_id IS NOT NULL THEN
      SELECT * INTO v_wallet FROM public.wallets WHERE user_id = v_uid;
      RETURN jsonb_build_object(
        'ok', true, 'duplicate', true, 'balance', v_wallet.balance,
        'transaction_id', v_tx_id
      );
    END IF;
  END IF;

  SELECT * INTO v_wallet
    FROM public.wallets
   WHERE user_id = v_uid
   FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.wallets (user_id, balance, currency)
         VALUES (v_uid, 0, 'EGP')
      RETURNING * INTO v_wallet;
  END IF;

  v_new_balance := COALESCE(v_wallet.balance, 0) + p_amount;

  UPDATE public.wallets
     SET balance = v_new_balance,
         updated_at = now()
   WHERE id = v_wallet.id;

  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, type, amount, balance_after, description, reference_id)
  VALUES
    (v_wallet.id, v_uid, 'topup', p_amount, v_new_balance,
     'Top up via ' || COALESCE(p_method, 'manual'),
     'topup:' || COALESCE(p_idempotency_key, gen_random_uuid()::text))
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'ok', true, 'balance', v_new_balance, 'transaction_id', v_tx_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.wallet_topup(numeric, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_topup(numeric, text, text, text) TO authenticated;

-- ─── 4. atomic payment (no double spend) ───────────────────────

CREATE OR REPLACE FUNCTION public.wallet_pay(
  p_amount numeric,
  p_description text DEFAULT NULL,
  p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_wallet public.wallets%ROWTYPE;
  v_new_balance numeric;
  v_tx_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT * INTO v_wallet
    FROM public.wallets
   WHERE user_id = v_uid
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No wallet';
  END IF;

  IF COALESCE(v_wallet.balance, 0) < p_amount THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INSUFFICIENT_BALANCE');
  END IF;

  v_new_balance := v_wallet.balance - p_amount;

  UPDATE public.wallets
     SET balance = v_new_balance,
         updated_at = now()
   WHERE id = v_wallet.id;

  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, type, amount, balance_after, description,
     reference_type, reference_id)
  VALUES
    (v_wallet.id, v_uid, 'payment', p_amount, v_new_balance,
     COALESCE(p_description, 'Wallet payment'),
     p_reference_type, p_reference_id)
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'ok', true, 'balance', v_new_balance, 'transaction_id', v_tx_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.wallet_pay(numeric, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wallet_pay(numeric, text, text, text) TO authenticated;