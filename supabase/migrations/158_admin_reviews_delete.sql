-- Migration 158: let admins delete reviews from the moderation page.
-- Audit finding: admin_reviews_moderation_page calls deleteReview (direct
-- delete on reviews), but reviews has no DELETE policy for any client role,
-- so moderation deletes always failed silently. Customer self-delete is not
-- part of any UI, so this is admin-only by design.

DROP POLICY IF EXISTS reviews_admin_delete ON public.reviews;
CREATE POLICY reviews_admin_delete ON public.reviews
  FOR DELETE TO authenticated
  USING (public.is_admin());
