-- =============================================================
-- 126_unified_admin_promotion_and_app_notifications.sql
-- 1. Unify member-to-admin promotion (role + user_type + admin_management +
--    optional admin_profiles / admins / admin_users sync + region + permissions).
-- 2. Ensure admin_broadcast_notification always records target_app in data JSONB.
-- =============================================================

BEGIN;

-- ─── 1. Ensure public.users has region_id and widened role/user_type checks ─

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES public.regions(id) ON DELETE SET NULL;

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_user_type_check;
ALTER TABLE public.users ADD CONSTRAINT users_user_type_check
  CHECK (user_type IN (
    'customer', 'merchant', 'driver', 'provider', 'delivery',
    'admin', 'owner', 'super_admin',
    'country_admin', 'governorate_admin', 'center_admin', 'village_admin'
  ));

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN (
    'customer', 'merchant', 'driver', 'provider', 'delivery',
    'admin', 'owner', 'super_admin',
    'country_admin', 'governorate_admin', 'center_admin', 'village_admin'
  ));

-- ─── 2. Expand permission vocabulary to include unified 11 platform codes ───

CREATE OR REPLACE FUNCTION public._valid_permission(p_permission text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_permission IN (
    'ADMIN_CREATE', 'ADMIN_ASSIGN', 'ADMIN_ROLE_ASSIGN', 'ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN', 'ADMIN_SUSPEND',
    'MEMBER_VIEW', 'MEMBER_VIEW_LOCATION', 'MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS', 'MEMBER_VIEW_TIMELINE', 'MEMBER_VIEW_DOCUMENTS',
    'MEMBER_MODERATE', 'MEMBER_WARN', 'MEMBER_RESTRICT', 'MEMBER_SUSPEND',
    'MEMBER_BAN', 'MEMBER_DELETE',
    'EMERGENCY_VIEW', 'EMERGENCY_AUDIO',
    'OFFER_CREATE', 'OFFER_REVIEW', 'OFFER_APPROVE', 'OFFER_PUBLISH',
    'PLATFORM_REVENUE',
    'FINANCIAL_VIEW', 'FINANCIAL_SETTLEMENT_APPROVE', 'FINANCIAL_TOPUP_APPROVE',
    'FINANCIAL_WALLET_MANAGE', 'FINANCIAL_COLLECT',
    'ORDER_VIEW', 'ORDER_MANAGE', 'ORDER_DISPATCH', 'ORDER_CANCEL',
    'MERCHANT_VIEW', 'MERCHANT_APPROVE', 'MERCHANT_SUSPEND', 'MERCHANT_EDIT',
    'DRIVER_VIEW', 'DRIVER_APPROVE', 'DRIVER_VERIFY', 'DRIVER_SUSPEND',
    'ESCALATION_VIEW', 'ESCALATION_RESOLVE',
    'SETTINGS_VIEW', 'SETTINGS_EDIT',
    'AUDIT_LOG_VIEW', 'ANALYTICS_VIEW',
    -- Unified 11 granular platform permissions
    'USERS_VIEW', 'USERS_MODERATE',
    'ORDERS_VIEW', 'ORDERS_MANAGE',
    'FINANCE_VIEW', 'FINANCE_APPROVE',
    'PROVIDERS_VERIFY', 'DISPUTES_RESOLVE',
    'CAMPAIGNS_MANAGE', 'ADMINS_MANAGE'
  );
$function$;

CREATE OR REPLACE FUNCTION public._is_active_admin_uid(p_uid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = p_uid
      AND (
        u.role = 'owner'
        OR (
          (
            u.role IN (
              'admin', 'super_admin',
              'country_admin', 'governorate_admin', 'center_admin', 'village_admin'
            )
            OR u.user_type = 'admin'
          )
          AND EXISTS (
            SELECT 1 FROM public.admin_management m
            WHERE m.admin_id = u.id AND m.is_active
          )
        )
      )
  );
END;
$$;

-- ─── 3. Unified assign_admin_role(p_email, p_role, p_reason) ───────────────

CREATE OR REPLACE FUNCTION public.assign_admin_role(
  p_email text,
  p_role text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_uid uuid;
  v_target_role text;
  v_user_type text;
  v_supervisor uuid;
  v_full_name text;
  v_user_email text;
BEGIN
  IF NOT (public.is_admin() OR public._is_owner_uid(v_actor)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_role NOT IN (
    'admin', 'super_admin',
    'country_admin', 'governorate_admin', 'center_admin', 'village_admin',
    'customer', 'driver', 'merchant', 'provider', 'delivery'
  ) THEN
    RAISE EXCEPTION 'Invalid role: %', p_role;
  END IF;

  SELECT id, role, full_name, email
    INTO v_uid, v_target_role, v_full_name, v_user_email
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email))
      OR id::text = btrim(p_email)
      OR phone = btrim(p_email)
   LIMIT 1;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF v_target_role = 'owner' THEN
    RAISE EXCEPTION 'Cannot change the owner role';
  END IF;

  v_user_type := CASE
    WHEN p_role IN ('customer', 'driver', 'merchant', 'provider') THEN p_role
    WHEN p_role = 'delivery' THEN 'delivery'
    ELSE 'admin'
  END;

  UPDATE public.users
     SET role = p_role,
         user_type = v_user_type,
         updated_at = now()
   WHERE id = v_uid;

  IF v_user_type = 'admin' THEN
    v_supervisor := CASE
      WHEN v_actor IS NOT NULL AND v_actor <> v_uid THEN v_actor
      ELSE (SELECT id FROM public.users WHERE role = 'owner' AND id <> v_uid LIMIT 1)
    END;

    IF v_supervisor IS NOT NULL THEN
      INSERT INTO public.admin_management (
        admin_id, supervisor_id, is_active, created_by, updated_at
      ) VALUES (
        v_uid, v_supervisor, true, v_actor, now()
      )
      ON CONFLICT (admin_id) DO UPDATE
        SET is_active = true,
            updated_at = now();
    END IF;

    IF to_regclass('public.admin_profiles') IS NOT NULL THEN
      BEGIN
        EXECUTE
          'INSERT INTO public.admin_profiles (user_id, role, is_active, updated_at)
           VALUES ($1, $2, true, now())
           ON CONFLICT (user_id) DO UPDATE
             SET role = EXCLUDED.role, is_active = true, updated_at = now()'
          USING v_uid, p_role;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;

    IF to_regclass('public.admins') IS NOT NULL THEN
      BEGIN
        EXECUTE
          'INSERT INTO public.admins (user_id, role, is_active, updated_at)
           VALUES ($1, $2, true, now())
           ON CONFLICT (user_id) DO UPDATE
             SET role = EXCLUDED.role, is_active = true, updated_at = now()'
          USING v_uid, p_role;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;

    IF to_regclass('public.admin_users') IS NOT NULL THEN
      BEGIN
        UPDATE public.admin_users
           SET is_active = true,
               updated_at = now()
         WHERE user_id = v_uid
            OR (v_user_email IS NOT NULL AND lower(email) = lower(v_user_email));
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  ELSE
    DELETE FROM public.admin_management WHERE admin_id = v_uid;
    DELETE FROM public.admin_permission_grants WHERE admin_id = v_uid;
    DELETE FROM public.admin_region_assignments WHERE admin_id = v_uid;

    IF to_regclass('public.admin_profiles') IS NOT NULL THEN
      BEGIN
        EXECUTE 'UPDATE public.admin_profiles SET is_active = false WHERE user_id = $1'
          USING v_uid;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;

    IF to_regclass('public.admins') IS NOT NULL THEN
      BEGIN
        EXECUTE 'UPDATE public.admins SET is_active = false WHERE user_id = $1'
          USING v_uid;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  END IF;

  PERFORM public.write_audit(
    'ADMIN_ROLE_CHANGED',
    'admin_management',
    v_uid::text,
    jsonb_build_object(
      'actor', COALESCE(v_actor::text, ''),
      'new_role', p_role,
      'user_type', v_user_type,
      'reason', COALESCE(p_reason, 'Assigned from Member Operations Center')
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.assign_admin_role(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_admin_role(text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assign_admin_role(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_admin_role(text, text, text) TO service_role;

-- ─── 4. Allow grant_admin_permission on any active promoted admin role ─────

CREATE OR REPLACE FUNCTION public.grant_admin_permission(
  p_admin_id uuid,
  p_permission text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (public._is_owner_uid(auth.uid()) OR public._is_active_admin_uid(auth.uid())) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF NOT public._valid_permission(p_permission) THEN
    RAISE EXCEPTION 'Unknown permission';
  END IF;
  IF p_admin_id = auth.uid() AND NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Cannot grant a permission to yourself';
  END IF;
  IF NOT public._is_owner_uid(auth.uid()) THEN
    IF NOT public.has_permission(p_permission) THEN
      RAISE EXCEPTION 'You do not hold this permission';
    END IF;
    IF NOT public.is_supervisor_of(auth.uid(), p_admin_id) THEN
      RAISE EXCEPTION 'Not authorized for this admin';
    END IF;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_management m
    JOIN public.users u ON u.id = m.admin_id
    WHERE m.admin_id = p_admin_id
      AND m.is_active
      AND (
        u.role IN (
          'admin', 'super_admin',
          'country_admin', 'governorate_admin', 'center_admin', 'village_admin'
        )
        OR u.user_type = 'admin'
      )
  ) THEN
    RAISE EXCEPTION 'Not an active admin';
  END IF;

  INSERT INTO public.admin_permission_grants (admin_id, permission, granted_by)
  VALUES (p_admin_id, p_permission, auth.uid())
  ON CONFLICT (admin_id, permission) DO NOTHING;

  PERFORM public.write_audit(
    'ADMIN_PERMISSION_GRANTED', 'admin_permission_grants', p_admin_id::text,
    jsonb_build_object('permission', p_permission)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.grant_admin_permission(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.grant_admin_permission(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.grant_admin_permission(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_admin_permission(uuid, text) TO service_role;

-- ─── 5. Sync region assignments with users.region_id & preferences ─────────

CREATE OR REPLACE FUNCTION public.admin_assign_region_by_id(
  p_email text,
  p_region_id uuid,
  p_scope text DEFAULT 'descendants'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_id uuid;
  v_region_name text;
BEGIN
  IF NOT (public.is_admin() OR public._is_owner_uid(auth.uid())) THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  IF p_scope NOT IN ('self', 'descendants') THEN
    RAISE EXCEPTION 'INVALID_SCOPE';
  END IF;

  SELECT id INTO v_admin_id
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email))
      OR id::text = btrim(p_email)
      OR phone = btrim(p_email)
   LIMIT 1;

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'ADMIN_NOT_FOUND';
  END IF;

  SELECT COALESCE(name_ar, name_en) INTO v_region_name
    FROM public.regions
   WHERE id = p_region_id;

  IF v_region_name IS NULL THEN
    RAISE EXCEPTION 'REGION_NOT_FOUND';
  END IF;

  INSERT INTO public.admin_region_assignments (
    admin_id, region_id, scope, created_by
  ) VALUES (
    v_admin_id, p_region_id, p_scope, auth.uid()
  )
  ON CONFLICT (admin_id, region_id) DO UPDATE
    SET scope = EXCLUDED.scope,
        created_by = EXCLUDED.created_by;

  UPDATE public.users
     SET region_id = p_region_id,
         updated_at = now()
   WHERE id = v_admin_id;

  INSERT INTO public.user_region_preferences (
    user_id, region_id, source, updated_at
  ) VALUES (
    v_admin_id, p_region_id, 'verified', now()
  )
  ON CONFLICT (user_id) DO UPDATE
    SET region_id = EXCLUDED.region_id,
        source = 'verified',
        updated_at = now();

  IF to_regclass('public.admin_users') IS NOT NULL THEN
    BEGIN
      UPDATE public.admin_users
         SET region_id = p_region_id,
             region_name = v_region_name,
             updated_at = now()
       WHERE user_id = v_admin_id OR lower(email) = lower(btrim(p_email));
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) TO service_role;

-- ─── 6. All-in-one admin_promote_and_configure_member RPC ──────────────────

CREATE OR REPLACE FUNCTION public.admin_promote_and_configure_member(
  p_member_id uuid,
  p_role text,
  p_region_id uuid DEFAULT NULL,
  p_permissions text[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_perm text;
BEGIN
  IF NOT (public.is_admin() OR public._is_owner_uid(auth.uid())) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  PERFORM public.assign_admin_role(p_member_id::text, p_role, 'Configured from Member Operations Center');

  IF p_region_id IS NOT NULL AND p_role NOT IN ('customer', 'driver', 'merchant', 'provider', 'delivery') THEN
    PERFORM public.admin_assign_region_by_id(p_member_id::text, p_region_id, 'descendants');
  END IF;

  IF p_permissions IS NOT NULL AND p_role NOT IN ('customer', 'driver', 'merchant', 'provider', 'delivery') THEN
    DELETE FROM public.admin_permission_grants
     WHERE admin_id = p_member_id
       AND NOT (permission = ANY(p_permissions));

    FOREACH v_perm IN ARRAY p_permissions LOOP
      IF public._valid_permission(v_perm) THEN
        INSERT INTO public.admin_permission_grants (admin_id, permission, granted_by)
        VALUES (p_member_id, v_perm, auth.uid())
        ON CONFLICT (admin_id, permission) DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'member_id', p_member_id,
    'role', p_role,
    'region_id', p_region_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_promote_and_configure_member(uuid, text, uuid, text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_promote_and_configure_member(uuid, text, uuid, text[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_promote_and_configure_member(uuid, text, uuid, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_promote_and_configure_member(uuid, text, uuid, text[]) TO service_role;

-- ─── 7. Update admin_broadcast_notification (both overloads) ───────────────

CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
  p_title text,
  p_body text,
  p_target_role text DEFAULT NULL,
  p_type text DEFAULT 'system',
  p_deep_link text DEFAULT NULL,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_inserted_count integer := 0;
  v_device_count integer := 0;
  v_target_app text := COALESCE(NULLIF(btrim(p_target_role), ''), 'all');
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = v_caller_id
      AND (
        u.user_type IN ('admin', 'owner', 'super_admin')
        OR u.role IN (
          'admin', 'owner', 'super_admin',
          'country_admin', 'governorate_admin', 'center_admin', 'village_admin'
        )
      )
  ) OR public.is_admin() INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin privileges required';
  END IF;

  PERFORM set_config('app.notify_dispatch', 'true', true);

  WITH target_users AS (
    SELECT u.id
    FROM public.users u
    WHERE COALESCE(u.is_active, true) = true
      AND (
        p_target_role IS NULL
        OR btrim(p_target_role) = ''
        OR p_target_role = 'all'
        OR u.user_type = p_target_role
        OR u.role = p_target_role
      )
  ),
  inserted AS (
    INSERT INTO public.notifications (
      user_id,
      title,
      body,
      type,
      deep_link,
      data,
      sender_id,
      send_push
    )
    SELECT
      tu.id,
      p_title,
      p_body,
      COALESCE(NULLIF(p_type, ''), 'system'),
      p_deep_link,
      COALESCE(p_data, '{}'::jsonb) || jsonb_build_object(
        'target_app', COALESCE(NULLIF(p_target_role, ''), 'all')
      ),
      v_caller_id,
      true
    FROM target_users tu
    RETURNING user_id
  )
  SELECT
    COUNT(*),
    (
      SELECT COUNT(*)
      FROM public.notification_tokens nt
      WHERE nt.user_id IN (SELECT user_id FROM inserted)
        AND nt.is_active = true
    )
  INTO v_inserted_count, v_device_count
  FROM inserted;

  RETURN jsonb_build_object(
    'sent_count', v_inserted_count,
    'device_count', v_device_count,
    'target_app', v_target_app
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
  p_title text,
  p_body text,
  p_type text DEFAULT 'info',
  p_deep_link text DEFAULT NULL,
  p_target_role text DEFAULT NULL,
  p_target_user_id uuid DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  matched_ids uuid[];
  device_count integer;
  v_payload jsonb;
BEGIN
  IF NOT (public.is_admin() OR public._is_owner_uid(auth.uid())) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT array_agg(u.id) INTO matched_ids
  FROM public.users u
  WHERE (p_target_user_id IS NULL OR u.id = p_target_user_id)
    AND (
      p_target_role IS NULL
      OR btrim(p_target_role) = ''
      OR p_target_role = 'all'
      OR u.role = p_target_role
      OR u.user_type = p_target_role
    );

  v_payload := jsonb_strip_nulls(jsonb_build_object(
    'deep_link', p_deep_link,
    'target_app', COALESCE(NULLIF(p_target_role, ''), 'all')
  ));

  IF matched_ids IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, deep_link, data, is_read)
    SELECT
      unnest(matched_ids),
      p_title,
      p_body,
      COALESCE(NULLIF(p_type, ''), 'info'),
      p_deep_link,
      v_payload,
      false;
  END IF;

  SELECT COUNT(*) INTO device_count
  FROM public.notification_tokens t
  WHERE t.user_id = ANY(matched_ids)
    AND COALESCE(t.is_active, true) = true;

  RETURN COALESCE(device_count, 0);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, uuid) TO service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
