-- 368: close the zero-target campaign hole in campaign_targets_authorized.
-- On a campaign with no rows in campaign_targets, NOT EXISTS is vacuously
-- true, so 367 still let any active admin (including unassigned and
-- village/center admins) manage it. Campaigns carry no region column, so a
-- zero-target campaign now requires country-admin/owner scope. Campaigns
-- with targets keep per-target region coverage.
BEGIN;

CREATE OR REPLACE FUNCTION public.campaign_targets_authorized(p_campaign_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (public._is_owner_uid(auth.uid()) OR public._is_active_admin_uid(auth.uid()))
    AND (
      (
        NOT EXISTS (
          SELECT 1 FROM public.campaign_targets t
          WHERE t.campaign_id = p_campaign_id
        )
        AND public._is_country_admin_uid(auth.uid())
      )
      OR (
        EXISTS (
          SELECT 1 FROM public.campaign_targets t
          WHERE t.campaign_id = p_campaign_id
        )
        AND NOT EXISTS (
          SELECT 1 FROM public.campaign_targets t
          WHERE t.campaign_id = p_campaign_id
            AND NOT public.campaign_can_target_region(t.region_id)
        )
      )
    );
$function$;

COMMIT;
