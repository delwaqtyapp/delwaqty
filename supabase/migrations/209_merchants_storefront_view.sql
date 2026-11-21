-- 209: Security M2 - merchants public SELECT exposed email/phone/exact
-- coordinates to anonymous callers. Base table is now authenticated-only;
-- anonymous storefront previews use a curated display view without contact
-- fields. Owner self-update tightened to authenticated.

CREATE OR REPLACE VIEW public.merchant_storefront AS
SELECT id, name, type, status, description, logo_url, cover_url, address,
       latitude, longitude, rating, total_reviews, delivery_fee, min_order,
       delivery_time_min, is_featured, is_open
FROM public.merchants
WHERE status = 'active';

REVOKE ALL ON public.merchant_storefront FROM public;
GRANT SELECT ON public.merchant_storefront TO anon, authenticated;

DROP POLICY "Merchants are viewable by everyone" ON public.merchants;
CREATE POLICY "Merchants readable by signed-in users"
  ON public.merchants FOR SELECT TO authenticated USING (true);

DROP POLICY "Merchants can update own via owner_user_id" ON public.merchants;
CREATE POLICY "Merchants can update own via owner_user_id"
  ON public.merchants FOR UPDATE TO authenticated
  USING (auth.uid() = owner_user_id)
  WITH CHECK (auth.uid() = owner_user_id);

NOTIFY pgrst, 'reload schema';
