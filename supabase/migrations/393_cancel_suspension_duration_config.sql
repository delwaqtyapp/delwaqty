-- 393: Owner-controlled cancellation penalty (owner decision 2026-11-23).
--
-- The 3rd customer cancellation inside one Cairo calendar month still
-- executes, then suspends the account - but the suspension length is now a
-- platform setting (default 5 days) that ONLY the owner account can change,
-- with an audit trail. The customer-facing message now directs the customer
-- to contact in-app support to understand the repeated cancellations.
--
-- Scope notes:
-- * Monthly cancel counting (2 per Cairo month, 3rd executes) is unchanged.
-- * settlement_suspension_days is a different penalty and is NOT reused.
-- * report_delivery_refusal keeps its own hardcoded 5-day refusal
--   suspension; the owner decision covered repeated cancellations only.

-- 1) Config column on the singleton settings row.
ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS cancel_suspension_days integer NOT NULL DEFAULT 5;

ALTER TABLE public.platform_settings
  DROP CONSTRAINT IF EXISTS platform_settings_cancel_suspension_days_check;
ALTER TABLE public.platform_settings
  ADD CONSTRAINT platform_settings_cancel_suspension_days_check
  CHECK (cancel_suspension_days BETWEEN 1 AND 365);

COMMENT ON COLUMN public.platform_settings.cancel_suspension_days IS
  'Days a customer account is suspended after the 3rd cancellation in one Cairo calendar month. Owner-only (393).';

-- 2) Owner-only guard at the table level. platform_settings is writable by
-- any admin via RLS, so the trigger enforces the owner-only rule even for
-- direct table writes (defense in depth behind the RPC check).
CREATE OR REPLACE FUNCTION public.guard_platform_settings_owner_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    IF TG_OP = 'UPDATE' AND NEW.require_provider_documents IS DISTINCT FROM OLD.require_provider_documents THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change provider document requirements';
      END IF;
    ELSIF TG_OP = 'INSERT' AND NEW.require_provider_documents IS TRUE THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change provider document requirements';
      END IF;
    END IF;
    -- 393: cancellation suspension duration is owner-only.
    IF NEW.cancel_suspension_days IS DISTINCT FROM OLD.cancel_suspension_days THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change the cancellation suspension duration';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 3) Owner-only setter with audit.
CREATE OR REPLACE FUNCTION public.set_cancel_suspension_days(p_days integer, p_reason text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_old integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED';
  END IF;
  IF NOT public._is_owner_uid(v_uid) THEN
    RAISE EXCEPTION 'Only the platform owner can change the cancellation suspension duration';
  END IF;
  IF p_days IS NULL OR p_days < 1 OR p_days > 365 THEN
    RAISE EXCEPTION 'Suspension duration must be between 1 and 365 days';
  END IF;

  SELECT cancel_suspension_days INTO v_old
  FROM public.platform_settings
  WHERE id = 'default'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Platform settings row missing';
  END IF;

  UPDATE public.platform_settings
  SET cancel_suspension_days = p_days,
      updated_at = now()
  WHERE id = 'default';

  PERFORM public.write_audit(
    'PENALTY_CONFIG_CHANGED', 'platform_settings', 'default',
    jsonb_build_object('field', 'cancel_suspension_days',
                       'old_value', v_old,
                       'new_value', p_days,
                       'reason', p_reason));

  RETURN p_days;
END;
$function$;

REVOKE ALL ON FUNCTION public.set_cancel_suspension_days(integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_cancel_suspension_days(integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_cancel_suspension_days(integer, text) TO postgres;
GRANT EXECUTE ON FUNCTION public.set_cancel_suspension_days(integer, text) TO service_role;

-- 4) cancel_order reads the configured duration and points the customer to
-- support. Identical to the 361 definition except:
--   * stale "UTC" comment corrected (the boundary is the Cairo month, kept),
--   * the hardcoded 5-day suspension reads platform_settings instead,
--   * the suspension push carries the configured length and tells the
--     customer to contact in-app support about the repeated cancellations,
--     deep-linking to /support.
CREATE OR REPLACE FUNCTION public.cancel_order(p_order_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.orders%rowtype;
  v_uid uuid := auth.uid();
  v_suspend_after boolean := false;
  v_refunded boolean := false;
  v_actor uuid;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_short text;
  v_suspension_days integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  end if;

  if v_order.user_id is distinct from v_uid and not public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;

  if v_order.status in ('delivered', 'cancelled') then
    return jsonb_build_object('ok', false, 'code', 'NOT_CANCELLABLE', 'status', v_order.status);
  end if;

  -- Customer self-cancel policy (owner-confirmed 2026-11-21, mig 185):
  -- no solo-cancel once the order is out for delivery, and a MONTHLY
  -- allowance of 2 customer cancels (Cairo calendar month; further cancels
  -- go through merchant/support).
  if v_uid = v_order.user_id and not public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) then
    if v_order.status = 'delivering' then
      return jsonb_build_object('ok', false, 'code', 'OUT_FOR_DELIVERY', 'status', v_order.status);
    end if;
    -- 188: the 3rd monthly cancel EXECUTES and triggers a suspension
    -- (length configurable by the owner since 393); it is not blocked.
    if (select count(*) from public.orders
         where user_id = v_uid and cancelled_by = 'customer'
           and cancelled_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') >= 2 then
      v_suspend_after := true;
    end if;
  end if;

  -- 194: shared finalizer owns stock/coupon/refund/order+ride cancellation.
  v_refunded := v_order.payment_status = 'paid';
  perform public._finalize_order_cancel(
    p_order_id,
    case when v_uid = v_order.user_id then 'customer' else 'admin' end,
    coalesce(p_reason, v_order.cancelled_reason, 'Order cancelled'),
    true, true, true,
    case when v_uid is distinct from v_order.user_id then 'system' else 'rider' end);

  -- Notify the assigned driver: stop heading to pickup.
  if v_order.driver_id is not null then
    select user_id into v_driver_uid from public.drivers where id = v_order.driver_id;
    if v_driver_uid is not null then
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_driver_uid,
              'تم إلغاء الطلب',
              'ألغى العميل الطلب. لا تتوجه للاستلام.',
              'order',
              jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                                 'reason', p_reason),
              true);
    end if;
  end if;

  -- Notify the merchant owner.
  if v_order.merchant_id is not null then
    select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
    if v_merchant_uid is not null then
      v_short := right(v_order.id::text, 6);
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_merchant_uid,
              'تم إلغاء طلب',
              'ألغى العميل الطلب رقم ' || v_short || '.',
              'order',
              jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                                 'reason', p_reason),
              true);
    end if;
  end if;

  -- 188/393: suspension after the 3rd monthly cancel. The duration comes
  -- from platform_settings.cancel_suspension_days (owner-only, default 5);
  -- the moderation engine owns account_status. The message routes the
  -- customer to in-app support to understand the repeated cancellations.
  if v_suspend_after then
    v_actor := coalesce(
      (select id from public.users where role = 'owner' order by created_at limit 1),
      v_order.user_id);
    v_suspension_days := coalesce(
      (select ps.cancel_suspension_days
         from public.platform_settings ps
        where ps.id = 'default'),
      5);
    perform public._member_exec_sanction(
      v_actor, v_order.user_id, 'suspension',
      'تجاوز سماحية الإلغاء الشهرية (إلغاء ثالث خلال شهر واحد)', v_suspension_days);
    insert into public.notifications (user_id, title, body, type, data, deep_link, send_push)
    values (v_order.user_id,
            'تم إيقاف حسابك ' || v_suspension_days || ' يوم',
            'تم تنفيذ إلغاء الطلب، لكن ده ثالث إلغاء ليك هذا الشهر (السماحية: 2). اتوقف حسابك ' || v_suspension_days || ' يوم. تواصل مع الدعم من التطبيق عشان تفهم سبب تكرار الإلغاء وإزاي تتجنب الإيقاف مرة تانية.',
            'account',
            jsonb_build_object('event', 'cancel_suspension', 'order_id', v_order.id,
                               'duration_days', v_suspension_days),
            '/support',
            true);
    return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled',
                              'refunded', v_refunded, 'suspended', true,
                              'suspension_days', v_suspension_days);
  end if;

  return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled', 'refunded', v_refunded);
end;
$function$;
