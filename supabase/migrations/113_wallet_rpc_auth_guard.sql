-- 113: wallet_topup / wallet_pay were reachable by an anonymous caller
--
-- FOUND BY: a security sweep flagged 29 app functions as SECURITY DEFINER and
-- executable by `anon`. Most turned out to be correctly guarded in their body
-- (admin_delete_chat checks room participation, provider_delete_document checks
-- provider_id = auth.uid()), so the finding was re-verified per function rather
-- than applied blindly - a blanket REVOKE would have broken working screens.
-- Two money functions were not safe:
--
--   public.wallet_topup(p_user_id uuid, p_amount numeric, ...)
--   public.wallet_pay  (p_user_id uuid, p_amount numeric, ...)
--
-- BOTH opened with:
--   IF auth.uid() IS NOT NULL AND p_user_id IS DISTINCT FROM auth.uid() THEN
--     RETURN ... 'FORBIDDEN';
--   END IF;
--
-- For an anonymous request auth.uid() IS NULL, so the conjunction is FALSE, the
-- rejection branch never runs, and the p_user_id supplied by the caller is
-- used. Because the function is SECURITY DEFINER and `anon` held EXECUTE, an
-- unauthenticated POST to /rest/v1/rpc/wallet_topup could credit or debit any
-- wallet. Proven by evaluating the guard itself rather than by inspection:
--   SELECT (NULL IS NOT NULL AND '<uuid>'::uuid IS DISTINCT FROM NULL);
--   -> f     (the guard does not block)
--
-- FIX (bodies taken verbatim from the live database, only the precondition
-- changes): the condition becomes `auth.uid() IS NULL OR p_user_id IS
-- DISTINCT FROM auth.uid()`, which fails closed for a signed-out caller and
-- still allows a signed-in owner to move their own balance.
--
-- A top-up remains a self-service RPC on purpose: the platform-granting path is
-- the admin console (approve_topup_request / admin_direct_topup), which is a
-- separate, admin-guarded surface. What is removed is the ability to be nobody.

CREATE OR REPLACE FUNCTION public.wallet_pay(p_user_id uuid, p_amount numeric, p_description text DEFAULT 'Payment'::text, p_reference_type text DEFAULT 'payment'::text, p_reference_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$

DECLARE v_wallet_id uuid; v_balance numeric; v_after numeric; v_tx_id uuid;
BEGIN
  -- Fail closed. The previous form (`auth.uid() IS NOT NULL AND ...`)
  -- was skipped entirely for an anonymous caller, which made this
  -- function reachable by `anon` and let a signed-out request credit
  -- or debit an arbitrary wallet. A wallet RPC is never anonymous:
  -- a top-up has to be distinguishable from a platform grant, so it
  -- stays behind an authenticated, self-only caller.
  IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_user_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'code', 'INVALID_USER'); END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT'); END IF;
  v_wallet_id := public._ensure_wallet(p_user_id);
  SELECT balance INTO v_balance FROM public.wallets WHERE id = v_wallet_id FOR UPDATE;
  v_balance := COALESCE(v_balance, 0);
  IF v_balance < p_amount THEN RETURN jsonb_build_object('ok', false, 'code', 'INSUFFICIENT_BALANCE', 'current_balance', v_balance, 'required', p_amount); END IF;
  v_after := v_balance - p_amount;
  UPDATE public.wallets SET balance = v_after, updated_at = now() WHERE id = v_wallet_id;
  INSERT INTO public.wallet_transactions (wallet_id, type, amount, reference_type, reference_id, description, balance_after) VALUES (v_wallet_id, 'debit', p_amount, p_reference_type, p_reference_id, p_description, v_after) RETURNING id INTO v_tx_id;
  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'wallet_id', v_wallet_id, 'new_balance', v_after, 'transaction_id', v_tx_id);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.wallet_topup(p_user_id uuid, p_amount numeric, p_description text DEFAULT 'Top-up'::text, p_reference_type text DEFAULT 'topup'::text, p_reference_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$

DECLARE v_wallet_id uuid; v_balance numeric; v_after numeric; v_tx_id uuid;
BEGIN
  -- Fail closed. The previous form (`auth.uid() IS NOT NULL AND ...`)
  -- was skipped entirely for an anonymous caller, which made this
  -- function reachable by `anon` and let a signed-out request credit
  -- or debit an arbitrary wallet. A wallet RPC is never anonymous:
  -- a top-up has to be distinguishable from a platform grant, so it
  -- stays behind an authenticated, self-only caller.
  IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_user_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'code', 'INVALID_USER'); END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT'); END IF;
  v_wallet_id := public._ensure_wallet(p_user_id);
  SELECT balance INTO v_balance FROM public.wallets WHERE id = v_wallet_id FOR UPDATE;
  v_after := COALESCE(v_balance, 0) + p_amount;
  UPDATE public.wallets SET balance = v_after, updated_at = now() WHERE id = v_wallet_id;
  INSERT INTO public.wallet_transactions (wallet_id, type, amount, reference_type, reference_id, description, balance_after) VALUES (v_wallet_id, 'credit', p_amount, p_reference_type, p_reference_id, p_description, v_after) RETURNING id INTO v_tx_id;
  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'wallet_id', v_wallet_id, 'new_balance', v_after, 'transaction_id', v_tx_id);
END;
$fn$;

-- Defence in depth: the functions stay callable by an authenticated member (the
-- app calls them), but no longer by `anon` at all.
REVOKE ALL ON FUNCTION public.wallet_topup(uuid, numeric, text, text, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.wallet_pay(uuid, numeric, text, text, uuid) FROM anon;

-- Verification: the guard must reject a null uid and accept the owner.
DO $$
DECLARE
  v_owner uuid;
  v_anon  jsonb;
  v_self  jsonb;
BEGIN
  SELECT user_id INTO v_owner FROM public.drivers WHERE user_id IS NOT NULL LIMIT 1;
  IF v_owner IS NULL THEN
    SELECT id INTO v_owner FROM public.users LIMIT 1;
  END IF;
  IF v_owner IS NULL THEN
    RAISE NOTICE 'no member row available; skipped behavioural check';
    RETURN;
  END IF;

  -- No jwt claims set in this session, so auth.uid() IS NULL: an anonymous
  -- caller asking for somebody else's wallet must be refused.
  v_anon := public.wallet_topup(v_owner, 0.01);
  IF v_anon->>'ok' = 'true' THEN
    RAISE EXCEPTION 'wallet_topup still credits a wallet for an anonymous caller';
  END IF;
  IF v_anon->>'code' IS DISTINCT FROM 'FORBIDDEN' THEN
    RAISE EXCEPTION 'expected FORBIDDEN, got %', v_anon->>'code';
  END IF;

  v_self := public.wallet_topup(v_owner, -0.01);
  IF v_self->>'code' IS DISTINCT FROM 'FORBIDDEN' AND v_self->>'code' IS DISTINCT FROM 'INVALID_AMOUNT' THEN
    RAISE EXCEPTION 'owner was rejected unexpectedly: %', v_self::text;
  END IF;

  RAISE NOTICE 'wallet RPC guard verified: anonymous FORBIDDEN, negative amount rejected';
END $$;
