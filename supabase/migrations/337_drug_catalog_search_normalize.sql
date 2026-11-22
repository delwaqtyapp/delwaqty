-- 337 (approved 3:17): search-normalized shadow column for the shared drug
-- catalog. Display names stay as-is; matching normalizes Arabic spelling
-- variants (alef/hamza forms, ى/ي, ة/ه, Egyptian transliteration letters
-- ڤ/پ/گ/چ), strips diacritics + tatweel, lowercases English. Powers the
-- cashier's fast typed search (brand AR/EN + active ingredient).

CREATE EXTENSION IF NOT EXISTS pg_trgm ;

CREATE OR REPLACE FUNCTION public.cashier_normalize_text(p text)
 RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT NULLIF(btrim(regexp_replace(
    translate(lower(coalesce(p, '')),
      'أإآٱىةئؤڤپگچ' || chr(160),
      'اااايهيوفبكج' || ' '),
    '[' || chr(0x0640) || chr(0x064B) || '-' || chr(0x0652) || chr(0x0670) || ']+|\s+', ' ', 'g')), '');
$function$;

ALTER TABLE public.drug_catalog
  ADD COLUMN IF NOT EXISTS search_norm text
    GENERATED ALWAYS AS (
      public.cashier_normalize_text(
        coalesce(name_ar, '') || ' ' || coalesce(name_en, '') || ' ' ||
        coalesce(active_ingredient, '') || ' ' || coalesce(manufacturer, ''))
    ) STORED;

CREATE INDEX IF NOT EXISTS drug_catalog_search_norm_trgm
  ON public.drug_catalog USING gin (search_norm gin_trgm_ops);

-- Fast typed search for the cashier lookup: prefix hits first, then
-- trigram similarity over the normalized shadow. Read-only.
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
           similarity(d.search_norm, q.nq),
           CASE WHEN d.search_norm LIKE q.nq || '%' THEN 1.0
                WHEN d.search_norm LIKE '% ' || q.nq || '%' THEN 0.9
                WHEN d.search_norm LIKE '%' || q.nq || '%' THEN 0.6 ELSE 0 END
         )::real AS score
    FROM public.drug_catalog d, q
   WHERE d.is_active
     AND q.nq IS NOT NULL
     AND (d.search_norm % q.nq OR d.search_norm LIKE '%' || q.nq || '%'
          OR d.barcode = btrim(p_query))
   ORDER BY score DESC, d.name_en
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100));
$function$;

GRANT EXECUTE ON FUNCTION public.drug_catalog_search(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.drug_catalog_search(text, integer) TO anon;

-- Generated columns execute the function as the querying role.
GRANT EXECUTE ON FUNCTION public.cashier_normalize_text(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cashier_normalize_text(text) TO anon;
