-- 423: request_withdrawal double-tap fix (load-test finding; mirrors 417).
--
-- Problem: request_withdrawal had no idempotency key and no pending
-- uniqueness, so a client double-tap / retry inserted duplicate pending
-- withdrawal_requests (and duplicate negative driver_earnings) whenever the
-- balance covered both.
--
-- Fix (417 pattern):
--   * optional bounded p_idempotency_key (blank/whitespace-only or >128
--     chars -> success=false reason=invalid_idempotency_key);
--   * keyed retry with the SAME amount returns the original request
--     (duplicate=true, original id/amount/status); the same key with a
--     DIFFERENT amount returns idempotency_conflict;
--   * one pending withdrawal per driver, enforced for every writer by a
--     unique partial index, plus a friendly pending_exists refusal under the
--     driver-row lock;
--   * the drivers row is locked FOR UPDATE first (lock order: drivers ->
--     withdrawal_requests -> driver_earnings), unchanged from the pre-423
--     body, so the check + insert serialize per driver.
--
-- NON-RERUNNABLE: the DROP FUNCTION public.request_withdrawal(uuid, double
-- precision, text) below is intentionally not IF-EXISTS guarded. Re-running
-- after a successful apply fails loudly there and aborts the transaction.
--
-- Signature: the three-arg form is DROPPED and replaced with a four-arg form
-- whose p_idempotency_key defaults to NULL, so existing callers (app passes
-- driver_id, amount, method) keep working unchanged. Grants are recreated
-- to match the pre-423 ACL exactly (postgres, authenticated, service_role).
--
-- PRE-DEPLOY DATA CHECK: the one-pending unique index fails if live
-- duplicates exist. Run before applying:
--   SELECT driver_id, count(*) FROM public.withdrawal_requests
--    WHERE status='pending' GROUP BY driver_id HAVING count(*) > 1;
-- (Prod 2026-11-23: withdrawal_requests is empty; check passes.)

BEGIN;

-- Existing-data guard: refuse to apply over duplicate pending withdrawals.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT driver_id, count(*) AS c
      FROM public.withdrawal_requests
     WHERE status = 'pending'
     GROUP BY driver_id
    HAVING count(*) > 1
  LOOP
    RAISE EXCEPTION 'DUPLICATE_PENDING_WITHDRAWALS: driver % has % pending requests', r.driver_id, r.c;
  END LOOP;
END;
$$;

ALTER TABLE public.withdrawal_requests
  ADD COLUMN IF NOT EXISTS idempotency_key text;

-- One pending withdrawal per driver, enforced for every writer.
CREATE UNIQUE INDEX IF NOT EXISTS withdrawal_requests_one_pending_per_driver
  ON public.withdrawal_requests (driver_id)
  WHERE status = 'pending';

-- Idempotency keys unique per driver when present.
CREATE UNIQUE INDEX IF NOT EXISTS withdrawal_requests_idempotency_key_unique
  ON public.withdrawal_requests (driver_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Replace the racy three-argument form; recreate its exact grants below.
-- (Non-rerunnable by design; see the header comment.)
DROP FUNCTION public.request_withdrawal(uuid, double precision, text);

CREATE FUNCTION public.request_withdrawal(p_driver_id uuid, p_amount double precision, p_method text DEFAULT 'bank'::text, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_owner uuid;
  v_balance numeric;
  v_id uuid;
  v_amount numeric;
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
  END IF;
  -- 423: bound the optional idempotency key (nonempty after trim,
  -- length-capped) before it is stored or indexed.
  IF p_idempotency_key IS NOT NULL
     AND (btrim(p_idempotency_key) = '' OR length(p_idempotency_key) > 128) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_idempotency_key');
  END IF;

  -- Lock the drivers row FOR UPDATE first, held for the whole
  -- check + insert (unchanged from the pre-423 body).
  SELECT user_id INTO v_owner FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'driver_not_found');
  END IF;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  -- 423: idempotent retry. A client retry (double-tap, timeout, app
  -- restart) with the same key and the same amount returns the original
  -- request instead of creating a second one. The same key with a
  -- different amount is a conflict, not a silent replay.
  IF p_idempotency_key IS NOT NULL THEN
    SELECT r.id, r.amount, r.status INTO v_id, v_amount, v_status
      FROM public.withdrawal_requests r
     WHERE r.driver_id = p_driver_id AND r.idempotency_key = p_idempotency_key;
    IF FOUND THEN
      IF v_amount <> p_amount THEN
        RETURN jsonb_build_object('success', false, 'reason', 'idempotency_conflict',
                                  'withdrawal_id', v_id, 'amount', v_amount, 'status', v_status);
      END IF;
      RETURN jsonb_build_object('success', true, 'withdrawal_id', v_id, 'duplicate', true,
                                'amount', v_amount, 'status', v_status);
    END IF;
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_balance FROM public.driver_earnings WHERE driver_id = p_driver_id;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > v_balance THEN
    RETURN jsonb_build_object('success', false, 'reason', 'insufficient_balance');
  END IF;

  -- 423: one pending request per driver (backstopped by the
  -- withdrawal_requests_one_pending_per_driver unique index).
  IF EXISTS (
    SELECT 1 FROM public.withdrawal_requests
     WHERE driver_id = p_driver_id AND status = 'pending'
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'pending_exists');
  END IF;

  INSERT INTO public.withdrawal_requests (driver_id, amount, status, method, idempotency_key)
  VALUES (p_driver_id, p_amount, 'pending', p_method, p_idempotency_key)
  RETURNING id INTO v_id;
  INSERT INTO public.driver_earnings (driver_id, type, amount, description)
  VALUES (p_driver_id, 'withdrawal', -p_amount, 'Withdrawal request');
  UPDATE public.drivers SET earnings_balance = v_balance - p_amount WHERE id = p_driver_id;
  RETURN jsonb_build_object('success', true, 'withdrawal_id', v_id);
END;
$function$;

-- Recreate the pre-423 ACL exactly: postgres, authenticated, service_role.
GRANT EXECUTE ON FUNCTION public.request_withdrawal(uuid, double precision, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(uuid, double precision, text, text) TO postgres;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(uuid, double precision, text, text) TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
