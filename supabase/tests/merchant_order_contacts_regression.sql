-- Run after migration 159. Fixtures and rows roll back.
-- Merchants get name+phone for customers of THEIR orders only.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid();
  o uuid := gen_random_uuid();
  o2 uuid := gen_random_uuid();
  mer uuid := gen_random_uuid();
  mer2 uuid := gen_random_uuid();
  ord uuid := gen_random_uuid();
  v_cnt int;
  v_blocked boolean;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(o,o::text||'@example.invalid'),(o2,o2::text||'@example.invalid');
  INSERT INTO public.users(id,email,role,full_name,phone) VALUES
    (c,c::text||'@example.invalid','customer','Fixture Customer','01000000001'),
    (o,o::text||'@example.invalid','merchant',null,null),
    (o2,o2::text||'@example.invalid','merchant',null,null)
    ON CONFLICT(id) DO NOTHING;
  -- auth sync trigger pre-creates users rows; set contact fields explicitly
  UPDATE public.users SET full_name='Fixture Customer', phone='01000000001' WHERE id=c;
  UPDATE public.users SET role='merchant' WHERE id IN (o, o2);
  INSERT INTO public.merchants(id, owner_user_id, name)
    VALUES (mer, o, 'Contact Store A'), (mer2, o2, 'Contact Store B');
  INSERT INTO public.orders(id, user_id, merchant_id, status, payment_status,
      payment_method, subtotal, total_amount)
    VALUES (ord, c, mer, 'pending', 'pending', 'cash', 50, 65);

  -- owning merchant sees the contact
  PERFORM set_config('request.jwt.claim.sub', o::text, true);
  PERFORM set_config('role','authenticated',true);
  EXECUTE 'SELECT count(*) FROM public.merchant_order_contacts($1) WHERE order_id = $2 AND full_name = ''Fixture Customer'' AND phone = ''01000000001'''
    INTO v_cnt USING mer, ord;
  IF v_cnt <> 1 THEN RAISE EXCEPTION 'owning merchant cannot see customer contact'; END IF;

  -- other merchant refused
  PERFORM set_config('request.jwt.claim.sub', o2::text, true);
  v_blocked := false;
  BEGIN
    PERFORM public.merchant_order_contacts(mer);
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'other merchant read contacts'; END IF;

  -- customer refused
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  v_blocked := false;
  BEGIN
    PERFORM public.merchant_order_contacts(mer);
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer read merchant contacts'; END IF;
END $$;
ROLLBACK;
