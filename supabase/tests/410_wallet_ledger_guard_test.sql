-- wallet_ledger_guard_regression.sql
-- Run after migration 410. Every fixture and resulting row is rolled back.
-- Verifies the wallet ledger invariant: wallets.balance moves only through
-- the ledger-writing functions, wallet_transactions is append-only, and the
-- client roles cannot write either table even with the internal flag set.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid();
  u2 uuid := gen_random_uuid();
  w uuid;
  a jsonb;
  v_denied boolean;
  v_balance numeric;
BEGIN
  INSERT INTO auth.users(id, email) VALUES (u, u::text || '@example.invalid');
  INSERT INTO public.users(id, email) VALUES (u, u::text || '@example.invalid') ON CONFLICT (id) DO NOTHING;
  INSERT INTO auth.users(id, email) VALUES (u2, u2::text || '@example.invalid');
  INSERT INTO public.users(id, email) VALUES (u2, u2::text || '@example.invalid') ON CONFLICT (id) DO NOTHING;

  -- Fixture seed: privileged role with the ledger flag (how tests/tools seed).
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
  INSERT INTO public.wallets (user_id, balance, currency) VALUES (u, 100, 'EGP') RETURNING id INTO w;
  PERFORM set_config('delwaqty.ledger_write', 'off', true);

  -- (1) Privileged role WITHOUT the flag cannot move a balance.
  v_denied := false;
  BEGIN
    UPDATE public.wallets SET balance = 0 WHERE id = w;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM ILIKE 'WALLET_LEDGER_GUARD%' THEN v_denied := true; ELSE RAISE; END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'unflagged direct UPDATE wallets was allowed'; END IF;

  -- (2) INSERT with a non-zero starting balance without the flag is refused;
  --     with the flag it is allowed (fixture seeding path).
  v_denied := false;
  BEGIN
    INSERT INTO public.wallets (user_id, balance, currency) VALUES (gen_random_uuid(), 50, 'EGP');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM ILIKE 'WALLET_LEDGER_GUARD%' THEN v_denied := true; ELSE RAISE; END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'unflagged non-zero wallet INSERT was allowed'; END IF;

  -- (3) Ledger function still works and stays consistent.
  a := public._wallet_credit(u, 25, 'test credit', 'qa', NULL);
  IF a->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION '_wallet_credit broke: %', a; END IF;
  SELECT balance INTO v_balance FROM public.wallets WHERE id = w;
  IF v_balance IS DISTINCT FROM 125::numeric THEN RAISE EXCEPTION 'balance after credit = %, want 125', v_balance; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE wallet_id = w AND amount = 25 AND balance_after = 125) THEN
    RAISE EXCEPTION 'ledger row missing after _wallet_credit';
  END IF;

  -- (4) The ledger is append-only: no UPDATE, no DELETE, for anyone.
  v_denied := false;
  BEGIN
    UPDATE public.wallet_transactions SET description = 'tampered' WHERE wallet_id = w;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM ILIKE 'WALLET_LEDGER_GUARD%' THEN v_denied := true; ELSE RAISE; END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'wallet_transactions UPDATE was allowed'; END IF;
  v_denied := false;
  BEGIN
    DELETE FROM public.wallet_transactions WHERE wallet_id = w;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM ILIKE 'WALLET_LEDGER_GUARD%' THEN v_denied := true; ELSE RAISE; END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'wallet_transactions DELETE was allowed'; END IF;


  -- (5) The actual authenticated role cannot move a balance even WITH the flag
  --     (privilege layer), and cannot insert a pre-loaded wallet (policy layer).
  PERFORM set_config('request.jwt.claim.sub', u::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
  v_denied := false;
  BEGIN
    UPDATE public.wallets SET balance = 999999 WHERE id = w;
  EXCEPTION WHEN insufficient_privilege THEN v_denied := true;
  WHEN OTHERS THEN
    IF SQLERRM ILIKE '%row-level security%' OR SQLERRM ILIKE 'WALLET_LEDGER_GUARD%' THEN v_denied := true; ELSE RAISE; END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'authenticated direct UPDATE wallets was allowed'; END IF;
  v_denied := false;
  BEGIN
    INSERT INTO public.wallets (user_id, balance, currency) VALUES (u2, 500, 'EGP');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM ILIKE '%row-level security%' OR SQLERRM ILIKE 'WALLET_LEDGER_GUARD%' OR SQLSTATE = '42501' THEN v_denied := true; ELSE RAISE; END IF;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'authenticated non-zero wallet INSERT was allowed'; END IF;
  PERFORM set_config('delwaqty.ledger_write', 'off', true);

  -- (6) Authenticated zero-balance self-create still works (customer app flow).
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  INSERT INTO public.wallets (user_id, balance, currency) VALUES (u2, 0, 'EGP');
  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = u2 AND balance = 0) THEN
    RAISE EXCEPTION 'zero-balance wallet creation failed';
  END IF;

  -- (7) Authenticated wallet_pay happy path: debits exactly once, ledger row written.
  PERFORM set_config('request.jwt.claim.sub', u::text, true);
  a := public.wallet_pay(40, 'synthetic fare', 'test', NULL);
  IF a->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'wallet_pay broke: %', a; END IF;
  SELECT balance INTO v_balance FROM public.wallets WHERE id = w;
  IF v_balance IS DISTINCT FROM 85::numeric THEN RAISE EXCEPTION 'balance after pay = %, want 85', v_balance; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE wallet_id = w AND amount = 40 AND type = 'payment' AND balance_after = 85) THEN
    RAISE EXCEPTION 'wallet_pay ledger row missing';
  END IF;

  -- (8) Overspend still refused.
  a := public.wallet_pay(10000, 'too much', 'test', NULL);
  IF a->>'code' IS DISTINCT FROM 'INSUFFICIENT_BALANCE' THEN RAISE EXCEPTION 'overspend not refused: %', a; END IF;

  PERFORM set_config('role', 'none', true);
END $$;
ROLLBACK;
