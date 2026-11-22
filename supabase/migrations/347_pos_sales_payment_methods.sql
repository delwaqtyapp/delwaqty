-- 347: widen pos_sales.payment_method CHECK. The desktop cashier (340/346)
-- records the first split-payment method, which can be 'card' or 'deferred'
-- (أجل); the 201-era CHECK only allowed cash/instapay/vodafone_cash, so any
-- deferred-first sale failed with a constraint violation. 'mixed' covers
-- future primary-method labeling. The split detail stays in
-- pos_sale_payments; this column is only the primary-method label.
ALTER TABLE public.pos_sales DROP CONSTRAINT IF EXISTS pos_sales_payment_method_check;
ALTER TABLE public.pos_sales
  ADD CONSTRAINT pos_sales_payment_method_check
  CHECK (payment_method IN ('cash','instapay','vodafone_cash','card','deferred','mixed'));
