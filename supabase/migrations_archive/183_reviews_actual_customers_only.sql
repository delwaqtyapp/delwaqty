-- 183: Reviews closed to actual customers (owner decision 2026-11-21, item 4)
-- Only customers with a delivered order / completed ride / completed booking
-- can review. Previously an order-less (or booking-less) review needed no
-- purchase at all.

-- Merchant/product reviews: order-less reviews now require at least one
-- delivered order from this user to this merchant. Reviews that name an
-- order keep the stricter per-order check.
drop policy if exists "Users can create reviews" on public.reviews;
create policy "Users can create reviews" on public.reviews
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and (
      (order_id is not null and exists (
        select 1 from public.orders o
         where o.id = reviews.order_id
           and o.user_id = auth.uid()
           and o.merchant_id = reviews.merchant_id
           and o.status = 'delivered'))
      or
      (order_id is null and exists (
        select 1 from public.orders o
         where o.user_id = auth.uid()
           and o.merchant_id = reviews.merchant_id
           and o.status = 'delivered'))
    )
  );

-- Driver/rider ratings: ride must be completed, not merely joined.
drop policy if exists "ratings rater rw" on public.ride_ratings;
create policy "ratings rater rw" on public.ride_ratings
  for all to authenticated
  using (rater_id = auth.uid())
  with check (
    rater_id = auth.uid()
    and exists (
      select 1 from public.rides r
       where r.id = ride_ratings.ride_id
         and (r.rider_id = auth.uid() or r.driver_id = auth.uid())
         and r.status = 'completed')
  );

-- Service reviews: booking-less reviews require a completed booking with
-- that provider.
drop policy if exists service_reviews_insert_own on public.service_reviews;
create policy service_reviews_insert_own on public.service_reviews
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and (
      (booking_id is not null and exists (
        select 1 from public.service_bookings b
         where b.id = service_reviews.booking_id
           and b.user_id = auth.uid()
           and b.status = 'completed'))
      or
      (booking_id is null and exists (
        select 1 from public.service_bookings b
         where b.user_id = auth.uid()
           and b.provider_id = service_reviews.provider_id
           and b.status = 'completed'))
    )
  );
