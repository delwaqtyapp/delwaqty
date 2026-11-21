-- 206: Security C1 - driver_directory was an auto-updatable postgres-owned view
-- with full write grants to anon/authenticated and no security_invoker, bypassing
-- drivers RLS entirely (anon PATCH returned 204). Lock to invoker-mode SELECT.

REVOKE ALL ON public.driver_directory FROM anon, authenticated;
GRANT SELECT ON public.driver_directory TO authenticated;
ALTER VIEW public.driver_directory SET (security_invoker = true);

-- deliveries view: keep invoker mode, trim write grants; anon reads nothing.
REVOKE ALL ON public.deliveries FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.deliveries FROM authenticated;
GRANT SELECT ON public.deliveries TO authenticated;

NOTIFY pgrst, 'reload schema';
