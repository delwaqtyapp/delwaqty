-- 459: review integrity (#327 one review per order; security: reply and name fields).
-- Gaps found on #109 (merchant review card):
--   1. Nothing stopped a customer reviewing the same order twice.
--   2. "Users can update own reviews" lets a customer write merchant_reply,
--      merchant_replied_at and user_name (fake a merchant reply or a name),
--      and INSERT can set them too.
-- Fix:
--   * one review per order: partial unique index on reviews(order_id) where
--     order_id is not null. Prod table is empty; the index build also fails
--     loudly if duplicates ever exist, so nothing is deleted silently.
--   * freeze_review_identity also freezes user_name for everyone except the
--     DB owner/service (auth.uid() is null), and freezes merchant_reply /
--     merchant_replied_at for anyone who is not the merchant's owner or a
--     country admin. The reply RPCs run as the merchant (auth.uid() is the
--     merchant owner), so they keep working.
--   * BEFORE INSERT guard: a client insert cannot carry a merchant reply, and
--     user_name is taken from the profile, not from the client.
-- Re-runnable.

CREATE UNIQUE INDEX IF NOT EXISTS reviews_one_per_order
  ON public.reviews (order_id) WHERE order_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.freeze_review_identity()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.merchant_id IS DISTINCT FROM OLD.merchant_id
     OR NEW.product_id IS DISTINCT FROM OLD.product_id
     OR NEW.order_id IS DISTINCT FROM OLD.order_id THEN
    RAISE EXCEPTION 'review identity fields cannot be changed';
  END IF;
  -- auth.uid() is null for the DB owner / service role: unrestricted.
  IF auth.uid() IS NOT NULL THEN
    IF NEW.user_name IS DISTINCT FROM OLD.user_name THEN
      RAISE EXCEPTION 'review author name cannot be changed';
    END IF;
    IF (NEW.merchant_reply IS DISTINCT FROM OLD.merchant_reply
        OR NEW.merchant_replied_at IS DISTINCT FROM OLD.merchant_replied_at)
       AND NOT (public._owns_merchant_row(OLD.merchant_id)
                OR public._is_country_admin_uid(auth.uid())) THEN
      RAISE EXCEPTION 'only the merchant can reply to a review';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.reviews_insert_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    NEW.merchant_reply := NULL;
    NEW.merchant_replied_at := NULL;
    NEW.user_name := (SELECT u.full_name FROM public.users u WHERE u.id = NEW.user_id);
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.reviews_insert_guard() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS reviews_insert_guard ON public.reviews;
CREATE TRIGGER reviews_insert_guard BEFORE INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.reviews_insert_guard();
