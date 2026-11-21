-- 136_wallet_order_payment.sql
-- Mechanism audit: customers could top up their wallet (request -> admin
-- approval -> credit) but had no way to spend it: wallet_pay existed with
-- zero callers and checkout offered no wallet option. Checkout now offers
-- wallet and calls wallet_pay with reference_type='order'; this trigger is
-- the server-side truth that marks the order paid from the ledger row, so a
-- tampered client cannot mark its own order paid without a real debit.

CREATE OR REPLACE FUNCTION public.wallet_tx_mark_order_paid()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.type = 'payment'
     AND NEW.reference_type = 'order'
     AND NEW.reference_id IS NOT NULL THEN
    UPDATE public.orders
       SET payment_status = 'paid',
           payment_method = 'wallet',
           transaction_id = NEW.id::text,
           updated_at = now()
     WHERE id = NEW.reference_id::uuid
       AND user_id = NEW.user_id
       AND payment_status IS DISTINCT FROM 'paid';
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS wallet_tx_mark_order_paid ON public.wallet_transactions;
CREATE TRIGGER wallet_tx_mark_order_paid
  AFTER INSERT ON public.wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION public.wallet_tx_mark_order_paid();
