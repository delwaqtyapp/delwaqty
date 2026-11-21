-- 213: Security R1/R2 - the 208/209 views repeated the C1 bug class:
-- Supabase default privileges grant FULL table-like privileges on new views
-- to anon+authenticated, and "REVOKE ALL ... FROM public" does not touch
-- role-specific grants. Both views were anon-writable (anon PATCH 204).

REVOKE ALL ON public.app_public_config FROM public, anon, authenticated;
GRANT SELECT ON public.app_public_config TO anon, authenticated;

REVOKE ALL ON public.merchant_storefront FROM public, anon, authenticated;
GRANT SELECT ON public.merchant_storefront TO anon, authenticated;

-- Sweep: re-assert SELECT-only on the other client-facing views.
REVOKE ALL ON public.deliveries FROM public, anon, authenticated;
GRANT SELECT ON public.deliveries TO authenticated;

REVOKE ALL ON public.driver_directory FROM public, anon, authenticated;
GRANT SELECT ON public.driver_directory TO authenticated;

-- Systemic: objects created by postgres no longer default-grant writes.
-- anon gets nothing by default (its reads go through curated views);
-- authenticated keeps SELECT (RLS-gated reads) but not writes.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM authenticated;

NOTIFY pgrst, 'reload schema';
