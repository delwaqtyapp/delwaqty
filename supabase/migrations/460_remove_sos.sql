-- 460: remove the SOS feature (owner decision 2026-11-27: delivery and services app, no ride safety flow).
-- No client ever triggered it; prod sos_alerts and member_events SOS rows are empty.
-- Drops: sos_alerts table (and its policies and trigger), notify_sos_alert(), open_emergency_chat(),
-- resolve_sos_alert(). Redefines the four functions that read sos_alerts, each copied from the live
-- prod definition with only the SOS lines removed: delete_user_data, platform_kpi_summary
-- (no sos_active key), platform_operational_alerts (no active_sos alert), get_member_profile
-- (no emergency block; access.emergency flag kept). member_events event_type values and the
-- EMERGENCY_VIEW permission are left as they are (harmless, 0 rows).
-- Re-runnable.

CREATE OR REPLACE FUNCTION public.delete_user_data(p_uid uuid, p_reason text DEFAULT 'user_requested'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_room_ids uuid[];
  v_driver_ids uuid[];
  v_merchant_ids uuid[];
BEGIN
  IF p_uid IS NULL THEN
    RAISE EXCEPTION 'User id is required';
  END IF;
  IF public._is_active_admin_uid(p_uid) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_uid) THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  -- 1. Conversations: every room the user participates in goes (messages,
  --    typing and escalations cascade from the room). Attachments are
  --    purged by the edge function through the Storage API first. Any
  --    message the user sent in another room goes too.
  SELECT array_agg(id) INTO v_room_ids
  FROM public.chat_rooms
  WHERE participant_ids @> ARRAY[p_uid]::uuid[];
  IF v_room_ids IS NOT NULL THEN
    DELETE FROM public.chat_rooms WHERE id = ANY (v_room_ids);
  END IF;
  DELETE FROM public.chat_messages WHERE sender_id = p_uid;

  -- 2. Audio recording rows (objects purged via Storage API first).
  DELETE FROM public.service_audio_logs WHERE user_id = p_uid;

  -- 3. Personal document rows (objects purged via Storage API first; the
  --    users-row URL columns are nulled by the engine below).
  DELETE FROM public.provider_documents WHERE provider_id = p_uid;
  DELETE FROM public.verification_attempts WHERE user_id = p_uid;

  -- 4. Wallet top-up proof references (the financial rows stay; the
  --    personal transfer receipts go).
  UPDATE public.wallet_funding_requests SET proof_url = NULL WHERE user_id = p_uid;
  UPDATE public.topup_requests SET proof_path = NULL WHERE account_id = p_uid;

  -- 5. Captain profile, if any: detach historical deliveries (driver_id is
  --    nullable on orders/rides), then delete the driver row; its documents,
  --    earnings, locations, vehicles and withdrawal requests cascade.
  SELECT array_agg(id) INTO v_driver_ids FROM public.drivers WHERE user_id = p_uid;
  IF v_driver_ids IS NOT NULL THEN
    UPDATE public.drivers SET current_delivery_id = NULL WHERE id = ANY (v_driver_ids);
    UPDATE public.orders SET driver_id = NULL WHERE driver_id = ANY (v_driver_ids);
    UPDATE public.rides SET driver_id = NULL WHERE driver_id = ANY (v_driver_ids);
    DELETE FROM public.order_dispatch WHERE candidate_driver_id = ANY (v_driver_ids);
    DELETE FROM public.drivers WHERE id = ANY (v_driver_ids);
  END IF;

  -- 6. Merchant profile, if any: detach historical orders/rides, then delete
  --    the store; its products, branches, favorites and profile rows cascade.
  SELECT array_agg(id) INTO v_merchant_ids FROM public.merchants WHERE owner_user_id = p_uid;
  IF v_merchant_ids IS NOT NULL THEN
    UPDATE public.orders SET merchant_id = NULL WHERE merchant_id = ANY (v_merchant_ids);
    UPDATE public.rides SET merchant_id = NULL WHERE merchant_id = ANY (v_merchant_ids);
    UPDATE public.coupons SET merchant_id = NULL WHERE merchant_id = ANY (v_merchant_ids);
    UPDATE public.reviews SET merchant_id = NULL WHERE merchant_id = ANY (v_merchant_ids);
    DELETE FROM public.merchants WHERE id = ANY (v_merchant_ids);
  END IF;
  DELETE FROM public.merchant_profiles WHERE user_id = p_uid;

  -- 7. Personal content rows.
  DELETE FROM public.user_addresses WHERE user_id = p_uid;
  DELETE FROM public.trusted_contacts WHERE user_id = p_uid;
  DELETE FROM public.saved_places WHERE user_id = p_uid;
  DELETE FROM public.favorites WHERE user_id = p_uid;
  DELETE FROM public.favorite_drivers WHERE user_id = p_uid;
  DELETE FROM public.notification_tokens WHERE user_id = p_uid;
  DELETE FROM public.notifications WHERE user_id = p_uid;
  DELETE FROM public.live_share_sessions WHERE user_id = p_uid;
  DELETE FROM public.location_updates WHERE user_id = p_uid;
  DELETE FROM public.user_region_preferences WHERE user_id = p_uid;
  DELETE FROM public.campaign_seen WHERE user_id = p_uid;
  DELETE FROM public.promo_redemptions WHERE user_id = p_uid;
  DELETE FROM public.reviews WHERE user_id = p_uid;
  DELETE FROM public.ride_ratings WHERE rater_id = p_uid;
  DELETE FROM public.service_reviews WHERE user_id = p_uid;
  DELETE FROM public.member_rewards WHERE user_id = p_uid;
  DELETE FROM public.grace_accounts WHERE user_id = p_uid;
  DELETE FROM public.chat_typing WHERE user_id = p_uid;
  DELETE FROM public.provider_business_profiles WHERE user_id = p_uid;

  -- 8. The engine's audit row references auth.users(actor) with NO ACTION;
  --    detach the member's actor rows so the auth delete below cannot fail.
  UPDATE public.audit_log SET actor = NULL WHERE actor = p_uid;

  -- 9. Anonymize the account row (D4 semantics, FK-safe) via the existing
  --    moderation engine, then revoke the login by removing the auth row.
  PERFORM public._member_exec_delete(
    p_uid, p_uid, COALESCE(NULLIF(btrim(p_reason), ''), 'user_requested'));

  DELETE FROM auth.users WHERE id = p_uid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_kpi_summary(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_region_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_regions uuid[];
  v_result jsonb;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;

  v_has_revenue := has_permission('PLATFORM_REVENUE');
  v_regions := public._kpi_effective_regions(p_region_id);

  SELECT jsonb_build_object(
    -- Members
    'total_users',         (SELECT count(*) FROM users u WHERE v_regions IS NULL OR public._user_in_regions(u.id, v_regions)),
    'customers',           (SELECT count(*) FROM users u WHERE u.user_type = 'customer' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'providers',           (SELECT count(*) FROM users u WHERE u.user_type = 'provider' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'delivery_users',      (SELECT count(*) FROM users u WHERE u.user_type = 'delivery' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'merchant_users',      (SELECT count(*) FROM users u WHERE u.user_type = 'merchant' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'driver_users',        (SELECT count(*) FROM users u WHERE u.user_type = 'driver' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'new_users_period',    (SELECT count(*) FROM users u WHERE u.created_at >= v_from AND u.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'pending_verification',(SELECT count(*) FROM users u WHERE u.verification_status = 'pending' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'verified_members',    (SELECT count(*) FROM users u WHERE u.verification_status = 'approved' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'rejected_members',    (SELECT count(*) FROM users u WHERE u.verification_status = 'rejected' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'new_today',           (SELECT count(*) FROM users u WHERE u.created_at >= date_trunc('day', v_now) AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'new_this_week',       (SELECT count(*) FROM users u WHERE u.created_at >= date_trunc('week', v_now) AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'new_this_month',      (SELECT count(*) FROM users u WHERE u.created_at >= date_trunc('month', v_now) AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),

    -- Drivers
    'total_drivers',       (SELECT count(*) FROM drivers d WHERE v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions)),
    'online_drivers',      (SELECT count(*) FROM drivers d WHERE d.is_online = true AND (v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions))),
    'verified_drivers',    (SELECT count(*) FROM drivers d WHERE d.is_verified = true AND (v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions))),

    -- Merchants
    'total_merchants',     (SELECT count(*) FROM merchants m WHERE v_regions IS NULL OR public._merchant_region_id(m.id) = ANY(v_regions)),
    'active_merchants',    (SELECT count(*) FROM merchants m WHERE m.status = 'active' AND (v_regions IS NULL OR public._merchant_region_id(m.id) = ANY(v_regions))),
    'merchants_by_type',   (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', type, 'count', c)), '[]'::jsonb)
      FROM (SELECT m.type, count(*) as c FROM merchants m
            WHERE v_regions IS NULL OR public._merchant_region_id(m.id) = ANY(v_regions)
            GROUP BY m.type) sub
    ),

    -- Orders
    'total_orders',        (SELECT count(*) FROM orders o WHERE v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)),
    'orders_today',        (SELECT count(*) FROM orders o WHERE o.created_at >= date_trunc('day', v_now) AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'orders_this_week',    (SELECT count(*) FROM orders o WHERE o.created_at >= date_trunc('week', v_now) AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'orders_this_month',   (SELECT count(*) FROM orders o WHERE o.created_at >= date_trunc('month', v_now) AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'completed_orders',    (SELECT count(*) FROM orders o WHERE o.status = 'delivered' AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'pending_orders',      (SELECT count(*) FROM orders o WHERE o.status = 'pending' AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'cancelled_orders',    (SELECT count(*) FROM orders o WHERE o.status = 'cancelled' AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),

    -- Rides & Deliveries
    'total_rides',         (SELECT count(*) FROM rides r WHERE r.service_type = 'ride' AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'completed_rides',     (SELECT count(*) FROM rides r WHERE r.service_type = 'ride' AND r.status = 'completed' AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'active_rides',        (SELECT count(*) FROM rides r WHERE r.service_type = 'ride' AND r.status IN ('searching','matched','arrived','inTrip') AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'total_deliveries',    (SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'completed_deliveries',(SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'completed' AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'active_deliveries',   (SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND r.status IN ('searching','matched','arrived','inTrip') AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),

    -- Service Bookings (region via service address geocode)
    'total_service_bookings',  (SELECT count(*) FROM service_bookings sb WHERE v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions)),
    'completed_service_bookings',(SELECT count(*) FROM service_bookings sb WHERE sb.status = 'completed' AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))),

    -- Financial (conditional on permission)
    'total_gmv',           CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'delivered' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)))
    ELSE 0 END,
    'ride_gmv',            CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type = 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)))
    ELSE 0 END,
    'delivery_gmv',        CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)))
    ELSE 0 END,
    'service_gmv',         CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(sb.final_price), 0) FROM service_bookings sb WHERE sb.status = 'completed' AND sb.completed_at >= v_from AND sb.completed_at <= v_to AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions)))
    ELSE 0 END,
    'platform_commission', CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions)))
    ELSE 0 END,
    'driver_earnings_total',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(de.amount), 0) FROM driver_earnings de WHERE de.created_at >= v_from AND de.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = de.driver_id), v_regions)))
    ELSE 0 END,
    'total_wallet_liability',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(w.balance), 0) FROM wallets w WHERE v_regions IS NULL OR public._user_in_regions(w.user_id, v_regions))
    ELSE 0 END,
    -- Commission buckets cannot be region-split without redefining the
    -- bucket helper; scoped admins get 0 rather than platform-wide numbers.
    'commission_7pct',     CASE WHEN v_has_revenue AND v_regions IS NULL THEN
      public._commission_bucket_amount(v_from, v_to, 'provider')
    ELSE 0 END,
    'commission_3pct',     CASE WHEN v_has_revenue AND v_regions IS NULL THEN
      public._commission_bucket_amount(v_from, v_to, 'merchant')
    ELSE 0 END,

    -- Risk
    'open_complaints',     (SELECT count(*) FROM complaints c WHERE c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
    'escalated_complaints', (SELECT count(*) FROM complaints c WHERE c.escalated_at IS NOT NULL AND c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
    'active_sanctions',    (SELECT count(*) FROM sanctions s WHERE s.is_active = true AND (v_regions IS NULL OR public._user_in_regions(s.target_user_id, v_regions))),
    'pending_withdrawals', (SELECT count(*) FROM withdrawal_requests wr WHERE wr.status = 'pending' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions))),
    'payment_failures',    (SELECT count(*) FROM payment_transactions pt WHERE pt.status = 'failed' AND pt.created_at >= v_from AND pt.created_at <= v_to AND (v_regions IS NULL OR public._order_region(pt.order_id) = ANY(v_regions))),

    -- Period
    'date_from', v_from
  ) || jsonb_build_object('date_to', v_to) INTO v_result;

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_operational_alerts()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_member_id uuid;
  v_regions uuid[];
  v_alerts jsonb := '[]'::jsonb;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;

  v_regions := public._kpi_effective_regions(NULL);

  IF (SELECT count(*) FROM users u WHERE u.verification_status = 'pending' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'verification_backlog', 'severity', 'warning',
      'message', 'Pending verification backlog',
      'count', (SELECT count(*) FROM users u WHERE u.verification_status = 'pending' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
      'action_route', '/admin/verifications'
    );
  END IF;

  IF (SELECT count(*) FROM complaints c WHERE c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'open_complaints', 'severity', 'warning',
      'message', 'Open complaints require attention',
      'count', (SELECT count(*) FROM complaints c WHERE c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
      'action_route', '/admin/complaints'
    );
  END IF;

  IF (SELECT count(*) FROM complaints c WHERE c.escalated_at IS NOT NULL AND c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'escalated_complaints', 'severity', 'critical',
      'message', 'Escalated complaints need immediate attention',
      'count', (SELECT count(*) FROM complaints c WHERE c.escalated_at IS NOT NULL AND c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
      'action_route', '/admin/escalations'
    );
  END IF;

  IF (SELECT count(*) FROM withdrawal_requests wr WHERE wr.status = 'pending' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'pending_withdrawals', 'severity', 'info',
      'message', 'Pending withdrawal requests',
      'count', (SELECT count(*) FROM withdrawal_requests wr WHERE wr.status = 'pending' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions))),
      'action_route', '/admin/drivers'
    );
  END IF;

  IF (SELECT count(*) FROM payment_transactions pt WHERE pt.status = 'failed' AND pt.created_at >= now() - interval '24 hours' AND (v_regions IS NULL OR public._order_region(pt.order_id) = ANY(v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'payment_failures', 'severity', 'warning',
      'message', 'Payment failures in last 24 hours',
      'count', (SELECT count(*) FROM payment_transactions pt WHERE pt.status = 'failed' AND pt.created_at >= now() - interval '24 hours' AND (v_regions IS NULL OR public._order_region(pt.order_id) = ANY(v_regions))),
      'action_route', '/admin/orders'
    );
  END IF;

  IF (SELECT count(*) FROM sanctions s WHERE s.is_active = true AND (v_regions IS NULL OR public._user_in_regions(s.target_user_id, v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'active_sanctions', 'severity', 'info',
      'message', 'Active sanctions on platform',
      'count', (SELECT count(*) FROM sanctions s WHERE s.is_active = true AND (v_regions IS NULL OR public._user_in_regions(s.target_user_id, v_regions))),
      'action_route', '/admin/sanctions'
    );
  END IF;

  RETURN jsonb_build_object('alerts', v_alerts, 'count', jsonb_array_length(v_alerts));
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_member_profile(p_member_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row record;
  v_region uuid;
  v_loc boolean;
  v_docs boolean;
  v_support boolean;
  v_mod boolean;
  v_tl boolean;
  v_em boolean;
  v_region_name text;
  v_docs_row record;
  v_support_rows jsonb;
  v_mods jsonb;
  v_events jsonb;
  v_result jsonb;
BEGIN
  SELECT role, user_type, verification_status, account_status, language, created_at, updated_at
  INTO v_row
  FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  v_region := public._ops_scope_region(public._member_region_id(p_member_id));
  IF NOT public.has_permission('MEMBER_VIEW', v_region) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;
  v_loc := public.has_permission('MEMBER_VIEW_LOCATION', v_region);
  v_docs := public.has_permission('MEMBER_VIEW_DOCUMENTS', v_region);
  v_support := public.has_permission('MEMBER_VIEW_CHAT_HISTORY', v_region);
  v_mod := public.has_permission('MEMBER_VIEW_COMPLAINTS', v_region)
           OR public.has_permission('MEMBER_MODERATE', v_region);
  v_tl := public.has_permission('MEMBER_VIEW_TIMELINE', v_region);
  v_em := public.has_permission('EMERGENCY_VIEW', v_region);

  v_result := jsonb_build_object(
    'member_id', p_member_id::text,
    'basic', jsonb_build_object(
      'role', v_row.role, 'user_type', v_row.user_type,
      'verification_status', v_row.verification_status,
      'account_status', v_row.account_status,
      'language', v_row.language,
      'created_at', v_row.created_at,
      'updated_at', v_row.updated_at));

  IF v_loc THEN
    SELECT r.name_en INTO v_region_name
    FROM public.user_region_preferences p
    LEFT JOIN public.regions r ON r.id = p.region_id
    WHERE p.user_id = p_member_id
    ORDER BY p.updated_at DESC
    LIMIT 1;
    v_result := v_result || jsonb_build_object(
      'location', jsonb_build_object('region_id', v_region, 'region_name', v_region_name));
  END IF;

  IF v_docs THEN
    SELECT id_card_url, trade_license_url, driving_license_url, profile_photo_url
    INTO v_docs_row
    FROM public.users WHERE id = p_member_id;
    v_result := v_result || jsonb_build_object(
      'documents', jsonb_build_object(
        'id_card_url', v_docs_row.id_card_url,
        'trade_license_url', v_docs_row.trade_license_url,
        'driving_license_url', v_docs_row.driving_license_url,
        'profile_photo_url', v_docs_row.profile_photo_url));
  END IF;

  -- Support-chat section lights up when support_rooms lands (master schema).
  IF v_support AND to_regclass('public.support_rooms') IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
             jsonb_build_object('room_id', sr.id::text, 'created_at', sr.created_at)
             ORDER BY sr.created_at DESC), '[]'::jsonb)
    INTO v_support_rows
    FROM public.support_rooms sr
    WHERE sr.customer_id = p_member_id;
    v_result := v_result || jsonb_build_object('support', v_support_rows);
  END IF;

  IF v_mod THEN
    v_mods := jsonb_build_object(
      'complaints',
      (SELECT count(*) FROM public.complaints c
       WHERE c.respondent_id = p_member_id OR c.complainant_id = p_member_id),
      'sanctions',
      (SELECT COALESCE(jsonb_agg(
               jsonb_build_object('sanction_type', s.sanction_type, 'reason', s.reason,
                                  'start_date', s.start_date, 'end_date', s.end_date,
                                  'action_status', s.action_status)
               ORDER BY s.created_at DESC), '[]'::jsonb)
       FROM public.sanctions s WHERE s.target_user_id = p_member_id));
    v_result := v_result || jsonb_build_object('moderation', v_mods);
  END IF;

  IF v_tl THEN
    v_events := (SELECT COALESCE(jsonb_agg(
                   jsonb_build_object('event_type', e.event_type, 'created_at', e.created_at)
                   ORDER BY e.created_at DESC), '[]'::jsonb)
                 FROM (SELECT e.event_type, e.created_at
                       FROM public.member_events e
                       WHERE e.user_id = p_member_id
                       ORDER BY e.created_at DESC LIMIT 10) e);
    v_result := v_result || jsonb_build_object('timeline_summary', v_events);
  END IF;

  v_result := v_result || jsonb_build_object('access', jsonb_build_object(
    'location', v_loc, 'documents', v_docs, 'support', v_support,
    'moderation', v_mod, 'timeline', v_tl, 'emergency', v_em));
  RETURN v_result;
END;
$function$;

DROP TRIGGER IF EXISTS notify_sos_alert ON public.sos_alerts;
DROP FUNCTION IF EXISTS public.notify_sos_alert();
DROP FUNCTION IF EXISTS public.open_emergency_chat(double precision, double precision, text);
DROP FUNCTION IF EXISTS public.resolve_sos_alert(uuid, text);
DROP TABLE IF EXISTS public.sos_alerts;
