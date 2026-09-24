-- 087_admin_content_moderation.sql
-- Owner/admin-only destructive operations, enforced server-side.
-- Each function is SECURITY DEFINER: it bypasses RLS but is gated by
-- public.is_admin() (users.role IN ('admin','owner') + active), so ONLY
-- authenticated admins can execute them. Regular RLS stays untouched.
--
-- Grants: EXECUTE is granted to authenticated only (is_admin() is the real
-- gate); anon/postgrest default is revoked.

CREATE OR REPLACE FUNCTION public.admin_delete_merchant_review(p_review_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;
  DELETE FROM public.reviews WHERE id = p_review_id;
  RETURN FOUND;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_delete_service_review(p_review_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;
  DELETE FROM public.service_reviews WHERE id = p_review_id;
  -- trg_service_reviews_sync_provider (AFTER DELETE) recomputes the provider rating.
  RETURN FOUND;
END; $$;

-- Delete one product. References from merchant reviews are removed first;
-- if the product is referenced by order_items (order history), it is kept but
-- soft-hidden (is_available = false) so history is never destroyed. Returns
-- true when the hard delete happened, false when it was soft-hidden instead.
CREATE OR REPLACE FUNCTION public.admin_delete_product(p_product_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;
  DELETE FROM public.reviews WHERE product_id = p_product_id;
  BEGIN
    DELETE FROM public.products WHERE id = p_product_id;
    RETURN FOUND;
  EXCEPTION WHEN foreign_key_violation THEN
    UPDATE public.products
       SET is_available = false, updated_at = now()
     WHERE id = p_product_id;
    RETURN FOUND;
  END;
END; $$;

-- Delete a merchant entirely. Reviews are removed first (FK has no cascade);
-- products referenced by order history are soft-hidden, the rest is hard
-- deleted (their favorites cascade). Returns true on full deletion.
CREATE OR REPLACE FUNCTION public.admin_delete_merchant(p_merchant_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;
  DELETE FROM public.reviews WHERE merchant_id = p_merchant_id;
  UPDATE public.products
     SET is_available = false, updated_at = now()
   WHERE merchant_id = p_merchant_id
     AND id IN (SELECT product_id FROM public.order_items);
  DELETE FROM public.products
   WHERE merchant_id = p_merchant_id
     AND id NOT IN (SELECT product_id FROM public.order_items);
  DELETE FROM public.merchants WHERE id = p_merchant_id;
  RETURN FOUND;
END; $$;

REVOKE ALL ON FUNCTION public.admin_delete_merchant_review(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_service_review(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_product(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_merchant(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_merchant_review(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_service_review(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_product(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_merchant(uuid) TO authenticated, service_role;