-- 232 (owner decision 2026-11-22): platform-owner stores must not appear to
-- customers. The owner account runs internal/test stores ("owner",
-- "Delwaqty *") that were readable by any signed-in user: the merchants
-- read policy was qual=true and products were "viewable by everyone", so
-- the customer app's status='active' filter was the ONLY thing hiding
-- suspended demo stores, and the "owner" store was fully visible.
--
-- 1) Suspend the still-active "owner" store (the five Delwaqty * demo
--    stores owned by the platform owner are already suspended).
-- 2) Replace the open read policies: non-privileged users (anon +
--    customers) only see rows whose merchant is active; the merchant
--    owner and platform admins keep full visibility for management.

UPDATE public.merchants
   SET status = 'suspended'
 WHERE owner_user_id = (SELECT id FROM auth.users WHERE email = 'said.3pkarino@gmail.com')
   AND status <> 'suspended';

DROP POLICY IF EXISTS "Merchants readable by signed-in users" ON public.merchants;
CREATE POLICY "Merchants readable by signed-in users" ON public.merchants
  FOR SELECT USING (
    status = 'active'
    OR owner_user_id = auth.uid()
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "Products are viewable by everyone" ON public.products;
CREATE POLICY "Products are viewable by everyone" ON public.products
  FOR SELECT USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE status = 'active')
    OR public.is_merchant_owner(merchant_id)
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "offers_view" ON public.offers;
DROP POLICY IF EXISTS "offers_select_public" ON public.offers;
CREATE POLICY "offers_view" ON public.offers
  FOR SELECT USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE status = 'active')
    OR public.is_merchant_owner(merchant_id)
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "branches_view" ON public.branches;
DROP POLICY IF EXISTS "branches_select_public" ON public.branches;
CREATE POLICY "branches_view" ON public.branches
  FOR SELECT USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE status = 'active')
    OR public.is_merchant_owner(merchant_id)
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.reviews;
CREATE POLICY "Reviews are viewable by everyone" ON public.reviews
  FOR SELECT USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE status = 'active')
    OR public.is_admin()
  );

-- The policies call these SECURITY DEFINER boolean helpers; the 218
-- lockdown revoked client EXECUTE on them, which surfaced as 42501 for
-- anon reads hitting the is_admin() branch. They return only booleans
-- about the CALLER, so granting EXECUTE is safe.
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_merchant_owner(uuid) TO anon, authenticated;
