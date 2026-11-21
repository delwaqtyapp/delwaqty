-- 214: Security R3/R4 backlog.
-- R3: PostGIS catalog views carry write grants to anon (extension-managed but
-- the grants are real). Strip anon/authenticated writes, keep reads.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.geography_columns FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.geometry_columns FROM anon, authenticated;

-- R4: future functions created by postgres no longer default-grant EXECUTE to
-- PUBLIC (which anon/authenticated inherit). Migrations must grant explicitly.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

NOTIFY pgrst, 'reload schema';
