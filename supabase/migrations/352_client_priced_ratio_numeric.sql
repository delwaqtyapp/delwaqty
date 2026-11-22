-- 352: FIX-UP of 351 - the ratio divided two integer sums, so any ratio
-- below 1 truncated to 0. Cast the numerator to numeric.

CREATE OR REPLACE FUNCTION public.admin_client_priced_ratio(p_since timestamptz DEFAULT (now() - interval '30 days'))
 RETURNS TABLE(merchant_id uuid, merchant_name text, sales integer, total_lines integer, client_priced_lines integer, client_priced_ratio numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_ONLY';
  END IF;
  RETURN QUERY
  SELECT s.merchant_id,
         m.name,
         COUNT(*)::integer,
         COALESCE(SUM(jsonb_array_length(s.items)), 0)::integer,
         COALESCE(SUM(s.client_priced_lines), 0)::integer,
         ROUND(COALESCE(SUM(s.client_priced_lines), 0)::numeric
               / NULLIF(COALESCE(SUM(jsonb_array_length(s.items)), 0), 0), 3)
    FROM public.pos_sales s
    JOIN public.merchants m ON m.id = s.merchant_id
   WHERE s.created_at >= p_since
     AND s.status = 'completed'
   GROUP BY s.merchant_id, m.name
  HAVING COALESCE(SUM(s.client_priced_lines), 0) > 0
   ORDER BY 6 DESC, 5 DESC;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.admin_client_priced_ratio(timestamptz) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_client_priced_ratio(timestamptz) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_client_priced_ratio(timestamptz) TO authenticated;

