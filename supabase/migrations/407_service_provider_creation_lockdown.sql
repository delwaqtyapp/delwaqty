-- #108: provider identities are created by the approval/provisioning flow,
-- never by a client INSERT. No existing provider data is changed.
BEGIN;

DROP POLICY IF EXISTS service_providers_manage_own ON public.service_providers;
CREATE POLICY service_providers_select_own ON public.service_providers
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Retain the existing owner UPDATE and region-scoped admin policies.
-- Clients, including admins, use decide_provider_profile_request for creation.
-- Its SECURITY DEFINER provisioning helper retains the owner's table access.
REVOKE INSERT ON TABLE public.service_providers FROM PUBLIC, anon, authenticated;

-- Defense in depth: this must remain SECURITY INVOKER. A definer trigger
-- would see its owner instead of the role performing a direct table write.
CREATE OR REPLACE FUNCTION public.service_providers_guard_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF TG_OP = 'INSERT' THEN
      RAISE EXCEPTION 'provider_creation_requires_approval' USING ERRCODE = '42501';
    ELSIF NOT public._admin_write_scope(
        public._point_region_id(OLD.latitude, OLD.longitude)) THEN
      RAISE EXCEPTION 'provider_deletion_requires_scoped_admin' USING ERRCODE = '42501';
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.service_providers_guard_lifecycle() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_service_provider_guard_lifecycle ON public.service_providers;
CREATE TRIGGER trg_service_provider_guard_lifecycle
  BEFORE INSERT OR DELETE ON public.service_providers
  FOR EACH ROW EXECUTE FUNCTION public.service_providers_guard_lifecycle();

COMMIT;
