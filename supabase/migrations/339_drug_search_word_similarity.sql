-- 339: the 337 search compared the whole concatenated catalog string, which
-- dilutes trigram similarity for short queries (owner's كونتافيڤر found
-- nothing). Switch to pg_trgm word similarity: the query is compared to the
-- best-matching WORD in the normalized shadow, with prefix/substring boosts.
CREATE OR REPLACE FUNCTION public.drug_catalog_search(p_query text, p_limit integer DEFAULT 20)
 RETURNS TABLE(id uuid, name_en text, name_ar text, active_ingredient text,
               manufacturer text, official_price_egp numeric, barcode text,
               dosage_form text, strength text, category text, score real)
 LANGUAGE sql STABLE SECURITY INVOKER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH q AS (SELECT public.cashier_normalize_text(p_query) AS nq)
  SELECT d.id, d.name_en, d.name_ar, d.active_ingredient, d.manufacturer,
         d.official_price_egp, d.barcode, d.dosage_form, d.strength, d.category,
         GREATEST(
           strict_word_similarity(q.nq, d.search_norm),
           CASE WHEN d.search_norm LIKE q.nq || '%' THEN 1.0
                WHEN d.search_norm LIKE '% ' || q.nq || '%' THEN 0.95
                WHEN d.search_norm LIKE '%' || q.nq || '%' THEN 0.7 ELSE 0 END,
           CASE WHEN d.barcode = btrim(p_query) THEN 1.0 ELSE 0 END
         )::real AS score
    FROM public.drug_catalog d, q
   WHERE d.is_active
     AND q.nq IS NOT NULL
     AND (q.nq <<% d.search_norm
          OR d.search_norm LIKE '%' || q.nq || '%'
          OR d.barcode = btrim(p_query))
   ORDER BY score DESC, d.name_en
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100));
$function$;
