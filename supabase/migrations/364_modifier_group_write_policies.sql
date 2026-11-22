-- 364: merchant write policies for the modifier group model.
-- Merchants manage their own products' modifier groups/options; scoped
-- admins via the (361) region-scoped is_merchant_owner. Read stays public.

CREATE POLICY product_modifier_groups_write ON public.product_modifier_groups
  FOR ALL TO authenticated
  USING (public.is_merchant_owner((
    SELECT p.merchant_id FROM public.products p WHERE p.id = product_id)))
  WITH CHECK (public.is_merchant_owner((
    SELECT p.merchant_id FROM public.products p WHERE p.id = product_id)));

CREATE POLICY product_modifier_options_write ON public.product_modifier_options
  FOR ALL TO authenticated
  USING (public.is_merchant_owner((
    SELECT p.merchant_id FROM public.products p
    JOIN public.product_modifier_groups g ON g.product_id = p.id
    WHERE g.id = group_id)))
  WITH CHECK (public.is_merchant_owner((
    SELECT p.merchant_id FROM public.products p
    JOIN public.product_modifier_groups g ON g.product_id = p.id
    WHERE g.id = group_id)));
