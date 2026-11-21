-- 175_coupon_redemption_lockdown.sql
-- Bughunt F17/F18 (second pass):
-- F17: redeem_coupon was executable by ANON with an arbitrary p_user_id.
--   Live-verified: a signed-out caller burned global usage_limit, planted
--   coupon_redemptions rows for foreign users (blocking their future orders
--   with COUPON_ALREADY_REDEEMED), and could probe whether any user redeemed
--   a coupon (oracle). Fix: caller must be authenticated and redeem only for
--   themselves; the one internal caller (create_order) passes auth.uid().
-- F18: increment_coupon_usage and apply_coupon let any authenticated user
--   burn a coupon's GLOBAL usage_limit without placing an order
--   (apply_coupon increments at validation time; increment_coupon_usage is
--   a bare counter bump). Live-verified. The authoritative counter is
--   create_order's redeem_coupon call, so both are revoked from app roles.
--   The shipped app's post-order incrementUsage call now fails silently
--   (catchError -> direct table update -> blocked by RLS), which also fixes
--   the double-count per coupon order.

CREATE OR REPLACE FUNCTION public.redeem_coupon(p_coupon_code text, p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_coupon public.coupons%ROWTYPE;
BEGIN
  -- Self-only: a redemption binds the caller's identity; no anon or
  -- cross-account redemption (prevents usage burn, targeted blocking and
  -- the redeemed-or-not oracle).
  IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  SELECT * INTO v_coupon FROM public.coupons WHERE code = btrim(p_coupon_code);
  IF v_coupon.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_not_found');
  END IF;
  IF NOT v_coupon.is_active THEN
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_inactive');
  END IF;
  IF v_coupon.expires_at IS NOT NULL AND v_coupon.expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_expired');
  END IF;
  IF v_coupon.usage_limit IS NOT NULL AND COALESCE(v_coupon.used_count, 0) >= v_coupon.usage_limit THEN
    RETURN jsonb_build_object('success', false, 'reason', 'usage_limit_reached');
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.coupon_redemptions r
    WHERE r.coupon_id = v_coupon.id AND r.user_id = p_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_redeemed');
  END IF;

  UPDATE public.coupons
  SET used_count = COALESCE(used_count, 0) + 1
  WHERE id = v_coupon.id;
  INSERT INTO public.coupon_redemptions (coupon_id, user_id)
  VALUES (v_coupon.id, p_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'coupon_id', v_coupon.id,
    'discount_type', v_coupon.discount_type,
    'discount_value', v_coupon.discount_value,
    'minimum_order', v_coupon.minimum_order,
    'maximum_discount', v_coupon.maximum_discount,
    'merchant_id', v_coupon.merchant_id
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.redeem_coupon(text, uuid) FROM anon;

REVOKE EXECUTE ON FUNCTION public.increment_coupon_usage(text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.apply_coupon(text, numeric) FROM anon, authenticated;

-- apply_coupon and increment_coupon_usage also held a PUBLIC grant; the
-- per-role revokes above are insufficient on their own.
REVOKE EXECUTE ON FUNCTION public.apply_coupon(text, numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_coupon_usage(text) FROM PUBLIC;
