-- 167: Anti review-bombing mitigation (bughunt F12).
-- The shipped review UI submits without order_id, so requiring one is a
-- product decision (needs his call). This caps the abuse without breaking the
-- app: one order-less review per user per merchant. Throwaway-account spam
-- now yields one review per account per merchant instead of unlimited.

create unique index if not exists reviews_one_orderless_per_user_merchant
  on public.reviews (user_id, merchant_id)
  where order_id is null and merchant_id is not null;
