-- Run after migration 158. Fixtures and rows roll back.
-- Admin moderation can delete reviews; customers cannot delete any review.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid();
  o uuid := gen_random_uuid();
  adm uuid := gen_random_uuid();
  mer uuid := gen_random_uuid();
  rev uuid := gen_random_uuid();
  rev2 uuid := gen_random_uuid();
  v_blocked boolean;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(o,o::text||'@example.invalid'),(adm,adm::text||'@example.invalid');
  INSERT INTO public.users(id,email,role) VALUES
    (c,c::text||'@example.invalid','customer'),(o,o::text||'@example.invalid','merchant'),
    (adm,adm::text||'@example.invalid','admin')
    ON CONFLICT(id) DO NOTHING;
  UPDATE public.users SET role='admin' WHERE id=adm;
  INSERT INTO public.admin_management(admin_id, supervisor_id, is_active) VALUES (adm, o, true);
  INSERT INTO public.merchants(id, owner_user_id, name) VALUES (mer, o, 'Rev Fixture');
  INSERT INTO public.reviews(id, user_id, merchant_id, rating, comment)
    VALUES (rev, c, mer, 1, 'fixture one'), (rev2, c, mer, 5, 'fixture two');

  -- admin deletes a review
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  PERFORM set_config('role','authenticated',true);
  DELETE FROM public.reviews WHERE id = rev;
  IF EXISTS (SELECT 1 FROM public.reviews WHERE id = rev) THEN
    RAISE EXCEPTION 'admin delete failed';
  END IF;

  -- customer cannot delete reviews (even own)
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  v_blocked := false;
  BEGIN
    DELETE FROM public.reviews WHERE id = rev2;
    IF NOT EXISTS (SELECT 1 FROM public.reviews WHERE id = rev2) THEN
      RAISE EXCEPTION 'customer deleted own review';
    END IF;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
END $$;
ROLLBACK;
