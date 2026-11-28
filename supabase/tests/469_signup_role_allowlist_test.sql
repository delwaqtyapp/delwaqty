-- Run after 469. Synthetic fixtures, rolled back.
BEGIN;
DO $$
DECLARE v_id uuid; t text; v text;
BEGIN
  -- #374: signup metadata can never pick a privileged role
  FOREACH t IN ARRAY ARRAY['owner','admin','super_admin','country_admin','merchant_staff','OWNER','junk'] LOOP
    v_id := gen_random_uuid();
    INSERT INTO auth.users(id, email, raw_user_meta_data) VALUES (v_id, 'p.' || v_id || '@example.com', jsonb_build_object('user_type', t));
    SELECT role || '/' || user_type INTO v FROM public.users WHERE id = v_id;
    ASSERT v = 'customer/customer', '469 a: signup as ' || t || ' became ' || coalesce(v, 'null');
  END LOOP;
  FOREACH t IN ARRAY ARRAY['customer','merchant','provider','driver','delivery'] LOOP
    v_id := gen_random_uuid();
    INSERT INTO auth.users(id, email, raw_user_meta_data) VALUES (v_id, 'q.' || v_id || '@example.com', jsonb_build_object('user_type', t));
    SELECT role INTO v FROM public.users WHERE id = v_id;
    ASSERT v = t, '469 b: legit type ' || t || ' became ' || coalesce(v, 'null');
  END LOOP;

END $$;
ROLLBACK;
