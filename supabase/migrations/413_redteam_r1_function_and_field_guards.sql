BEGIN;
-- 413: red team round 1 backlog — function authorization + sensitive-field guards.
--
-- 1) admin_effective_permissions(p_admin_id): was callable by any authenticated
--    user for ANY admin id, leaking role, permission grants and region
--    assignments. Now restricted to the subject themself or an active admin.
-- 2) is_admin(): the anon role held EXECUTE on the no-arg overload on staging
--    (is_admin(uid) had already been revoked in 032/051). anon needs neither
--    overload; revoked on both (idempotent).
-- 3) merchants_guard_sensitive_fields: settlement_model is now guarded for
--    direct client writes. Merchants keep self-service through the
--    SECURITY DEFINER merchant_set_settlement_model RPC; admins/owner keep
--    direct writes via the existing is_admin() exemption.
-- 4) users_guard_account_fields: also guards status, role_key, region_id,
--    email, refusal_count, rejection_reason. Verified against the Flutter
--    monorepo: no client flow writes these columns directly (region preference
--    lives in user_region_preferences; all writers are SECURITY DEFINER RPCs).
-- 5) drivers_guard_sensitive_fields: also guards onboarding_completed,
--    onboarding_step, is_active. The captain app drives onboarding exclusively
--    through submit_driver_onboarding / complete_driver_onboarding (both
--    SECURITY DEFINER); the admin app's direct is_active toggle keeps working
--    through the existing is_admin() exemption.
-- 6) products.is_featured: NOT guarded here. The merchant app's product form
--    (merchant_product_form_page.dart) exposes a merchant-facing "featured"
--    toggle that writes products.is_featured directly, so merchants
--    legitimately use the column today. Guarding it belongs with the app
--    change that removes that toggle.

-- (1) admin_effective_permissions: self or active admin only -------------------
CREATE OR REPLACE FUNCTION public.admin_effective_permissions(p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS DISTINCT FROM p_admin_id AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin_effective_permissions is restricted to the subject or an active admin';
  END IF;
  RETURN jsonb_build_object(
    'role', (SELECT role_key FROM users WHERE id = p_admin_id),
    'role_permissions',
      (SELECT COALESCE(r.default_permissions, '[]'::jsonb)
         FROM public.admin_roles r WHERE r.role_key = (SELECT role_key FROM users WHERE id = p_admin_id)),
    'granted',
      (SELECT COALESCE(jsonb_agg(DISTINCT permission), '[]'::jsonb)
         FROM public.admin_permission_grants WHERE admin_id = p_admin_id),
    'regions',
      (SELECT COALESCE(jsonb_agg(DISTINCT region_id), '[]'::jsonb)
         FROM public.admin_region_assignments WHERE admin_id = p_admin_id)
  );
END;
$function$;

-- (2) Keep zero-argument caller predicate available to anon RLS evaluation.
-- It is false for anon and cannot disclose arbitrary identities. Only the
-- supplied-identity overload loses anon access, matching the review scope.
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;
REVOKE EXECUTE ON FUNCTION public.is_admin(uid uuid) FROM anon;

-- (3) merchants: guard settlement_model against direct client writes ----------
CREATE OR REPLACE FUNCTION public.merchants_guard_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    if NEW.owner_user_id is distinct from OLD.owner_user_id then
      raise exception 'owner_user_id is immutable';
    end if;
    if NEW.status is distinct from OLD.status then
      raise exception 'status is managed by the admin RPCs';
    end if;
    if NEW.rating is distinct from OLD.rating then
      raise exception 'rating is managed by the rating engine';
    end if;
    if NEW.total_reviews is distinct from OLD.total_reviews then
      raise exception 'total_reviews is managed by the rating engine';
    end if;
    if NEW.total_orders is distinct from OLD.total_orders then
      raise exception 'total_orders is managed by the order engine';
    end if;
    if NEW.delivery_fee is distinct from OLD.delivery_fee then
      raise exception 'delivery_fee is managed by the admin RPCs';
    end if;
    if NEW.min_order is distinct from OLD.min_order then
      raise exception 'min_order is managed by the admin RPCs';
    end if;
    if NEW.is_featured is distinct from OLD.is_featured then
      raise exception 'is_featured is managed by the admin RPCs';
    end if;
    if NEW.settlement_model is distinct from OLD.settlement_model then
      raise exception 'settlement_model is managed by the merchant_set_settlement_model RPC';
    end if;
  end if;
  return NEW;
end;
$function$;

-- (4) users: guard status, role_key, region_id, email, refusal_count,
--     rejection_reason against direct client writes ---------------------------
CREATE OR REPLACE FUNCTION public.users_guard_account_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    return NEW;
  end if;
  if current_user in ('authenticated', 'anon') then
    if NEW.role is distinct from OLD.role then
      raise exception 'Role is managed by the admin lifecycle RPCs';
    end if;
    if NEW.account_status is distinct from OLD.account_status then
      raise exception 'Account status is managed by the moderation RPCs';
    end if;
    if NEW.date_of_birth is distinct from OLD.date_of_birth then
      raise exception 'Date of birth must be updated via update_member_dob';
    end if;
    if NEW.anonymized_at is distinct from OLD.anonymized_at then
      raise exception 'Anonymization is managed by the member deletion RPC';
    end if;
    if NEW.verification_status is distinct from OLD.verification_status then
      raise exception 'Verification status is managed by the verification RPCs';
    end if;
    if NEW.user_type is distinct from OLD.user_type then
      raise exception 'User type is managed by the account lifecycle RPCs';
    end if;
    if NEW.phone is distinct from OLD.phone then
      raise exception 'Phone number is managed by the WhatsApp-verified claim_phone_change RPC';
    end if;
    if NEW.status is distinct from OLD.status then
      raise exception 'Status flag is managed by the account lifecycle RPCs';
    end if;
    if NEW.role_key is distinct from OLD.role_key then
      raise exception 'Role key is managed by the admin role RPCs';
    end if;
    if NEW.region_id is distinct from OLD.region_id then
      raise exception 'Region assignment is managed by the admin region RPCs';
    end if;
    if NEW.email is distinct from OLD.email then
      raise exception 'Email is managed by the account lifecycle RPCs';
    end if;
    if NEW.refusal_count is distinct from OLD.refusal_count then
      raise exception 'Refusal count is managed by the refusal RPCs';
    end if;
    if NEW.rejection_reason is distinct from OLD.rejection_reason then
      raise exception 'Rejection reason is managed by the verification RPCs';
    end if;
  end if;
  return NEW;
end;
$function$;

-- (5) drivers: guard onboarding_completed, onboarding_step, is_active ---------
CREATE OR REPLACE FUNCTION public.drivers_guard_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user IN ('authenticated', 'anon') AND NOT public.is_admin() THEN
    IF NEW.earnings_balance IS DISTINCT FROM OLD.earnings_balance THEN
      RAISE EXCEPTION 'earnings_balance is managed by the earnings RPCs';
    END IF;
    IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
      RAISE EXCEPTION 'is_verified is managed by the admin verification RPCs';
    END IF;
    IF NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
      RAISE EXCEPTION 'verification_status is managed by the admin verification RPCs';
    END IF;
    IF NEW.background_check_status IS DISTINCT FROM OLD.background_check_status THEN
      RAISE EXCEPTION 'background_check_status is managed by the admin RPCs';
    END IF;
    IF NEW.rating IS DISTINCT FROM OLD.rating THEN
      RAISE EXCEPTION 'rating is managed by the rating engine';
    END IF;
    IF NEW.total_deliveries IS DISTINCT FROM OLD.total_deliveries THEN
      RAISE EXCEPTION 'total_deliveries is managed by the delivery engine';
    END IF;
    IF NEW.total_trips IS DISTINCT FROM OLD.total_trips THEN
      RAISE EXCEPTION 'total_trips is managed by the trip engine';
    END IF;
    IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'user_id is immutable';
    END IF;
    IF NEW.active_vehicle_id IS DISTINCT FROM OLD.active_vehicle_id THEN
      RAISE EXCEPTION 'active_vehicle_id is managed by the vehicle RPCs';
    END IF;
    IF NEW.national_id_number IS DISTINCT FROM OLD.national_id_number THEN
      RAISE EXCEPTION 'national_id_number is managed by the onboarding RPCs';
    END IF;
    IF NEW.onboarding_completed IS DISTINCT FROM OLD.onboarding_completed THEN
      RAISE EXCEPTION 'onboarding_completed is managed by the onboarding RPCs';
    END IF;
    IF NEW.onboarding_step IS DISTINCT FROM OLD.onboarding_step THEN
      RAISE EXCEPTION 'onboarding_step is managed by the onboarding RPCs';
    END IF;
    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      RAISE EXCEPTION 'is_active is managed by the account lifecycle RPCs';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

COMMIT;
