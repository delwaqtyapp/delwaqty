-- Run after migration 466. Synthetic fixtures only, everything rolled back.
-- Mode flag, signup hook, unconfirmed-account limits, confirm RPC.
BEGIN;
DO $$
DECLARE
  v_phone text := '+201000000466';
  v_ev jsonb;
  r jsonb;
  u uuid := gen_random_uuid();
  m uuid;
  owner uuid := gen_random_uuid();
  v_flag boolean;
  v_ok boolean;
  n int;
BEGIN
  INSERT INTO public.platform_settings(id) VALUES ('default') ON CONFLICT (id) DO NOTHING;
  v_ev := jsonb_build_object('user', jsonb_build_object(
    'email', 'phone_' || substring(v_phone from 2) || '@delwaqty.app',
    'app_metadata', jsonb_build_object('provider', 'email'),
    'user_metadata', jsonb_build_object('phone', v_phone)));

  -- (1) default mode keeps the WhatsApp requirement
  UPDATE public.platform_settings SET feature_flags = '{}'::jsonb WHERE id = 'default';
  ASSERT public.signup_phone_mode() = 'whatsapp', '466 1a: default mode is not whatsapp';
  r := public.before_user_created_phone_guard(v_ev);
  ASSERT r #>> '{error,message}' LIKE 'PHONE_NOT_VERIFIED%', '466 1b: whatsapp mode allowed an unproven phone: ' || r::text;

  -- (2) password mode allows it, other checks stay
  UPDATE public.platform_settings SET feature_flags = '{"signup_phone_mode":"password"}'::jsonb WHERE id = 'default';
  ASSERT public.signup_phone_mode() = 'password', '466 2a: flag not read';
  r := public.before_user_created_phone_guard(v_ev);
  ASSERT r = '{}'::jsonb, '466 2b: password mode refused a valid phone: ' || r::text;
  r := public.before_user_created_phone_guard(jsonb_set(v_ev, '{user,user_metadata,phone}', '"+20123"'));
  ASSERT r #>> '{error,message}' LIKE 'PHONE_INVALID%' OR r #>> '{error,message}' LIKE 'PHONE_EMAIL_MISMATCH%', '466 2c: bad phone accepted: ' || r::text;
  r := public.before_user_created_phone_guard(jsonb_set(v_ev, '{user,email}', '"someone@example.com"'));
  ASSERT r #>> '{error,message}' LIKE 'PHONE_EMAIL_MISMATCH%', '466 2d: non-canonical identifier accepted';
  r := public.before_user_created_phone_guard(jsonb_set(v_ev, '{user,app_metadata,provider}', '"facebook"'));
  ASSERT r #>> '{error,message}' LIKE 'SIGNUP_PROVIDER_NOT_ALLOWED%', '466 2e: provider allow-list weakened';

  -- (3) the account is created unconfirmed; duplicate phone refused
  INSERT INTO auth.users(id, email, raw_user_meta_data)
    VALUES (u, 'phone_' || substring(v_phone from 2) || '@delwaqty.app',
            jsonb_build_object('phone', v_phone, 'full_name', 'T466'));
  ASSERT (SELECT phone_verified FROM public.users WHERE id = u) = false, '466 3a: password-mode signup is marked confirmed';
  r := public.before_user_created_phone_guard(v_ev);
  ASSERT r #>> '{error,message}' LIKE 'PHONE_ALREADY_REGISTERED%', '466 3b: duplicate phone accepted';

  -- (4) hourly breaker
  UPDATE public.platform_settings SET feature_flags = '{"signup_phone_mode":"password","signup_unverified_per_hour":1}'::jsonb WHERE id = 'default';
  r := public.before_user_created_phone_guard(jsonb_set(jsonb_set(v_ev, '{user,user_metadata,phone}', '"+201000000467"'), '{user,email}', '"phone_201000000467@delwaqty.app"'));
  ASSERT r #>> '{error,message}' LIKE 'SIGNUP_BUSY%', '466 4: breaker did not trip: ' || r::text;
  UPDATE public.platform_settings SET feature_flags = '{"signup_phone_mode":"password"}'::jsonb WHERE id = 'default';

  -- (5) limits on an unconfirmed customer
  INSERT INTO auth.users(id, email) VALUES (owner, owner::text || '@example.invalid');
  INSERT INTO public.users(id, email, role) VALUES (owner, owner::text || '@example.invalid', 'merchant') ON CONFLICT (id) DO NOTHING;
  m := gen_random_uuid();
  INSERT INTO public.merchants(id, name, owner_user_id) VALUES (m, 'T466 shop', owner);
  IF true THEN
    v_ok := true;
    BEGIN
      INSERT INTO public.orders(user_id, merchant_id, status, payment_method, subtotal, total_amount)
        VALUES (u, m, 'pending', 'instapay', 10, 10);
      v_ok := false;
    EXCEPTION WHEN raise_exception THEN NULL; END;
    ASSERT v_ok, '466 5a: unconfirmed customer paid by non-cash';
    INSERT INTO public.orders(user_id, merchant_id, status, payment_method, subtotal, total_amount)
      VALUES (u, m, 'pending', 'cash', 10, 10), (u, m, 'pending', 'cash', 10, 10);
    v_ok := true;
    BEGIN
      INSERT INTO public.orders(user_id, merchant_id, status, payment_method, subtotal, total_amount)
        VALUES (u, m, 'pending', 'cash', 10, 10);
      v_ok := false;
    EXCEPTION WHEN raise_exception THEN NULL; END;
    ASSERT v_ok, '466 5b: third open order accepted';
  END IF;

  -- (6) the holder cannot flip the flag; an admin-less stranger cannot confirm
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  SET LOCAL ROLE authenticated;
  BEGIN
    UPDATE public.users SET phone_verified = true WHERE id = u;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  r := public.confirm_customer_phone(u);
  RESET ROLE;
  SELECT phone_verified INTO v_flag FROM public.users WHERE id = u;
  ASSERT v_flag = false, '466 6a: holder flipped phone_verified';
  ASSERT r ->> 'reason' = 'FORBIDDEN', '466 6b: the customer confirmed their own phone: ' || r::text;

  -- the merchant that owns one of the orders can confirm, with an audit row
  PERFORM set_config('request.jwt.claims', json_build_object('sub', owner)::text, true);
  SET LOCAL ROLE authenticated;
  r := public.confirm_customer_phone(u);
  RESET ROLE;
  ASSERT (r ->> 'ok')::boolean, '466 6c: owning merchant could not confirm: ' || r::text;
  ASSERT (SELECT phone_verified FROM public.users WHERE id = u), '466 6d: flag not set';
  ASSERT EXISTS (SELECT 1 FROM public.audit_log WHERE action = 'confirm_customer_phone' AND resource_id = u::text), '466 6e: no audit row';
  PERFORM set_config('request.jwt.claims', '{}', true);
  UPDATE public.users SET phone_verified = false WHERE id = u;

  -- (7) once confirmed the limits lift
  UPDATE public.users SET phone_verified = true WHERE id = u;
  INSERT INTO public.orders(user_id, merchant_id, status, payment_method, subtotal, total_amount)
    VALUES (u, m, 'pending', 'instapay', 10, 10);
END $$;
ROLLBACK;
