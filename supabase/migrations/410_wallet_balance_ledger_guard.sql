BEGIN;
-- 410_wallet_balance_ledger_guard.sql
-- Accidental-write guard, not a proof of ledger/balance equality.
-- The transaction-local write flag stays enabled for the rest of the transaction.
-- Hard-delete of public.users or wallets with history now fails by design.
-- Wallet balance writes are normally routed through the
-- ledger-writing functions (the ones that also append wallet_transactions).
--
-- Findings that motivated this (prod, read-only review, Nov 23 2026):
--   * wallet 96766540-0711-49c1-a221-e00cea6b707a (QA bughunt customer) held
--     5 ledger credits totalling 266.45 while balance read 0.00 and the
--     balance_after chain showed two out-of-ledger resets.
--   * wallet 60c27d68-5d61-4ee1-b973-03713d4788cd (anonymized self-deleted
--     customer) held balance 42.50 with zero wallet_transactions rows.
--   Both were QA artifacts written by privileged direct SQL, bypassing every
--   ledger function. No trigger, policy or privilege stopped it.
--
-- What this migration does:
--   1. Adds a guard trigger on wallets: any INSERT with balance <> 0 and any
--      UPDATE that changes balance is rejected unless the transaction first
--      ran `set_config('delwaqty.ledger_write','on',true)`. The flag is set by
--      the nine ledger functions below (redefined with one added line each;
--      bodies otherwise byte-identical to prod).
--   2. Makes wallet_transactions append-only (no UPDATE/DELETE for anyone).
--   3. Revokes table-level UPDATE/DELETE on wallets and INSERT/UPDATE/DELETE
--      on wallet_transactions from anon/authenticated, so a client cannot
--      write even after setting the flag itself. SELECT and zero-balance
--      INSERT on wallets stay (the customer app creates its own empty wallet).
--
-- Idempotent: safe to re-run.

-- 1. Guard trigger ----------------------------------------------------------

CREATE OR REPLACE FUNCTION public._wallet_ledger_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.balance IS DISTINCT FROM 0::numeric
       AND current_setting('delwaqty.ledger_write', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION 'WALLET_LEDGER_GUARD: wallets rows must start at balance 0; balances change only through ledger functions (migration 410)';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.balance IS DISTINCT FROM OLD.balance
     AND current_setting('delwaqty.ledger_write', true) IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'WALLET_LEDGER_GUARD: wallets.balance can only change through the ledger-writing functions (migration 410)';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS wallets_ledger_guard ON public.wallets;
CREATE TRIGGER wallets_ledger_guard
  BEFORE INSERT OR UPDATE ON public.wallets
  FOR EACH ROW EXECUTE FUNCTION public._wallet_ledger_guard();

-- 2. Append-only ledger -----------------------------------------------------

CREATE OR REPLACE FUNCTION public._wallet_transactions_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION 'WALLET_LEDGER_GUARD: wallet_transactions is append-only (migration 410)';
END;
$function$;

DROP TRIGGER IF EXISTS wallet_transactions_append_only ON public.wallet_transactions;
CREATE TRIGGER wallet_transactions_append_only
  BEFORE UPDATE OR DELETE ON public.wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION public._wallet_transactions_append_only();

-- 3. Privilege lockdown ------------------------------------------------------

REVOKE UPDATE, DELETE ON public.wallets FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.wallet_transactions FROM anon, authenticated;

-- 4. Ledger functions redefined with the ledger-write flag -------------------
-- Bodies are identical to prod except the flagged first statement after BEGIN.

CREATE OR REPLACE FUNCTION public.admin_direct_topup(p_account_type text, p_account_id uuid, p_amount numeric, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller    uuid := auth.uid();
  v_wallet_id uuid;
  v_before    numeric;
  v_after     numeric;
  v_target    record;
  v_txn_id    uuid;
BEGIN
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  -- OWNER ONLY. This removes the prior (owner OR TOPUP_APPROVE-admin) gate that
  -- let any region admin credit any wallet without a request + approval.
  IF NOT public._is_owner_uid(v_caller) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN_OWNER_ONLY');
  END IF;

  SELECT id INTO v_target FROM public.users WHERE id = p_account_id;
  IF v_target.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ACCOUNT_NOT_FOUND');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  END IF;

  v_wallet_id := public._ensure_wallet(p_account_id);
  SELECT balance INTO v_before FROM public.wallets WHERE id = v_wallet_id FOR UPDATE;
  v_after := COALESCE(v_before, 0) + p_amount;
  UPDATE public.wallets SET balance = v_after, updated_at = now()
   WHERE id = v_wallet_id;
  INSERT INTO public.wallet_transactions
    (wallet_id, type, amount, reference_type, reference_id, description, balance_after)
  VALUES
    (v_wallet_id, 'credit', p_amount, 'admin_topup', v_caller,
     'Owner direct top-up correction (' || coalesce(p_account_type, 'account') || ')', v_after)
  RETURNING id INTO v_txn_id;

  PERFORM public.write_audit('ADMIN_DIRECT_TOPUP', 'wallets', v_wallet_id::text,
    jsonb_build_object('actor', v_caller, 'actor_role', 'owner',
      'account_id', p_account_id, 'account_type', p_account_type,
      'amount', p_amount, 'balance_before', v_before, 'balance_after', v_after,
      'transaction_id', v_txn_id, 'note', p_note));

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (p_account_id, 'Account funded',
    'Your wallet was credited with ' || p_amount::text, 'admin_topup',
    jsonb_build_object('account_id', p_account_id, 'account_type', p_account_type,
      'amount', p_amount, 'transaction_id', v_txn_id));

  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'wallet_id', v_wallet_id,
    'transaction_id', v_txn_id, 'balance_before', v_before, 'balance_after', v_after,
    'amount', p_amount);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.approve_topup_request(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r          public.topup_requests;
  v_wallet_id uuid;
  v_balance  numeric;
  v_after    numeric;
  v_coll_id  uuid;
BEGIN
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
  -- Sensitive financial approval is OWNER-only. A normal admin is never a
  -- substitute unless an explicit, separately-protected financial role exists.
  IF auth.uid() IS NULL OR NOT public._is_owner_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN_OWNER_ONLY');
  END IF;

  SELECT * INTO r FROM public.topup_requests
   WHERE id = p_request_id FOR UPDATE;
  IF r IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF r.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_PROCESSED', 'status', r.status);
  END IF;
  -- Owner cannot approve their own request (an Owner account filing for itself).
  IF r.account_id = auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'SELF_APPROVAL');
  END IF;

  -- Hard idempotency: the ledger row is the single source of truth. If a credit
  -- already exists for this request, never credit again (double-approval blocked).
  IF EXISTS (SELECT 1 FROM public.regional_collections WHERE topup_request_id = r.id) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_CREDITED');
  END IF;

  -- Atomic credit: lock the wallet row, compute, write, ledger.
  v_wallet_id := public._ensure_wallet(r.account_id);
  SELECT balance INTO v_balance FROM public.wallets WHERE id = v_wallet_id FOR UPDATE;
  v_after := COALESCE(v_balance, 0) + r.amount;
  UPDATE public.wallets SET balance = v_after, updated_at = now()
   WHERE id = v_wallet_id;
  INSERT INTO public.wallet_transactions
    (wallet_id, type, amount, reference_type, reference_id, description, balance_after)
  VALUES
    (v_wallet_id, 'credit', r.amount, 'topup', r.id,
     'Wallet top-up approved (request ' || r.id::text || ')', v_after);

  -- Immutable collection/credit ledger (UNIQUE topup_request_id = idempotency).
  INSERT INTO public.regional_collections
    (admin_id, region_id, account_id, topup_request_id, amount, currency, reference)
  VALUES
    (auth.uid(), r.region_id, r.account_id, r.id, r.amount, r.currency, r.transfer_reference)
  RETURNING id INTO v_coll_id;

  UPDATE public.topup_requests
     SET status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   WHERE id = r.id;

  -- Full audit with balance before/after (write_audit is safe for all actors).
  PERFORM public.write_audit('TOPUP_APPROVED', 'topup_requests', r.id::text,
    jsonb_build_object('account', r.account_id, 'amount', r.amount,
      'method', r.payment_method, 'reference', r.transfer_reference,
      'reviewed_by', auth.uid(), 'collection', v_coll_id,
      'balance_before', v_balance, 'balance_after', v_after));

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES
    (r.account_id, 'Top-up approved', 'Your wallet was credited with ' ||
       r.amount::text || ' ' || coalesce(r.currency, 'EGP'), 'topup_approved',
     jsonb_build_object('topup_request_id', r.id, 'amount', r.amount,
       'wallet_transaction_balance', v_after, 'deep_link', '/wallet'));

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'wallet_balance', v_after, 'collection_id', v_coll_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.wallet_topup(p_user_id uuid, p_amount numeric, p_description text DEFAULT 'Top-up'::text, p_reference_type text DEFAULT 'topup'::text, p_reference_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

DECLARE v_wallet_id uuid; v_balance numeric; v_after numeric; v_tx_id uuid;
BEGIN
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
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
$function$
;

CREATE OR REPLACE FUNCTION public.wallet_pay(p_user_id uuid, p_amount numeric, p_description text DEFAULT 'Payment'::text, p_reference_type text DEFAULT 'payment'::text, p_reference_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

DECLARE v_wallet_id uuid; v_balance numeric; v_after numeric; v_tx_id uuid;
BEGIN
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
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
$function$
;

CREATE OR REPLACE FUNCTION public.approve_wallet_funding_request(p_funding_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_request RECORD;
  v_wallet_id UUID;
  v_new_balance NUMERIC;
  v_approved_by UUID := auth.uid();
BEGIN
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
  -- Authorization: only financial admins/Owner can approve
  IF NOT public.has_financial_permission(v_approved_by, 'approve_wallet_funding') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_funding_request_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_REQUEST_ID');
  END IF;
  IF v_approved_by IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_APPROVER');
  END IF;

  -- Lock the funding request row
  SELECT * INTO STRICT v_request
  FROM public.wallet_funding_requests
  WHERE id = p_funding_request_id
  FOR UPDATE;

  IF v_request.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS', 'current_status', v_request.status);
  END IF;

  -- Ensure wallet exists
  v_wallet_id := public._ensure_wallet(v_request.user_id);

  -- Credit the wallet atomically
  UPDATE public.wallets
  SET balance = balance + v_request.amount,
      updated_at = now()
  WHERE id = v_wallet_id
  RETURNING balance INTO v_new_balance;

  -- Record the wallet transaction
  INSERT INTO public.wallet_transactions (
    wallet_id,
    type,
    amount,
    description,
    reference_type,
    reference_id,
    created_by
  ) VALUES (
    v_wallet_id,
    'credit',
    v_request.amount,
    'Funding request approved: ' || v_request.reference,
    'funding_approval',
    v_request.id,
    v_approved_by
  );

  -- Update funding request status
  UPDATE public.wallet_funding_requests
  SET status = 'approved',
      approved_by = v_approved_by,
      approved_at = now(),
      updated_at = now()
  WHERE id = p_funding_request_id;

  RETURN jsonb_build_object(
    'ok', true,
    'transaction_id', (SELECT id FROM public.wallet_transactions WHERE reference_id = v_request.id AND type = 'credit' ORDER BY created_at DESC LIMIT 1),
    'new_balance', v_new_balance,
    'amount', v_request.amount
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.wallet_topup(p_amount numeric, p_method text DEFAULT 'manual'::text, p_reference text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text)
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
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
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
$function$
;

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
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
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
$function$
;

CREATE OR REPLACE FUNCTION public.wallet_adjust(p_account_id uuid, p_amount numeric, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_caller    uuid := auth.uid();
  v_wallet_id uuid;
  v_before    numeric;
  v_after     numeric;
  v_txn_id    uuid;
begin
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
  if v_caller is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;
  if not public._is_owner_uid(v_caller) then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN_OWNER_ONLY');
  end if;
  if not exists (select 1 from public.users where id = p_account_id) then
    return jsonb_build_object('ok', false, 'code', 'ACCOUNT_NOT_FOUND');
  end if;
  if p_amount is null or p_amount = 0 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  end if;

  v_wallet_id := public._ensure_wallet(p_account_id);
  select balance into v_before from public.wallets where id = v_wallet_id for update;
  v_after := coalesce(v_before, 0) + p_amount;
  if v_after < 0 then
    return jsonb_build_object('ok', false, 'code', 'INSUFFICIENT_BALANCE',
      'balance', v_before, 'requested', p_amount);
  end if;

  update public.wallets set balance = v_after, updated_at = now() where id = v_wallet_id;

  insert into public.wallet_transactions
    (wallet_id, type, amount, reference_type, reference_id, description, balance_after)
  values
    (v_wallet_id, case when p_amount > 0 then 'credit' else 'debit' end,
     abs(p_amount), 'admin_adjustment', v_caller,
     'Owner adjustment' || coalesce(' - ' || p_note, ''), v_after)
  returning id into v_txn_id;

  perform public.write_audit('WALLET_ADJUST', 'wallets', v_wallet_id::text,
    jsonb_build_object('actor', v_caller, 'account_id', p_account_id,
      'amount', p_amount, 'balance_before', v_before, 'balance_after', v_after,
      'transaction_id', v_txn_id, 'note', p_note));

  return jsonb_build_object('ok', true, 'code', 'OK', 'wallet_id', v_wallet_id,
    'balance_before', v_before, 'balance_after', v_after, 'transaction_id', v_txn_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public._wallet_credit(p_user_id uuid, p_amount numeric, p_description text DEFAULT 'Credit'::text, p_reference_type text DEFAULT 'credit'::text, p_reference_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_wallet_id uuid;
  v_balance numeric;
  v_after numeric;
  v_tx_id uuid;
begin
  PERFORM set_config('delwaqty.ledger_write', 'on', true);
  if p_user_id is null then return jsonb_build_object('ok', false, 'code', 'INVALID_USER'); end if;
  if p_amount is null or p_amount <= 0 then return jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT'); end if;
  v_wallet_id := public._ensure_wallet(p_user_id);
  select balance into v_balance from public.wallets where id = v_wallet_id for update;
  v_after := coalesce(v_balance, 0) + p_amount;
  update public.wallets set balance = v_after, updated_at = now() where id = v_wallet_id;
  insert into public.wallet_transactions (wallet_id, type, amount, reference_type, reference_id, description, balance_after)
  values (v_wallet_id, 'credit', p_amount, p_reference_type, p_reference_id, p_description, v_after)
  returning id into v_tx_id;
  return jsonb_build_object('ok', true, 'code', 'OK', 'wallet_id', v_wallet_id, 'new_balance', v_after, 'transaction_id', v_tx_id);
end;
$function$
;

COMMIT;
