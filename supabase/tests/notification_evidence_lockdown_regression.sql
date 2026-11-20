-- Run after migration 154. Fixtures and rows roll back.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid();
  other uuid := gen_random_uuid();
  log_id uuid := gen_random_uuid();
  v_blocked boolean;
  v_count int;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (u,u::text||'@example.invalid'),(other,other::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (u,u::text||'@example.invalid'),(other,other::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;

  -- fixtures as table owner
  INSERT INTO public.notification_tokens(user_id, token, platform)
    VALUES (other, 'fixture-fcm-token', 'android');
  INSERT INTO public.merchants(id, owner_user_id, name)
    VALUES (gen_random_uuid(), other, 'Fixture M');
  INSERT INTO public.orders(id, user_id, merchant_id, status, subtotal, total_amount)
    SELECT gen_random_uuid(), u, id, 'pending', 10, 10 FROM public.merchants WHERE name='Fixture M';
  INSERT INTO public.service_audio_logs(id, order_id, user_id, audio_url)
    SELECT log_id, o.id, u, 'https://example.invalid/a.m4a'
    FROM public.orders o WHERE o.user_id = u LIMIT 1;

  PERFORM set_config('request.jwt.claim.sub', u::text, true);
  PERFORM set_config('role','authenticated',true);

  -- 1. destinations: unreadable and unwritable
  v_blocked := false;
  BEGIN
    PERFORM count(*) FROM public.notification_destinations;
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END;
  SELECT count(*) INTO v_count FROM public.notification_destinations;
  IF v_count <> 0 AND NOT v_blocked THEN RAISE EXCEPTION 'client reads push routing'; END IF;

  -- 2. tokens: cannot see or delete other users' tokens
  SELECT count(*) INTO v_count FROM public.notification_tokens WHERE user_id = other;
  IF v_count <> 0 THEN RAISE EXCEPTION 'client reads another users token'; END IF;
  DELETE FROM public.notification_tokens WHERE user_id = other;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 0 THEN RAISE EXCEPTION 'client deleted another users token'; END IF;

  -- own token management still works
  INSERT INTO public.notification_tokens(user_id, token, platform)
    VALUES (u, 'own-token', 'android');
  DELETE FROM public.notification_tokens WHERE user_id = u AND token = 'own-token';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 1 THEN RAISE EXCEPTION 'own token management broken'; END IF;

  -- 3. audio logs: read own, insert own, but no rewrite or erase
  PERFORM 1 FROM public.service_audio_logs WHERE id = log_id;
  v_blocked := false;
  BEGIN
    UPDATE public.service_audio_logs SET status = 'deleted' WHERE id = log_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count > 0 THEN RAISE EXCEPTION 'keep'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  v_blocked := false;
  BEGIN
    DELETE FROM public.service_audio_logs WHERE id = log_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count > 0 THEN RAISE EXCEPTION 'keep'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  IF NOT EXISTS (SELECT 1 FROM public.service_audio_logs WHERE id = log_id) THEN
    RAISE EXCEPTION 'audio log erased';
  END IF;

  PERFORM set_config('role','none',true);
END;
$$;
ROLLBACK;
