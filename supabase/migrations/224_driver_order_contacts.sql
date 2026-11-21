-- 224: Driver-scoped customer contact lookup, mirroring merchant_order_contacts
-- (159). users is self+admin only, so the driver app could never show the
-- customer's phone on a food order (item 18). The driver may only see contact
-- details for orders actually assigned to them.
CREATE OR REPLACE FUNCTION public.driver_order_contacts()
 RETURNS TABLE(order_id uuid, full_name text, phone text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT d.id INTO v_driver
    FROM public.drivers d
   WHERE d.user_id = v_uid;

  IF v_driver IS NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT o.id, u.full_name, u.phone
  FROM public.orders o
  JOIN public.users u ON u.id = o.user_id
  WHERE public.is_admin() OR o.driver_id = v_driver;
END;
$function$
;
REVOKE EXECUTE ON FUNCTION public.driver_order_contacts() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.driver_order_contacts() FROM anon;
GRANT EXECUTE ON FUNCTION public.driver_order_contacts() TO authenticated;
