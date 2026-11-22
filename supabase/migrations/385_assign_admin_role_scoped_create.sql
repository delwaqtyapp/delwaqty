-- 385: assign_admin_role scoped create fix (review #35 residual)
-- Non-owner country admins were rejected when assigning an admin role:
-- _admin_exec_create was called with p_supervisor_id NULL, and its
-- "only the owner creates admins at root level" guard fired.
-- The new admin is now placed under the actor (supervisor = actor),
-- which is identical to the previous outcome for the owner
-- (COALESCE(NULL, actor) = actor) and the correct branch placement
-- for scoped country admins.
CREATE OR REPLACE FUNCTION public.assign_admin_role(p_email text, p_role text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_user_type text;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_role NOT IN (
    'admin', 'super_admin',
    'country_admin', 'governorate_admin', 'center_admin', 'village_admin',
    'customer', 'driver', 'merchant', 'provider', 'delivery'
  ) THEN
    RAISE EXCEPTION 'Invalid role: %', p_role;
  END IF;

  -- #35: 126 lookup contract - email, member uuid (member drawer fallback),
  -- or phone.
  SELECT id INTO v_uid
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email))
      OR id::text = btrim(p_email)
      OR phone = btrim(p_email)
   LIMIT 1;
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  v_user_type := CASE
    WHEN p_role IN ('customer', 'driver', 'merchant', 'provider', 'delivery') THEN p_role
    ELSE 'admin'
  END;

  IF v_user_type = 'admin' THEN
    -- Admin-scope role names map onto the tree model: users.role stays
    -- 'admin', scope comes from the tree row + region assignments.
    IF EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = v_uid) THEN
      PERFORM public._admin_exec_role(auth.uid(), v_uid, 'admin', COALESCE(p_reason, 'Role updated'));
    ELSE
      PERFORM public._admin_exec_create(auth.uid(), v_uid, auth.uid(), NULL, 'descendants');
    END IF;
  ELSE
    -- Demotion to a member role: _admin_exec_role removes the tree row,
    -- guards the owner, and audits.
    PERFORM public._admin_exec_role(auth.uid(), v_uid, p_role, COALESCE(p_reason, 'Role updated'));
  END IF;

  UPDATE public.users SET user_type = v_user_type WHERE id = v_uid;
END;
$function$;
