-- 338: repair 337's normalization (diacritics range swallowed Arabic
-- letters; one translate target was misaligned). The generated column is
-- STORED, so it must be dropped and rebuilt after the function is fixed.
DROP INDEX IF EXISTS public.drug_catalog_search_norm_trgm;
ALTER TABLE public.drug_catalog DROP COLUMN IF EXISTS search_norm;

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
  ADD COLUMN search_norm text
    GENERATED ALWAYS AS (
      public.cashier_normalize_text(
        coalesce(name_ar, '') || ' ' || coalesce(name_en, '') || ' ' ||
        coalesce(active_ingredient, '') || ' ' || coalesce(manufacturer, ''))
    ) STORED;

CREATE INDEX drug_catalog_search_norm_trgm
  ON public.drug_catalog USING gin (search_norm gin_trgm_ops);
