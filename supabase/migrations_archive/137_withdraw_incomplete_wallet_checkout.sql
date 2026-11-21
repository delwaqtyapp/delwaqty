-- The 136 trigger incorrectly trusted a client-insertable ledger row as
-- proof of a debit. Withdraw it until order creation + payment is a single
-- server transaction, with ledger insert rights restricted to trusted RPCs.
DROP TRIGGER IF EXISTS wallet_tx_mark_order_paid ON public.wallet_transactions;
DROP FUNCTION IF EXISTS public.wallet_tx_mark_order_paid();
