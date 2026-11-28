-- Run after 468. Synthetic fixtures, rolled back.
BEGIN;
DO $$
DECLARE u uuid := gen_random_uuid(); v text;
BEGIN
  INSERT INTO auth.users(id, email) VALUES (u, 'old.468@example.com');
  UPDATE public.users SET email = 'old.468@example.com' WHERE id = u;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = u) THEN
    INSERT INTO public.users(id, email, full_name) VALUES (u, 'old.468@example.com', 'T468');
  END IF;
  UPDATE auth.users SET email = 'new.468@example.com' WHERE id = u;
  SELECT email INTO v FROM public.users WHERE id = u;
  ASSERT v = 'new.468@example.com', '468 1: email not synced: ' || coalesce(v, 'null');
  ASSERT public.auth_login_resolve_email('new.468@example.com') = 'new.468@example.com', '468 2: new email does not resolve';
  ASSERT public.auth_login_resolve_email('old.468@example.com') IS NULL, '468 3: old email still resolves';
  UPDATE auth.users SET updated_at = now() WHERE id = u;
  SELECT email INTO v FROM public.users WHERE id = u;
  ASSERT v = 'new.468@example.com', '468 4: unrelated update changed email';
END $$;
ROLLBACK;
