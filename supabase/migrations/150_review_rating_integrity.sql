-- ============================================================
-- 150_review_rating_integrity.sql
-- Review/rating forgery lockdown:
--  1. reviews UPDATE had USING but no WITH CHECK: a user could
--     reassign their review to another user, merchant, product or
--     order. Now auth.uid() must stay the author, and a trigger
--     freezes the identity columns (user/merchant/product/order)
--     so an edit can only change rating/comment.
--  2. reviews INSERT took any merchant/order pair. When an order
--     is cited it must be a real delivered order by this user at
--     this merchant. order_id stays optional because product
--     reviews in the app are submitted without one.
--  3. service_reviews INSERT accepted any booking_id. A cited
--     booking must be a completed booking by this user. Nullable
--     booking_id stays allowed (app flow).
--  4. ride_ratings took any ride_id. The rater must now be a
--     participant (rider or driver) of the ride being rated.
-- ============================================================

-- ─── 1. reviews update: WITH CHECK + identity freeze ─────────

DROP POLICY IF EXISTS "Users can update own reviews" ON public.reviews;
CREATE POLICY "Users can update own reviews" ON public.reviews
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.freeze_review_identity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.merchant_id IS DISTINCT FROM OLD.merchant_id
     OR NEW.product_id IS DISTINCT FROM OLD.product_id
     OR NEW.order_id IS DISTINCT FROM OLD.order_id THEN
    RAISE EXCEPTION 'review identity fields cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS freeze_review_identity ON public.reviews;
CREATE TRIGGER freeze_review_identity
  BEFORE UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.freeze_review_identity();

-- ─── 2. reviews insert: verified order when cited ────────────

DROP POLICY IF EXISTS "Users can create reviews" ON public.reviews;
CREATE POLICY "Users can create reviews" ON public.reviews
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      order_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = reviews.order_id
          AND o.user_id = auth.uid()
          AND o.merchant_id = reviews.merchant_id
          AND o.status = 'delivered'
      )
    )
  );

-- ─── 3. service_reviews insert: verified booking when cited ──

DROP POLICY IF EXISTS service_reviews_insert_own ON public.service_reviews;
CREATE POLICY service_reviews_insert_own ON public.service_reviews
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      booking_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.service_bookings b
        WHERE b.id = service_reviews.booking_id
          AND b.user_id = auth.uid()
          AND b.status = 'completed'
      )
    )
  );

-- ─── 4. ride_ratings: rater must be a ride participant ───────

DROP POLICY IF EXISTS "ratings rater rw" ON public.ride_ratings;
CREATE POLICY "ratings rater rw" ON public.ride_ratings
  FOR ALL TO authenticated
  USING (rater_id = auth.uid())
  WITH CHECK (
    rater_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.rides r
      WHERE r.id = ride_ratings.ride_id
        AND (r.rider_id = auth.uid() OR r.driver_id = auth.uid())
    )
  );
