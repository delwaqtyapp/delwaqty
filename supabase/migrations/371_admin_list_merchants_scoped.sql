-- 371: scoped admin merchant list. AdminMerchantsPage read the merchants
-- table directly, whose public-catalog SELECT policy exposes every ACTIVE
-- merchant to any signed-in user - so region-scoped admins saw the whole
-- country. This RPC is the admin list path: owner/country see all
-- merchants (any status); region-scoped active admins see only merchants
-- whose geocoded region is inside their assigned scope; anyone else gets
-- an empty set. The public catalog policy is unchanged.
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_list_merchants(p_search text DEFAULT NULL::text, p_status text DEFAULT NULL::text)
 RETURNS SETOF public.merchants
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL
     OR NOT (public._is_country_admin_uid(auth.uid())
             OR public._is_active_admin_uid(auth.uid())) THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT m.*
    FROM public.merchants m
   WHERE (p_status IS NULL OR btrim(p_status) = '' OR m.status = p_status)
     AND (p_search IS NULL OR btrim(p_search) = ''
          OR m.name ILIKE '%' || btrim(p_search) || '%'
          OR COALESCE(m.email, '') ILIKE '%' || btrim(p_search) || '%')
     AND (
       public._is_country_admin_uid(auth.uid())
       OR public.is_admin_for_region(
            public._ops_scope_region(public._merchant_region_id(m.id)))
     )
   ORDER BY m.created_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_merchants(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_merchants(text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_list_merchants(text, text) TO authenticated;

COMMIT;
