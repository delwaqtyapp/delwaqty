-- Migration 159: scoped customer-contact access for merchants.
--
-- Audit finding: the merchant dashboard embeds users(full_name, phone) in its
-- orders query, but the users table only allows self + admin reads, so the
-- embed always returned null - merchants see blank customer names and cannot
-- call customers about their orders. A wide users-read policy would leak
-- every customer's PII; this RPC returns exactly name+phone, only for orders
-- belonging to a merchant the caller owns (or admin).

CREATE OR REPLACE FUNCTION public.merchant_order_contacts(p_merchant_id uuid)
RETURNS TABLE (order_id uuid, full_name text, phone text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF NOT (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.merchants m
      WHERE m.id = p_merchant_id AND m.owner_user_id = v_uid
    )
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT o.id, u.full_name, u.phone
  FROM public.orders o
  JOIN public.users u ON u.id = o.user_id
  WHERE o.merchant_id = p_merchant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.merchant_order_contacts(uuid) TO authenticated;
