-- reconcile_qa_wallets.sql
-- Prod reconciliation for the two QA-artifact wallets found in the Nov 23, 2026
-- ledger review. Run as postgres AFTER migration 410 is applied.
--
-- Authority: owner statement, WhatsApp Nov 23 2026 02:38 EET: there is no real
-- money in the system yet; everything so far is testing. Both wallets' rows are
-- QA artifacts (fake order references eeeee188-*, reference_type 'qa', a
-- pre-loaded balance inserted by privileged SQL minutes before a self-service
-- account deletion).
--
-- Method: void the phantom value with append-only 'reconciliation' ledger
-- entries so that sum(ledger) = balance = 0 for both wallets. No rows are
-- updated or deleted (the 410 append-only trigger forbids it anyway).
--
-- Wallet A: 96766540-0711-49c1-a221-e00cea6b707a (Bughunt Customer,
--   f0f0608d-8c16-4a0d-a0ba-87f195e1e2c4): 5 credit txs totalling 266.45,
--   balance already 0.00 -> offsetting debit 266.45, balance stays 0.
-- Wallet B: 60c27d68-5d61-4ee1-b973-03713d4788cd (anonymized self-deleted
--   customer c8082658-fe4c-4252-8143-efdba9ba07b3): balance 42.50, zero
--   ledger rows -> offsetting debit 42.50, balance set to 0.
-- Also rejects the stale QA instapay top-up request f016d75d (100 EGP,
-- no proof, no transfer reference, never reviewed).

BEGIN;

-- Stable lock order before any precondition read or ledger sum.
DO $$ DECLARE t public.topup_requests; n int; BEGIN
 PERFORM 1 FROM public.wallets WHERE id IN ('96766540-0711-49c1-a221-e00cea6b707a','60c27d68-5d61-4ee1-b973-03713d4788cd') ORDER BY id FOR UPDATE;
 GET DIAGNOSTICS n=ROW_COUNT; ASSERT n=2,'both reviewed wallets required';
 SELECT * INTO STRICT t FROM public.topup_requests WHERE id='f016d75d-095c-4a7b-bfae-7226d2fee544' FOR UPDATE;
 ASSERT t.status='pending' AND t.amount=100 AND t.account_id='f0f0608d-8c16-4a0d-a0ba-87f195e1e2c4'::uuid
   AND t.payment_method='instapay' AND t.proof_path IS NULL AND t.transfer_reference IS NULL
   AND t.reviewed_at IS NULL AND t.reviewed_by IS NULL AND t.idempotency_key='bughunt-topup-001','reviewed topup changed';
END $$;
SELECT set_config('delwaqty.ledger_write', 'on', true);

-- Preconditions: abort loudly if the wallets no longer look like the reviewed state.
DO $$
DECLARE
  v_a_balance numeric; v_a_sum numeric;
  v_b_balance numeric; v_b_count int;
BEGIN
  SELECT balance INTO v_a_balance FROM public.wallets WHERE id = '96766540-0711-49c1-a221-e00cea6b707a';
  SELECT COALESCE(SUM(CASE WHEN type IN ('credit','topup','refund') THEN amount ELSE -amount END), 0)
    INTO v_a_sum FROM public.wallet_transactions WHERE wallet_id = '96766540-0711-49c1-a221-e00cea6b707a';
  IF v_a_balance IS NULL OR v_a_balance <> 0 OR v_a_sum <> 266.45 THEN
    RAISE EXCEPTION 'wallet A state changed since review (balance=%, ledger_sum=%) - re-review before reconciling', v_a_balance, v_a_sum;
  END IF;
  SELECT balance INTO v_b_balance FROM public.wallets WHERE id = '60c27d68-5d61-4ee1-b973-03713d4788cd';
  SELECT count(*) INTO v_b_count FROM public.wallet_transactions WHERE wallet_id = '60c27d68-5d61-4ee1-b973-03713d4788cd';
  IF v_b_balance IS NULL OR v_b_balance <> 42.50 OR v_b_count <> 0 THEN
    RAISE EXCEPTION 'wallet B state changed since review (balance=%, tx_count=%) - re-review before reconciling', v_b_balance, v_b_count;
  END IF;
END $$;

-- Wallet A: void the 5 QA credits.
INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, reference_type, description, balance_after)
VALUES ('96766540-0711-49c1-a221-e00cea6b707a', 'f0f0608d-8c16-4a0d-a0ba-87f195e1e2c4',
        'debit', 266.45, 'reconciliation',
        'Reconciliation 2026-11-23: void 5 QA-artifact credits (fake refund/apology/qa-mint txs, Nov 21); owner confirmed no real money in system', 0.00);
UPDATE public.wallets SET balance = 0.00, updated_at = now()
 WHERE id = '96766540-0711-49c1-a221-e00cea6b707a';

-- Wallet B: the 42.50 never entered through the ledger, so record it entering
-- and then void it; the ledger then sums to the final balance (0).
INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, reference_type, description, balance_after)
VALUES ('60c27d68-5d61-4ee1-b973-03713d4788cd', 'c8082658-fe4c-4252-8143-efdba9ba07b3',
        'credit', 42.50, 'reconciliation',
        'Reconciliation 2026-11-23: record out-of-ledger QA-seeded balance on anonymized deleted account; owner confirmed no real money in system', 42.50);
INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, reference_type, description, balance_after)
VALUES ('60c27d68-5d61-4ee1-b973-03713d4788cd', 'c8082658-fe4c-4252-8143-efdba9ba07b3',
        'debit', 42.50, 'reconciliation',
        'Reconciliation 2026-11-23: void out-of-ledger QA-seeded balance on anonymized deleted account; owner confirmed no real money in system', 0.00);
UPDATE public.wallets SET balance = 0.00, updated_at = now()
 WHERE id = '60c27d68-5d61-4ee1-b973-03713d4788cd';

-- Stale QA instapay top-up request: reject so it can never be approved into a balance.
DO $$ DECLARE n int; BEGIN
UPDATE public.topup_requests
   SET status = 'rejected', reviewed_at = now(),
       rejection_reason = 'QA artifact (bughunt account, no proof/reference); rejected during wallet reconciliation 2026-11-23'
 WHERE id = 'f016d75d-095c-4a7b-bfae-7226d2fee544' AND status = 'pending';
GET DIAGNOSTICS n=ROW_COUNT; ASSERT n=1,'topup rejection cardinality';
END $$;

-- Audit trail.
SELECT public.write_audit('WALLET_RECONCILIATION', 'wallets', '96766540-0711-49c1-a221-e00cea6b707a',
  jsonb_build_object('note', 'void 266.45 QA credits; balance 0', 'date', '2026-11-23'));
SELECT public.write_audit('WALLET_RECONCILIATION', 'wallets', '60c27d68-5d61-4ee1-b973-03713d4788cd',
  jsonb_build_object('note', 'void 42.50 out-of-ledger balance; balance 0', 'date', '2026-11-23'));

-- Post-checks: ledger sum now equals balance (= 0) for both wallets.
DO $$
DECLARE
  v_rec record;
  v_sum numeric;
BEGIN
  ASSERT (SELECT status FROM public.topup_requests WHERE id='f016d75d-095c-4a7b-bfae-7226d2fee544')='rejected','topup not rejected';
  ASSERT (SELECT count(*) FROM public.wallet_transactions WHERE reference_type='reconciliation' AND wallet_id IN ('96766540-0711-49c1-a221-e00cea6b707a','60c27d68-5d61-4ee1-b973-03713d4788cd'))=3,'expected three append-only corrections';
  FOR v_rec IN SELECT id, balance FROM public.wallets
    WHERE id IN ('96766540-0711-49c1-a221-e00cea6b707a','60c27d68-5d61-4ee1-b973-03713d4788cd')
  LOOP
    SELECT COALESCE(SUM(CASE WHEN type IN ('credit','topup','refund') THEN amount ELSE -amount END), 0)
      INTO v_sum FROM public.wallet_transactions WHERE wallet_id = v_rec.id;
    IF v_rec.balance <> 0 OR v_sum <> 0 THEN
      RAISE EXCEPTION 'reconciliation failed for %: balance=%, ledger_sum=%', v_rec.id, v_rec.balance, v_sum;
    END IF;
  END LOOP;
END $$;

COMMIT;

-- Optional drift sweep (report-only): any other wallet whose balance disagrees
-- with its ledger, or whose latest balance_after disagrees with balance.
-- SELECT w.id, w.user_id, w.balance,
--        COALESCE(SUM(CASE WHEN t.type IN ('credit','topup','refund') THEN t.amount ELSE -t.amount END), 0) AS ledger_sum,
--        (SELECT balance_after FROM public.wallet_transactions x WHERE x.wallet_id = w.id ORDER BY created_at DESC LIMIT 1) AS latest_balance_after
--   FROM public.wallets w LEFT JOIN public.wallet_transactions t ON t.wallet_id = w.id
--  GROUP BY w.id, w.user_id, w.balance
--  HAVING w.balance <> COALESCE(SUM(CASE WHEN t.type IN ('credit','topup','refund') THEN t.amount ELSE -t.amount END), 0);
