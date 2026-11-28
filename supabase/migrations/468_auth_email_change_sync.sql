-- 468: keep public.users.email in step with auth.users.email.
-- GoTrue only changes auth.users.email after the NEW mailbox confirmed the
-- change link (secure email change). Until now nothing copied that to
-- public.users, so login-by-email (auth_login_resolve_email) kept resolving
-- the OLD address. This trigger copies it. It runs inside GoTrue's own
-- transaction: if public.users.email would collide it raises, so the
-- change rolls back instead of leaving the two tables disagreeing.
-- Re-runnable.
CREATE OR REPLACE FUNCTION public.sync_auth_email_to_public_users()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.email IS NOT NULL AND NEW.email IS DISTINCT FROM OLD.email THEN
    UPDATE public.users SET email = NEW.email WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.sync_auth_email_to_public_users() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS sync_auth_email_to_public_users ON auth.users;
CREATE TRIGGER sync_auth_email_to_public_users
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_auth_email_to_public_users();
