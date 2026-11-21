-- 191: review integrity fixes (E2E squad + auditor, all three pre-probed live).
--
-- 1. service_reviews_insert_own: the booking branch checked ownership + status
--    but never bound the booking's provider/category to the review, so one
--    completed booking authorized reviews against ANY provider (pre-probe:
--    review inserted against qa-provider-B using a qa-provider-A booking).
--    Both branches now bind provider AND category to the completed booking.
-- 2. service_reviews had no identity freeze on UPDATE: a valid review could be
--    re-pointed at another provider/booking/category afterwards (pre-probe:
--    PATCH flipped provider and category at will). New trigger mirrors 150's
--    freeze_review_identity for the reviews table.
-- 3. "ratings rater rw" compared rides.driver_id (drivers.id) to auth.uid()
--    (users.id), so a driver could never rate a rider through the direct table
--    path the apps actually use (lib writes ride_ratings via table upsert;
--    rate_recipient RPC is unused by the apps). Driver branch now resolves
--    drivers.id through drivers.user_id.

-- 1. Insert policy: bind provider + category in both branches.
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
           and b.status = 'completed'
           and b.provider_id = service_reviews.provider_id
           and b.category_type = service_reviews.category_type))
      or
      (booking_id is null and exists (
        select 1 from public.service_bookings b
         where b.user_id = auth.uid()
           and b.provider_id = service_reviews.provider_id
           and b.status = 'completed'
           and b.category_type = service_reviews.category_type))
    )
  );

-- 2. Freeze identity fields on UPDATE (same pattern as 150's reviews freeze).
create or replace function public.freeze_service_review_identity()
returns trigger
language plpgsql
as $$
begin
  if new.user_id is distinct from old.user_id
     or new.provider_id is distinct from old.provider_id
     or new.booking_id is distinct from old.booking_id
     or new.category_type is distinct from old.category_type then
    raise exception 'service review identity fields cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists freeze_service_review_identity on public.service_reviews;
create trigger freeze_service_review_identity
  before update on public.service_reviews
  for each row execute function public.freeze_service_review_identity();

-- 3. ride_ratings: resolve the driver branch through drivers.user_id.
-- 4. sync_service_provider_rating (084) recalculated BOTH old and new provider
--    with ONE combined average/count, and kept a stale rating when a
--    provider's last review was deleted. Now each affected provider is
--    recalculated separately, resetting to the zero-review default (0.0/0).
create or replace function public.sync_service_provider_rating()
returns trigger
language plpgsql
security definer set search_path = public, pg_temp
as $$
begin
  if tg_op in ('INSERT','UPDATE') and new.provider_id is not null then
    update public.service_providers sp
       set rating = coalesce((
             select round(avg(r.rating)::numeric, 1)
               from public.service_reviews r where r.provider_id = sp.id), 0.0),
           rating_count = (
             select count(*) from public.service_reviews r where r.provider_id = sp.id)
     where sp.id = new.provider_id;
  end if;
  if tg_op in ('UPDATE','DELETE') and old.provider_id is not null
     and (tg_op = 'DELETE' or old.provider_id is distinct from new.provider_id) then
    update public.service_providers sp
       set rating = coalesce((
             select round(avg(r.rating)::numeric, 1)
               from public.service_reviews r where r.provider_id = sp.id), 0.0),
           rating_count = (
             select count(*) from public.service_reviews r where r.provider_id = sp.id)
     where sp.id = old.provider_id;
  end if;
  return null;
end;
$$;

drop policy if exists "ratings rater rw" on public.ride_ratings;
create policy "ratings rater rw" on public.ride_ratings
  for all to authenticated
  using (rater_id = auth.uid())
  with check (
    rater_id = auth.uid()
    and exists (
      select 1 from public.rides r
       where r.id = ride_ratings.ride_id
         and (r.rider_id = auth.uid()
              or r.driver_id = (select d.id from public.drivers d
                                 where d.user_id = auth.uid()))
         and r.status = 'completed')
  );
