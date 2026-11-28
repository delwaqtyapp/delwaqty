-- Run after 467. Synthetic fixtures, rolled back.
BEGIN;
DO $$
DECLARE
  r jsonb;
  ev jsonb;
  u uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.platform_settings(id) VALUES ('default') ON CONFLICT (id) DO NOTHING;
  UPDATE public.platform_settings SET feature_flags = '{}'::jsonb WHERE id = 'default';
  ASSERT public.auth_methods() = '{"email":false,"facebook":false,"google":true}'::jsonb, '467 1a: defaults changed: ' || public.auth_methods()::text;

  ev := jsonb_build_object('user', jsonb_build_object('email', 'new.user@example.com', 'app_metadata', jsonb_build_object('provider', 'email')));
  r := public.before_user_created_phone_guard(ev);
  ASSERT r #>> '{error,message}' LIKE 'EMAIL_SIGNUP_NOT_ALLOWED%', '467 2a: email signup open by default: ' || r::text;
  r := public.before_user_created_phone_guard(jsonb_set(ev, '{user,app_metadata,provider}', '"facebook"'));
  ASSERT r #>> '{error,message}' LIKE 'SIGNUP_PROVIDER_NOT_ALLOWED%', '467 2b: facebook open by default';
  r := public.before_user_created_phone_guard(jsonb_set(ev, '{user,app_metadata,provider}', '"google"'));
  ASSERT r = '{}'::jsonb, '467 2c: google refused: ' || r::text;
  r := public.before_user_created_phone_guard(jsonb_set(ev, '{user,app_metadata,provider}', '"github"'));
  ASSERT r #>> '{error,message}' LIKE 'SIGNUP_PROVIDER_NOT_ALLOWED%', '467 2d: allow-list weakened';

  UPDATE public.platform_settings SET feature_flags = '{"auth_methods":{"email":true,"facebook":true}}'::jsonb WHERE id = 'default';
  ASSERT (public.auth_methods() ->> 'email')::boolean AND (public.auth_methods() ->> 'facebook')::boolean, '467 3a: flags not read';
  r := public.before_user_created_phone_guard(ev);
  ASSERT r = '{}'::jsonb, '467 3b: valid email refused: ' || r::text;
  r := public.before_user_created_phone_guard(jsonb_set(ev, '{user,email}', '"not-an-email"'));
  ASSERT r #>> '{error,message}' LIKE 'EMAIL_INVALID%', '467 3c: bad email accepted';
  r := public.before_user_created_phone_guard(jsonb_set(ev, '{user,email}', '"someone@delwaqty.app"'));
  ASSERT r #>> '{error,message}' LIKE 'EMAIL_INVALID%', '467 3d: own-domain email accepted';
  r := public.before_user_created_phone_guard(jsonb_set(ev, '{user,app_metadata,provider}', '"facebook"'));
  ASSERT r = '{}'::jsonb, '467 3e: facebook refused when on';
  -- legacy phone path still behaves: unproven phone is refused
  r := public.before_user_created_phone_guard(jsonb_build_object('user', jsonb_build_object(
    'email', 'phone_201000000467@delwaqty.app', 'app_metadata', jsonb_build_object('provider', 'email'),
    'user_metadata', jsonb_build_object('phone', '+201000000467'))));
  ASSERT r #>> '{error,message}' LIKE 'PHONE_NOT_VERIFIED%', '467 3f: legacy phone guard changed: ' || r::text;

  -- breaker
  UPDATE public.platform_settings SET feature_flags = '{"auth_methods":{"email":true},"email_signup_per_hour":1}'::jsonb WHERE id = 'default';
  INSERT INTO auth.users(id, email) VALUES (u, 'a.b@example.com');
  r := public.before_user_created_phone_guard(ev);
  ASSERT r #>> '{error,message}' LIKE 'SIGNUP_BUSY%', '467 4a: breaker did not trip: ' || r::text;

  -- email login identifier: real accounts only, never the technical identifier
  ASSERT public.auth_login_resolve_email('A.B@example.com') = 'a.b@example.com', '467 5a: real email did not resolve';
  ASSERT public.auth_login_resolve_email('nobody@example.com') IS NULL, '467 5b: unknown email resolved';
  INSERT INTO auth.users(id, email) VALUES (gen_random_uuid(), 'phone_201000000999@delwaqty.app');
  ASSERT public.auth_login_resolve_email('phone_201000000999@delwaqty.app') IS NULL, '467 5c: technical identifier resolved';
  ASSERT NOT has_function_privilege('anon', 'public.auth_login_resolve_email(text)', 'EXECUTE'), '467 5d: resolve callable by anon';
  ASSERT has_function_privilege('anon', 'public.auth_methods()', 'EXECUTE'), '467 5e: auth_methods not callable by anon';
END $$;
ROLLBACK;
