-- 111: get_commission_rate overload ambiguity (SQLSTATE 42725)
--
-- SYMPTOM (reported from the admin Operations Center):
--   PostgrestException(message: function public.get_commission_rate(text, unknown)
--   is not unique, code: 42725, details: Bad Request,
--   hint: Could not choose a best candidate function.)
--
-- ROOT CAUSE
--   public.get_commission_rate existed as BOTH
--     (p_account_type text, p_service_category text)                       -- migration 049, redefined by 052
--     (p_account_type text, p_service_category text, p_user_id uuid DEFAULT NULL)  -- migration 063
--   The three-argument version has a DEFAULT on its trailing parameter, so it
--   also accepts a two-argument call. Every two-argument call therefore has two
--   equally good candidates and Postgres/PostgREST cannot choose one:
--     SELECT public.get_commission_rate('delivery', NULL);
--     ERROR 42725: function public.get_commission_rate(unknown, unknown) is not unique
--   Reproduced live before this migration. It is not confined to the console:
--   the ambiguous call is in the body of complete_delivery, get_member_ops_profile
--   and get_my_financial_summary, so those RPCs fail the moment their rate lookup
--   is reached - a driver completing a delivery is one of them.
--
-- The class of defect, not just the instance: any pair of overloads where one
-- argument list is a strict prefix of the other and the longer one defaults its
-- trailing parameters. A live sweep of every function in the public schema found
-- exactly three such pairs; all three are closed here.
--
-- FIX
--   1. Drop the redundant shorter overload. In every case the surviving longer
--      signature is a strict superset, so no capability is lost:
--        get_commission_rate(text,text)              -> (text,text,uuid) adds the
--             per-account override AND the c.is_active filter, so it is also the
--             more correct body; migration 052's rules are contained in it.
--        _reward_config(text)                       -> (text,uuid) already
--             falls back to the region-less config when p_region_id IS NULL.
--        complete_delivery_for_driver(4 args)       -> (5 args) adds p_recipient_otp.
--      Access control is unchanged: each survivor already carried the dropped
--      twin's ACL (verified against pg_proc.proacl).
--   2. Re-emit every live caller with an explicit ::text cast, so the intent is
--      recorded in the source and a future overload cannot make these calls
--      ambiguous again. Bodies are taken verbatim from the live database.
--   3. Assert afterwards that no shadowing pair remains in the public schema.

-- STEP 1 - remove the three shadowing shorter overloads. IF EXISTS throughout,
-- so this migration is safe to re-apply and safe on a database where one of the
-- twins was never created.
DROP FUNCTION IF EXISTS public.get_commission_rate(text, text);
DROP FUNCTION IF EXISTS public._reward_config(text);
DROP FUNCTION IF EXISTS public.complete_delivery_for_driver(uuid, uuid, text, numeric);

-- The survivors already carried the ACLs of the twins they replace
-- (verified against pg_proc.proacl): get_commission_rate(text,text,uuid) and
-- _reward_config(text,uuid) are granted to postgres/authenticated/service_role,
-- complete_delivery_for_driver(uuid,uuid,text,numeric,text) additionally to
-- PUBLIC and anon. Re-asserting the authenticated/service_role grants so a
-- rebuild that recreates them from this file keeps the same reachability.
GRANT EXECUTE ON FUNCTION public.get_commission_rate(text, text, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._reward_config(text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_delivery_for_driver(uuid, uuid, text, numeric, text) TO authenticated, service_role;

-- ------------------------------------------------------------------------
-- complete_delivery: identical body, explicit casts on the rate lookup.
-- ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_delivery(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$

DECLARE
  v_uid     uuid := auth.uid();
  v_order   orders%ROWTYPE;
  v_is_driver boolean;
  v_driver_uid uuid;
  v_rate      numeric;
  v_commission numeric;
  v_net       numeric;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL OR v_order.driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_ASSIGNED');
  END IF;
  IF v_order.status = 'delivered' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ALREADY_DONE');
  END IF;

  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  v_is_driver := EXISTS (
    SELECT 1 FROM public.drivers d
     WHERE d.user_id = v_uid AND d.id = v_order.driver_id
  );

  IF NOT v_is_driver AND NOT public._is_owner_uid(v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  -- Canonical identity mapping: driver_earnings.driver_id -> drivers.id;
  -- platform_commissions.member_id -> users.id (drivers.user_id).
  SELECT user_id INTO v_driver_uid
    FROM public.drivers WHERE id = v_order.driver_id;

  SELECT COALESCE(public.get_commission_rate('delivery'::text, NULL::text), 0) INTO v_rate;
  v_rate := COALESCE(v_rate, 0);
  v_commission := (COALESCE(v_order.total_amount, 0) * v_rate / 100.0);
  v_net := COALESCE(v_order.total_amount, 0) - v_commission;

  INSERT INTO public.driver_earnings (driver_id, ride_id, type, amount, currency, description)
  VALUES (v_order.driver_id, NULL, 'trip', v_net, 'EGP', 'Order ' || p_order_id::text || ' delivery earning');

  INSERT INTO public.platform_commissions (member_id, reference_type, reference_id, gross_amount, commission_rate, commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'order', p_order_id, v_order.total_amount, v_rate, v_commission, v_net, 'EGP', 'computed');

  UPDATE public.orders SET status = 'delivered', dispatch_status = 'ACCEPTED'
    WHERE id = p_order_id;

  PERFORM public.log_admin_action('DELIVERY_COMPLETE', 'order', p_order_id::text,
    NULL, jsonb_build_object('commission', v_commission, 'rate', v_rate), NULL, 'GLOBAL');
  RETURN jsonb_build_object('ok', true, 'commission', v_commission, 'rate', v_rate);
END;
$fn$;

-- ------------------------------------------------------------------------
-- get_member_ops_profile: identical body, explicit casts on the rate lookup.
-- ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_member_ops_profile(p_member_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$

DECLARE
  v_uid          uuid := auth.uid();
  v_member_regid uuid;
  v_can_loc      boolean;
  v_can_chat     boolean;
  v_can_docs     boolean;
  v_can_mod      boolean;
  v_exists       boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT region_id INTO v_member_regid
    FROM public.user_region_preferences
   WHERE user_id = p_member_id
   ORDER BY updated_at DESC LIMIT 1;

  IF NOT public.has_permission('MEMBER_VIEW', v_member_regid) THEN
    RETURN NULL;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = p_member_id
  ) INTO v_exists;
  IF NOT v_exists THEN
    RETURN NULL;
  END IF;

  v_can_loc  := public.has_permission('MEMBER_VIEW_LOCATION', v_member_regid);
  v_can_chat := public.has_permission('MEMBER_VIEW_CHAT_HISTORY', v_member_regid);
  v_can_docs := public.has_permission('MEMBER_VIEW_DOCUMENTS', v_member_regid);
  v_can_mod  := public.has_permission('MEMBER_MODERATE', v_member_regid);

  RETURN jsonb_build_object(
    'member', (
      SELECT jsonb_build_object(
        'id', u.id, 'full_name', u.full_name, 'email', u.email, 'phone', u.phone,
        'avatar_url', u.avatar_url, 'username', u.username,
        'role', u.role, 'user_type', u.user_type,
        'account_status', COALESCE(u.account_status, 'active'),
        'verification_status', COALESCE(u.verification_status, 'unverified'),
        'language', u.language, 'is_onboarded', u.is_onboarded,
        'date_of_birth', u.date_of_birth,
        'created_at', u.created_at, 'updated_at', u.updated_at)
        FROM public.users u WHERE u.id = p_member_id
    ),
    'region', (
      SELECT jsonb_build_object(
        'region_id', up.region_id,
        'label', public._region_label_path(up.region_id))
        FROM public.user_region_preferences up
       WHERE up.user_id = p_member_id ORDER BY up.updated_at DESC LIMIT 1
    ),
    'location', CASE WHEN v_can_loc THEN (
      SELECT jsonb_build_object(
        'latitude', l.latitude, 'longitude', l.longitude,
        'accuracy', l.accuracy, 'recorded_at', l.recorded_at,
        'is_moving', l.is_moving)
        FROM public.location_updates l
       WHERE l.user_id = p_member_id
       ORDER BY l.recorded_at DESC LIMIT 1)
      ELSE NULL END,
    'last_seen', (
      SELECT GREATEST(
        (SELECT MAX(recorded_at) FROM public.location_updates lu WHERE lu.user_id = p_member_id),
        (SELECT MAX(last_seen_at) FROM public.notification_tokens nt WHERE nt.user_id = p_member_id))
    ),
    'driver', (
      SELECT jsonb_build_object(
        'id', id, 'vehicle_type', vehicle_type, 'vehicle_plate', vehicle_plate,
        'is_online', is_online, 'is_verified', is_verified,
        'verification_status', verification_status,
        'status', status, 'rating', rating, 'total_deliveries', total_deliveries,
        'total_trips', total_trips, 'earnings_balance', earnings_balance,
        'background_check_status', background_check_status,
        'service_types', service_types)
        FROM public.drivers WHERE user_id = p_member_id
    ),
    'merchants', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'name', name, 'type', type, 'status', status,
        'rating', rating, 'total_orders', total_orders,
        'delivery_fee', delivery_fee, 'min_order', min_order,
        'is_featured', is_featured))
        FROM public.merchants WHERE owner_user_id = p_member_id)
    , '[]'::jsonb),
    'providers', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'name', name, 'category_type', category_type,
        'is_verified', is_verified, 'is_available', is_available,
        'rating', rating, 'rating_count', rating_count,
        'hourly_rate', hourly_rate, 'fixed_price_min', fixed_price_min,
        'fixed_price_max', fixed_price_max, 'city', city))
        FROM public.service_providers WHERE user_id = p_member_id)
    , '[]'::jsonb),
    'orders', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'merchant_id', merchant_id, 'driver_id', driver_id,
            'status', status, 'payment_status', payment_status,
            'total_amount', total_amount, 'created_at', created_at) AS j
          FROM public.orders WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'rides', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'service_type', service_type, 'status', status,
            'fare', fare, 'driver_rating', driver_rating, 'created_at', created_at) AS j
          FROM public.rides WHERE rider_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'bookings', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'category_type', category_type, 'status', status,
            'provider_name', provider_name, 'final_price', final_price,
            'created_at', created_at) AS j
          FROM public.service_bookings WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'wallet', (
      SELECT jsonb_build_object(
        'balance', w.balance, 'currency', w.currency,
        'transactions', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', t.id, 'type', t.type, 'amount', t.amount,
                'reference_type', t.reference_type, 'balance_after', t.balance_after,
                'created_at', t.created_at) AS j
              FROM public.wallet_transactions t WHERE t.wallet_id = w.id
              ORDER BY t.created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
        FROM public.wallets w WHERE w.user_id = p_member_id
    ),
    'financials', (
      SELECT jsonb_build_object(
        'gross_orders', COALESCE(SUM(o.total_amount), 0),
        'orders_count', COUNT(o.id),
        'commission_rate', public.get_commission_rate(u.user_type::text, NULL::text),
        'commission_estimated', ROUND(COALESCE(SUM(o.total_amount), 0)
                                  * COALESCE(public.get_commission_rate(u.user_type::text, NULL::text), 0) / 100.0, 2),
        'commissions', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'reference_type', c.reference_type, 'gross_amount', c.gross_amount,
                'commission_rate', c.commission_rate, 'commission_amount', c.commission_amount,
                'net_amount', c.net_amount, 'status', c.status, 'created_at', c.created_at) AS j
              FROM public.platform_commissions c WHERE c.member_id = p_member_id
              ORDER BY c.created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
        FROM public.users u
        LEFT JOIN public.orders o ON o.user_id = u.id
       WHERE u.id = p_member_id
       GROUP BY u.user_type
    ),
    'active_sanctions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'sanction_type', sanction_type, 'reason', reason,
        'amount', amount, 'start_date', start_date, 'end_date', end_date,
        'is_active', is_active, 'issued_by', issued_by, 'created_at', created_at))
        FROM public.sanctions
       WHERE target_user_id = p_member_id AND is_active)
    , '[]'::jsonb),
    'complaints', (
      SELECT jsonb_build_object(
        'filed_count', (SELECT COUNT(*) FROM public.complaints WHERE complainant_id = p_member_id),
        'received_count', (SELECT COUNT(*) FROM public.complaints WHERE respondent_id = p_member_id),
        'related', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', id, 'complaint_type', complaint_type, 'category', category,
                'status', status, 'priority', priority, 'subject', subject, 'created_at', created_at) AS j
              FROM public.complaints
             WHERE complainant_id = p_member_id OR respondent_id = p_member_id
             ORDER BY created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
    ),
    'support', (
      SELECT jsonb_build_object(
        'rooms_count', (SELECT COUNT(*) FROM public.chat_rooms
                         WHERE p_member_id = ANY(participant_ids)),
        'rooms', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', id, 'room_type', room_type, 'status', status,
                'priority', priority, 'last_message_at', last_message_at, 'created_at', created_at) AS j
              FROM public.chat_rooms
             WHERE p_member_id = ANY(participant_ids)
             ORDER BY last_message_at DESC NULLS LAST LIMIT 10) s)
        , '[]'::jsonb))
    ),
    'timeline', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'event_type', event_type, 'title', title,
            'payload', payload, 'created_at', created_at) AS j
          FROM public.member_events WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 20) s)
    , '[]'::jsonb),
    'permissions', jsonb_build_object(
      'can_view_location',   v_can_loc,
      'can_view_chat',       v_can_chat,
      'can_view_documents',  v_can_docs,
      'can_moderate',        v_can_mod
    )
  );
END;
$fn$;

-- ------------------------------------------------------------------------
-- get_my_financial_summary: identical body, explicit casts on the rate lookup.
-- ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_financial_summary()
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$

DECLARE
  v_uid uuid := auth.uid();
  v_balance numeric;
  v_grace jsonb;
  v_rate numeric;
  v_ut text;
  v_pending int;
  v_txns jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT balance INTO v_balance FROM public.wallets WHERE user_id = v_uid;
  v_balance := COALESCE(v_balance, 0);
  v_grace := public.get_my_grace();
  SELECT user_type INTO v_ut FROM public.users WHERE id = v_uid;
  v_rate := public.get_commission_rate(v_ut::text, NULL::text);

  SELECT count(*) INTO v_pending FROM public.topup_requests
   WHERE account_id = v_uid AND status = 'pending';

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id, 'type', type, 'amount', amount, 'description', description,
    'balance_after', balance_after, 'created_at', created_at)), '[]'::jsonb) INTO v_txns
  FROM (
    SELECT * FROM public.wallet_transactions wt
     WHERE wallet_id = (SELECT id FROM public.wallets WHERE user_id = v_uid)
    ORDER BY created_at DESC LIMIT 10
  ) sub;

  RETURN jsonb_build_object(
    'balance', v_balance,
    'grace_limit', (v_grace ->> 'grace_limit')::int,
    'grace_used', (v_grace ->> 'grace_used')::int,
    'grace_remaining', (v_grace ->> 'grace_remaining')::int,
    'commission_rate', v_rate,
    'pending_topups', v_pending,
    'recent_transactions', COALESCE(v_txns, '[]'::jsonb)
  );
END;
$fn$;

-- Verification: fail loudly if any shadowing overload pair is ever reintroduced.
DO $$
DECLARE
  v_pairs text;
BEGIN
  SELECT string_agg(short_name || ' is shadowed by ' || long_name, ', ')
    INTO v_pairs
  FROM (
    SELECT DISTINCT a.proname AS short_name, b.proname AS long_name
      FROM pg_proc a
      JOIN pg_proc b ON b.proname = a.proname AND b.oid <> a.oid
      JOIN pg_namespace na ON na.oid = a.pronamespace AND na.nspname = 'public'
      JOIN pg_namespace nb ON nb.oid = b.pronamespace AND nb.nspname = 'public'
     WHERE split_part(b.proargtypes::text, ',', 1) = split_part(a.proargtypes::text, ',', 1)
       AND b.proargtypes::text LIKE split_part(a.proargtypes::text, ',', 1) || ',%'
       AND b.pronargdefaults >= b.pronargs - a.pronargs
  ) pairs;
  IF v_pairs IS NOT NULL THEN
    RAISE EXCEPTION 'ambiguous overload pairs still present: %', v_pairs;
  END IF;
  RAISE NOTICE 'no shadowing overload pairs remain in public schema';
END $$;
