-- 373: expose the caller's admin region footprint for UI gating.
-- Owner/country admins are unrestricted. Region-scoped admins get their
-- assigned roots plus every region those roots cover (scope 'self' = the
-- region itself, 'descendants' = the whole subtree). Everyone else gets an
-- empty, restricted result. Read-only; used by the admin web to limit the
-- Command Center governorate selector and /admin/regions controls.

CREATE OR REPLACE FUNCTION public.admin_my_scope_region_ids()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_root_ids uuid[];
  v_ids uuid[];
BEGIN
  IF v_uid IS NULL OR NOT public._is_active_admin_uid(v_uid) THEN
    RETURN jsonb_build_object(
      'unrestricted', false,
      'root_ids', '[]'::jsonb,
      'region_ids', '[]'::jsonb);
  END IF;

  IF public._is_owner_uid(v_uid) OR public._is_country_admin_uid(v_uid) THEN
    RETURN jsonb_build_object(
      'unrestricted', true,
      'root_ids', '[]'::jsonb,
      'region_ids', '[]'::jsonb);
  END IF;

  SELECT coalesce(array_agg(a.region_id), '{}')
    INTO v_root_ids
    FROM public.admin_region_assignments a
   WHERE a.admin_id = v_uid;

  WITH RECURSIVE covered AS (
    SELECT r.id, a.scope
      FROM public.regions r
      JOIN public.admin_region_assignments a
        ON a.admin_id = v_uid AND a.region_id = r.id
    UNION ALL
    SELECT r.id, c.scope
      FROM public.regions r
      JOIN covered c
        ON r.parent_region_id = c.id AND c.scope = 'descendants'
  )
  SELECT coalesce(array_agg(DISTINCT id), '{}') INTO v_ids FROM covered;

  RETURN jsonb_build_object(
    'unrestricted', false,
    'root_ids', coalesce((SELECT jsonb_agg(x) FROM (SELECT unnest(v_root_ids) AS x) t), '[]'::jsonb),
    'region_ids', coalesce((SELECT jsonb_agg(x) FROM (SELECT unnest(v_ids) AS x) t), '[]'::jsonb));
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_my_scope_region_ids() TO authenticated;
