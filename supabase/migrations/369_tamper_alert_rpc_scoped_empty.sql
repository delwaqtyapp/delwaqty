-- 369: tamper-alert RPCs must never 400 for region-scoped admins (reviewer
-- P1: admin/tamper-alerts spun forever on HTTP 400 for a village admin).
-- Non-country active admins now get rows for their covered regions only;
-- anyone without admin scope gets an empty set instead of ADMIN_ONLY.
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_client_priced_ratio(p_since timestamp with time zone DEFAULT (now() - '30 days'::interval))
 RETURNS TABLE(merchant_id uuid, merchant_name text, sales integer, total_lines integer, client_priced_lines integer, client_priced_ratio numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- No ADMIN_ONLY raise: unscoped callers get an empty set, scoped admins
  -- get only the regions they cover, country/owner get everything.
  IF auth.uid() IS NULL
     OR NOT (public._is_country_admin_uid(auth.uid())
             OR public._is_active_admin_uid(auth.uid())) THEN
    RETURN;
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
     AND (
       public._is_country_admin_uid(auth.uid())
       OR public.is_admin_for_region(public._merchant_region_id(s.merchant_id))
     )
   GROUP BY s.merchant_id, m.name
  HAVING COALESCE(SUM(s.client_priced_lines), 0) > 0
   ORDER BY 6 DESC, 5 DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_insurance_mismatches(p_since timestamp with time zone DEFAULT (now() - '30 days'::interval))
 RETURNS TABLE(merchant_id uuid, merchant_name text, insurance_sale_id bigint, company_id uuid, claimed_total numeric, server_total numeric, company_share numeric, patient_share numeric, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL
     OR NOT (public._is_country_admin_uid(auth.uid())
             OR public._is_active_admin_uid(auth.uid())) THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT s.merchant_id, m.name, s.id, s.company_id, s.total, s.server_total,
         s.company_share, s.patient_share, s.created_at
    FROM public.pos_insurance_sales s
    JOIN public.merchants m ON m.id = s.merchant_id
   WHERE s.total_mismatch
     AND s.created_at >= p_since
     AND (
       public._is_country_admin_uid(auth.uid())
       OR public.is_admin_for_region(public._merchant_region_id(s.merchant_id))
     )
   ORDER BY s.created_at DESC;
END;
$function$;

COMMIT;
