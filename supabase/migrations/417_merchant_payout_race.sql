-- 417 v2: merchant payout request race (HIGH, load-test finding) + code
-- reviewer NO-GO #126 fixes.
--
-- v1 of this migration fixed the request side only: merchant_request_payout
-- locked the merchant row, but admin_review_payout (effective body from
-- migration 361) locked ONLY the request row, flipped pending -> approved
-- and inserted the ledger debit with no shared merchant lock and no balance
-- recheck. Race: request2 reads balance 100, approval1 commits debit 100
-- and clears pending, request2 inserts another 100; approval2 debits again
-- -> negative balance.
--
-- v2 fixes, per NO-GO #126:
--  1. Shared merchant lock, consistent order. BOTH payout functions lock
--     the merchants row FOR UPDATE FIRST, then touch
--     merchant_payout_requests. Lock order everywhere:
--       merchants -> merchant_payout_requests -> merchant_ledger (insert).
--     merchant_request_payout: locks merchants row, then reads/inserts
--     requests. admin_review_payout: resolves merchant_id (unlocked read),
--     locks the merchants row, THEN locks the request row FOR UPDATE.
--     Same order on both sides => no deadlock between request and
--     approval/rejection. Rejection takes the same merchant lock, so a
--     reject and a concurrent request serialize too.
--  2. Balance re-evaluated at APPROVE time. After taking both locks,
--     approval recomputes the ledger balance and refuses with
--     INSUFFICIENT_BALANCE if it no longer covers the request amount; the
--     request stays pending. The request-side balance check is kept.
--  3. Other merchant_ledger writers audited: the only DEBIT writer is
--     admin_review_payout. The order-settlement paths (000_baseline
--     complete_ride / order settlement, 342 dedupe redefinitions) insert
--     CREDIT rows only and take no payout locks, so they cannot overspend
--     the balance and cannot deadlock with this lock order (they never
--     acquire merchants or merchant_payout_requests locks while holding a
--     ledger write).
--  4. merchant_request_payout now accepts an explicit p_merchant_id and
--     verifies ownership (owner_user_id = auth.uid()), instead of silently
--     picking the first owned merchant. One-arg compat: p_merchant_id NULL
--     + exactly one owned merchant behaves as before; NULL + several owned
--     merchants returns AMBIGUOUS_MERCHANT instead of guessing.
--  5. Idempotency: a retry with the same key and same amount returns the
--     original request (duplicate=true, original amount + status). The same
--     key with a DIFFERENT amount returns IDEMPOTENCY_CONFLICT. Keys are
--     bounded: blank/whitespace-only or longer than 128 chars returns
--     INVALID_IDEMPOTENCY_KEY.
--
-- NON-RERUNNABLE: the DROP FUNCTION public.merchant_request_payout(numeric)
-- below is intentionally not IF-EXISTS guarded. Re-running this migration
-- after it has been applied fails loudly at that statement (the one-arg
-- function no longer exists) and aborts the transaction. Apply it exactly
-- once through the normal migration tracker; do not hand-replay it.
--
-- Signature: the single-argument form is DROPPED and replaced with a
-- three-argument form whose p_merchant_id and p_idempotency_key default to
-- NULL, so existing callers passing only p_amount keep working (PostgREST
-- resolves defaulted parameters; proven in run_payout_tests.sh against a
-- real PostgREST instance and by a pg_proc catalog assertion). Grants are
-- recreated to match 000_baseline exactly.
--
-- PRE-DEPLOY DATA CHECK: the unique partial index fails if live duplicates
-- exist. The DO block below checks first and raises DUPLICATE_PENDING_PAYOUTS
-- naming the merchants, instead of a raw index error. Run this on prod
-- before applying:
--   SELECT merchant_id, count(*) FROM public.merchant_payout_requests
--    WHERE status='pending' GROUP BY merchant_id HAVING count(*) > 1;
--
-- Rollback: run 417_rollback.sql (precondition hash pin + idempotency
-- archive; restores the pre-417 bodies byte-identical).

BEGIN;

-- Existing-data guard: refuse to apply over duplicate pending payouts.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT merchant_id, count(*) AS c
      FROM public.merchant_payout_requests
     WHERE status = 'pending'
     GROUP BY merchant_id
    HAVING count(*) > 1
  LOOP
    RAISE EXCEPTION 'DUPLICATE_PENDING_PAYOUTS: merchant % has % pending requests', r.merchant_id, r.c;
  END LOOP;
END;
$$;

ALTER TABLE public.merchant_payout_requests
  ADD COLUMN IF NOT EXISTS idempotency_key text;

-- One pending payout per merchant, enforced for every writer.
CREATE UNIQUE INDEX IF NOT EXISTS merchant_payout_requests_one_pending_per_merchant
  ON public.merchant_payout_requests (merchant_id)
  WHERE status = 'pending';

-- Idempotency keys unique per merchant when present.
CREATE UNIQUE INDEX IF NOT EXISTS merchant_payout_requests_idempotency_key_unique
  ON public.merchant_payout_requests (merchant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Replace the racy single-argument form; recreate its exact grants below.
-- (Non-rerunnable by design; see the header comment.)
DROP FUNCTION public.merchant_request_payout(numeric);

CREATE OR REPLACE FUNCTION public.merchant_request_payout(p_amount numeric, p_merchant_id uuid DEFAULT NULL::uuid, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_merchant public.merchants%ROWTYPE;
  v_balance numeric;
  v_id uuid;
  v_amount numeric;
  v_status text;
  v_owned int;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  END IF;
  -- 417 v2: bound the optional idempotency key (nonempty after trim,
  -- length-capped) before it is stored or indexed.
  IF p_idempotency_key IS NOT NULL
     AND (btrim(p_idempotency_key) = '' OR length(p_idempotency_key) > 128) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_IDEMPOTENCY_KEY');
  END IF;

  -- 417 v2 (NO-GO #126): explicit merchant selection with ownership check.
  -- Lock the merchants row FOR UPDATE FIRST (lock order: merchants ->
  -- merchant_payout_requests -> merchant_ledger), held for the whole
  -- check + insert. The pre-417 body did SELECT ... then EXISTS-check ...
  -- then INSERT with no lock; v1 added this lock but silently picked the
  -- first owned merchant. Now an explicit p_merchant_id must name a
  -- merchant the caller owns, and the one-arg form only auto-resolves when
  -- exactly one merchant is owned.
  IF p_merchant_id IS NOT NULL THEN
    SELECT * INTO v_merchant FROM public.merchants
     WHERE id = p_merchant_id
     FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NO_MERCHANT');
    END IF;
    IF v_merchant.owner_user_id IS DISTINCT FROM auth.uid() THEN
      RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
    END IF;
  ELSE
    -- One-arg compat path. Lock FIRST, then decide: a count-then-select
    -- here races an ownership transfer (count says 1, transfer commits,
    -- the select picks arbitrarily or finds nothing). SELECT ... FOR
    -- UPDATE returns the newest committed row version after any wait, so
    -- re-check FOUND and ownership under the lock, then count: a second
    -- owned merchant committed before this point is seen and refused as
    -- AMBIGUOUS_MERCHANT instead of an arbitrary pick.
    SELECT * INTO v_merchant FROM public.merchants
     WHERE owner_user_id = auth.uid()
     ORDER BY created_at, id
     LIMIT 1
     FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NO_MERCHANT');
    END IF;
    IF v_merchant.owner_user_id IS DISTINCT FROM auth.uid() THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NO_MERCHANT');
    END IF;
    SELECT count(*) INTO v_owned FROM public.merchants
     WHERE owner_user_id = auth.uid();
    IF v_owned > 1 THEN
      RETURN jsonb_build_object('ok', false, 'code', 'AMBIGUOUS_MERCHANT',
                                'owned_merchants', v_owned);
    END IF;
  END IF;

  -- 417: idempotent retry. A client retry (timeout, app restart) with the
  -- same key and the same amount returns the original request instead of
  -- creating a second one. The same key with a different amount is a
  -- conflict, not a silent replay.
  IF p_idempotency_key IS NOT NULL THEN
    SELECT r.id, r.amount, r.status INTO v_id, v_amount, v_status
      FROM public.merchant_payout_requests r
     WHERE r.merchant_id = v_merchant.id AND r.idempotency_key = p_idempotency_key;
    IF FOUND THEN
      IF v_amount <> p_amount THEN
        RETURN jsonb_build_object('ok', false, 'code', 'IDEMPOTENCY_CONFLICT',
                                  'id', v_id, 'amount', v_amount, 'status', v_status);
      END IF;
      RETURN jsonb_build_object('ok', true, 'id', v_id, 'duplicate', true,
                                'amount', v_amount, 'status', v_status);
    END IF;
  END IF;

  SELECT COALESCE(sum(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0)
    INTO v_balance
    FROM public.merchant_ledger WHERE merchant_id = v_merchant.id;
  IF p_amount > v_balance THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INSUFFICIENT_BALANCE', 'balance', v_balance);
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.merchant_payout_requests
     WHERE merchant_id = v_merchant.id AND status = 'pending'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'PENDING_EXISTS');
  END IF;
  INSERT INTO public.merchant_payout_requests (merchant_id, amount, requested_by, idempotency_key)
  VALUES (v_merchant.id, p_amount, auth.uid(), p_idempotency_key)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.merchant_request_payout(numeric, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.merchant_request_payout(numeric, uuid, text) TO postgres;
GRANT EXECUTE ON FUNCTION public.merchant_request_payout(numeric, uuid, text) TO service_role;
REVOKE ALL ON FUNCTION public.merchant_request_payout(numeric, uuid, text) FROM PUBLIC;

-- 417 v2 (NO-GO #126): redefine admin_review_payout (effective body from
-- migration 361) with the shared merchant lock and the approve-time balance
-- recheck. v1's body locked ONLY the request row, flipped pending ->
-- approved and inserted the ledger debit with no shared merchant lock and
-- no balance recheck, so it raced a concurrent merchant_request_payout into
-- a negative balance (request reads balance 100, approval commits debit 100
-- and clears pending, request inserts another 100, second approval debits
-- again).
--
-- Lock order (shared with merchant_request_payout, so no deadlock):
--   1. merchants row FOR UPDATE
--   2. merchant_payout_requests row FOR UPDATE
--   3. merchant_ledger insert
-- Rejection takes the same merchant lock, so reject-vs-request serializes
-- too. Approval re-evaluates available funds AFTER both locks are held and
-- refuses with INSUFFICIENT_BALANCE, leaving the request pending.
CREATE OR REPLACE FUNCTION public.admin_review_payout(p_request_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_req public.merchant_payout_requests%ROWTYPE;
  v_merchant_id uuid;
  v_balance numeric;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  -- A NULL decision must not silently act as a rejection.
  IF p_approve IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_DECISION');
  END IF;

  -- Resolve the merchant without a lock, then lock in the shared order:
  -- merchants row FIRST, request row second.
  SELECT r.merchant_id INTO v_merchant_id
    FROM public.merchant_payout_requests r WHERE r.id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  PERFORM 1 FROM public.merchants WHERE id = v_merchant_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;

  SELECT * INTO v_req FROM public.merchant_payout_requests
   WHERE id = p_request_id FOR UPDATE;
  -- Re-checked under both locks: a privileged delete between the unlocked
  -- lookup and the lock, or a review that landed in between, lands here.
  IF NOT FOUND OR v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  -- A privileged retarget between lookup and lock must not debit the
  -- merchant we locked for a request that now belongs to another.
  IF v_req.merchant_id IS DISTINCT FROM v_merchant_id THEN
    RETURN jsonb_build_object('ok', false, 'code', 'MERCHANT_RETARGETED');
  END IF;

  IF p_approve THEN
    -- Re-evaluate available funds at approve time, under the merchant lock.
    -- Balance = credits - debits; pending requests hold no ledger rows, so
    -- this reflects only committed entries.
    SELECT COALESCE(sum(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0)
      INTO v_balance
      FROM public.merchant_ledger WHERE merchant_id = v_req.merchant_id;
    IF v_req.amount > v_balance THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INSUFFICIENT_BALANCE',
                                'balance', v_balance);
    END IF;
  END IF;

  UPDATE public.merchant_payout_requests
     SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
         reviewed_by = auth.uid(), reviewed_at = now(), rejection_reason = p_reason
   WHERE id = p_request_id;
  IF p_approve THEN
    INSERT INTO public.merchant_ledger
      (merchant_id, entry_type, amount, currency, description, created_by)
    VALUES
      (v_req.merchant_id, 'debit', v_req.amount, v_req.currency,
       'Payout request ' || p_request_id::text, auth.uid());
  END IF;
  PERFORM public.log_admin_action(
    CASE WHEN p_approve THEN 'PAYOUT_APPROVED' ELSE 'PAYOUT_REJECTED' END,
    'merchant_payout_request', p_request_id::text, NULL,
    jsonb_build_object('amount', v_req.amount, 'reason', p_reason), p_reason, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_review_payout(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_payout(uuid, boolean, text) TO postgres;
GRANT EXECUTE ON FUNCTION public.admin_review_payout(uuid, boolean, text) TO service_role;
REVOKE ALL ON FUNCTION public.admin_review_payout(uuid, boolean, text) FROM PUBLIC;

COMMIT;
