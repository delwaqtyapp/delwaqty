-- 336 (owner request 2026-11-22): Arabic drug-name cleanup in the shared
-- catalog before it becomes customer-facing. The seed left 2,045 names with
-- a trailing standalone " /" artifact. Mid-string slashes are meaningful
-- (units like إ.أو./مل) and are NOT touched; spelling normalization is
-- deferred to a designed search-normalized shadow column instead of
-- rewriting transliterations in place.

UPDATE public.drug_catalog
   SET name_ar = regexp_replace(name_ar, '\s*/\s*$', '')
 WHERE name_ar ~ '\s*/\s*$';

-- Collapse accidental double spaces introduced by the seed.
UPDATE public.drug_catalog
   SET name_ar = regexp_replace(name_ar, '\s{2,}', ' ', 'g')
 WHERE name_ar ~ '\s{2,}';
