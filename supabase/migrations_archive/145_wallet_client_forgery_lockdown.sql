-- 145: close the remaining client-side wallet credit-forgery paths.
--
-- Live-state audit (Nov 20, 2026) found three open paths that let any
-- signed-in user mint wallet balance without a real money movement:
--
-- 1) public.wallet_refund(uuid, numeric, text, text, uuid) is SECURITY DEFINER
--    and was executable by every authenticated user. It credits any positive
--    amount to the caller's wallet with no verified refund reference - the
--    same free-money hole migration 130 closed for wallet_topup. Nothing in
--    the apps calls it (the checkout integration that did was withdrawn in
--    75d0cfc). Revoke it from client roles; service_role keeps it for genuine
--    server-side refunds. The function exists in the live database but not in
--    the migration history (applied out of band), so the revoke is guarded to
--    keep this migration replayable on a fresh database.
--
-- 2) The wallets INSERT policy only checked auth.uid() = user_id, so a user
--    could create their own wallet row with ANY starting balance. Recreate it
--    requiring balance = 0. Zero-balance self-creation (the only legitimate
--    client path) is preserved.
--
-- 3) wallet_transactions had a direct client INSERT policy
--    ("Users insert own wallet transactions"), letting a user write arbitrary
--    credit rows into their own ledger. Every legitimate ledger write goes
--    through SECURITY DEFINER functions owned by postgres (which bypass RLS),
--    so the client INSERT policy is dropped and not replaced.
--
-- The lockdown regression test also exposed a live production bug in the
-- self-service overload public.wallet_pay(numeric, text, text, text): it
-- inserts its p_reference_id TEXT parameter straight into the uuid
-- reference_id column, so every customer wallet payment with sufficient
-- balance failed with a type error. The parameter is cast to uuid below.
BEGIN;

-- (1) wallet_refund: clients out, service_role keeps it.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'wallet_refund'
      AND pg_get_function_arguments(p.oid) LIKE 'p_user_id uuid%'
  ) THEN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.wallet_refund(uuid, numeric, text, text, uuid) FROM PUBLIC, anon, authenticated';
  END IF;
END
$$;

-- (2) wallets: self-creation with zero balance only.
DROP POLICY IF EXISTS "wallets_insert_own" ON public.wallets;
CREATE POLICY "wallets_insert_own" ON public.wallets
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id AND balance = 0);

-- (3) wallet_transactions: no direct client ledger writes.
DROP POLICY IF EXISTS "Users insert own wallet transactions" ON public.wallet_transactions;

-- (4) Repair the broken self-payment overload (text -> uuid cast).
CREATE OR REPLACE FUNCTION public.wallet_pay(p_amount numeric, p_description text DEFAULT NULL::text, p_reference_type text DEFAULT NULL::text, p_reference_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
     p_reference_type, p_reference_id::uuid)
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'ok', true, 'balance', v_new_balance, 'transaction_id', v_tx_id
  );
END;
$function$;

NOTIFY pgrst, 'reload schema';
COMMIT;
