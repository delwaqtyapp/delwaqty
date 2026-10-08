-- ============================================================
-- 108_merchant_review_reply.sql
-- "Reply" in the merchant console called
-- repo.updateReview(reviewId, comment: reply), which writes the
-- `comment` column — the CUSTOMER'S OWN REVIEW TEXT. The reply box
-- was even pre-filled with that same text, so saving overwrote the
-- review itself.
--
-- It could never succeed either way: reviews_update_own is scoped to
-- `auth.uid() = user_id` (005:185-186), so a merchant is always
-- rejected. The exception was uncaught, so the button produced an
-- unhandled async error and no feedback.
--
-- Fix: a dedicated column pair plus an owner/merchant-scoped RPC that
-- can only write the reply fields and nothing else.
-- ============================================================

ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS merchant_reply TEXT,
  ADD COLUMN IF NOT EXISTS merchant_replied_at TIMESTAMPTZ;

-- ─── reply RPC ─────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.reply_to_merchant_review(
  p_review_id uuid,
  p_reply text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant uuid;
  v_review_user uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_reply IS NULL OR btrim(p_reply) = '' THEN
    RAISE EXCEPTION 'Reply cannot be empty';
  END IF;

  -- The caller must own the merchant this review belongs to.
  SELECT id INTO v_merchant
    FROM public.merchants
   WHERE owner_user_id = v_uid
   LIMIT 1;

  IF v_merchant IS NULL THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT r.user_id INTO v_review_user
    FROM public.reviews r
   WHERE r.id = p_review_id
     AND r.merchant_id = v_merchant;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Review not found';
  END IF;

  -- Writes ONLY the reply columns: the customer's comment, rating and
  -- every other field are unreachable from here.
  UPDATE public.reviews
     SET merchant_reply = btrim(p_reply),
         merchant_replied_at = now()
   WHERE id = p_review_id;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.reply_to_merchant_review(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reply_to_merchant_review(uuid, text) TO authenticated;

-- ─── make the merchant's own reviews readable ──────────────────
-- With only `reviews_update_own` (auth.uid() = user_id) a merchant
-- cannot even see the store's reviews in some contexts; this policy
-- is read-only and owner-scoped.

DROP POLICY IF EXISTS "Merchants can view reviews for their merchant"
  ON public.reviews;
CREATE POLICY "Merchants can view reviews for their merchant"
  ON public.reviews
  FOR SELECT TO authenticated
  USING (
    merchant_id IN (
      SELECT id FROM public.merchants WHERE owner_user_id = auth.uid()
    )
  );