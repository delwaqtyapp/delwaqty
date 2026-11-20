-- Run after migration 145. Every fixture and resulting row is rolled back.
-- Verifies the three closed credit-forgery paths stay closed and the
-- legitimate wallet flows (zero-balance creation, self-payment, RPC ledger
-- writes) still work.
BEGIN;
-- Rollback-only synthetic fixtures. Never use real user accounts or money.
DO $$
DECLARE
  u uuid := gen_random_uuid();
  v_wallet uuid;
  v_balance_before numeric;
  a jsonb;
  v_denied boolean;
BEGIN
  INSERT INTO auth.users(id, email) VALUES (u, u::text || '@example.invalid');
  INSERT INTO public.users(id, email) VALUES (u, u::text || '@example.invalid') ON CONFLICT (id) DO NOTHING;

  -- Become the synthetic user.
  PERFORM set_config('request.jwt.claim.sub', u::text, true);
  PERFORM set_config('role', 'authenticated', true);

  -- (1) wallet_refund must not be executable by a client any more.
  v_denied := false;
  BEGIN
    PERFORM public.wallet_refund(u, 500, 'forgery attempt', 'refund', NULL);
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'wallet_refund still executable by authenticated caller';
  END IF;

  -- (2) A wallet with a forged starting balance must be rejected; a
  -- zero-balance wallet must be accepted.
  v_denied := false;
  BEGIN
    INSERT INTO public.wallets (user_id, balance, currency) VALUES (u, 9999, 'EGP');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    v_denied := true;
  WHEN OTHERS THEN
    IF SQLERRM ILIKE '%row-level security%' OR SQLERRM ILIKE '%row security%' THEN
      v_denied := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'wallet INSERT with non-zero balance was allowed';
  END IF;
  INSERT INTO public.wallets (user_id, balance, currency) VALUES (u, 0, 'EGP');
  SELECT id INTO v_wallet FROM public.wallets WHERE user_id = u;
  IF v_wallet IS NULL THEN
    RAISE EXCEPTION 'zero-balance wallet creation failed';
  END IF;

  -- (3) Direct client ledger writes must be rejected.
  v_denied := false;
  BEGIN
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, balance_after)
    VALUES (v_wallet, u, 'credit', 1234, 'forged ledger row', 1234);
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM ILIKE '%row-level security%' OR SQLERRM ILIKE '%row security%' OR SQLSTATE = '42501' THEN
      v_denied := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'direct wallet_transactions INSERT was allowed';
  END IF;

  -- Legitimate flows still work: server-side credit via owner adjustment path
  -- is exercised through wallet_pay after a service-style balance seed.
  PERFORM set_config('role', 'none', true);
  UPDATE public.wallets SET balance = 100 WHERE id = v_wallet;
  PERFORM set_config('role', 'authenticated', true);

  a := public.wallet_pay(40, 'synthetic fare', 'test', NULL);
  IF a->>'ok' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'wallet_pay self-payment broke: %', a;
  END IF;
  SELECT balance INTO v_balance_before FROM public.wallets WHERE id = v_wallet;
  IF v_balance_before IS DISTINCT FROM 60::numeric THEN
    RAISE EXCEPTION 'wallet_pay did not debit exactly once, balance=%', v_balance_before;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.wallet_transactions
    WHERE wallet_id = v_wallet AND amount = 40 AND type = 'payment'
  ) THEN
    RAISE EXCEPTION 'RPC ledger write missing after client INSERT policy drop';
  END IF;

  -- Overspend still refused.
  a := public.wallet_pay(1000, 'too much', 'test', NULL);
  IF a->>'code' IS DISTINCT FROM 'INSUFFICIENT_BALANCE' THEN
    RAISE EXCEPTION 'overspend not refused: %', a;
  END IF;

  PERFORM set_config('role', 'none', true);
END;
$$;
ROLLBACK;
