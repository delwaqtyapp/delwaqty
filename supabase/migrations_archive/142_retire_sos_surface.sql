-- SOS was not a real emergency-service workflow. Preserve historical rows
-- and ordinary support; retire its RPCs and stop client insertion.
BEGIN;
DROP FUNCTION IF EXISTS public.trigger_sos_alert(uuid,double precision,double precision,text,text);
DROP FUNCTION IF EXISTS public.admin_list_sos_alerts(text);
DROP FUNCTION IF EXISTS public.admin_resolve_sos_alert(uuid,text,text);
REVOKE INSERT,UPDATE,DELETE ON public.sos_alerts FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
