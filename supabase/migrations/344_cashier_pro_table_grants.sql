-- 344: table-level DML grants for the 343 insurance tables. Supabase's default
-- ACL gave authenticated SELECT only; the RLS policies from 343 already scope
-- rows to the merchant owner/admin, so direct PostgREST CRUD (company
-- management from the desktop app) needs INSERT/UPDATE/DELETE granted.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pos_insurance_companies TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pos_insurance_sales TO authenticated;
