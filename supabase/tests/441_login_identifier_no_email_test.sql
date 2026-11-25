-- Suite for migration 441 (login identifiers: username/phone only).
-- Applied by supabase/harness/441_harness.sh AFTER 439 + 440 + 441 on a
-- throwaway clone of h435_template. Synthetic fixtures only:
-- @example.invalid emails, never real accounts.
-- DISPOSABLE-DATABASE-ONLY: auth.users fixtures persist; run on a
-- throwaway clone, never on staging or prod.

create temporary table zz441(a uuid, b uuid);
insert into zz441 select gen_random_uuid(), gen_random_uuid();
insert into auth.users(id,email)
select a, 'suite441.user@example.invalid' from zz441
union all
select b, 'suite441.other@example.invalid' from zz441;
update public.users
   set email='suite441.user@example.invalid', username='Suite441User',
       phone='01005556666', account_status='active'
 where id=(select a from zz441);
update public.users
   set email='suite441.other@example.invalid', username='Suite441Other',
       account_status='active'
 where id=(select b from zz441);

DO $$
DECLARE
  v text;
BEGIN
  -- 1) Username still resolves (case-insensitive).
  v := public.auth_login_resolve_email('suite441user');
  ASSERT v = 'suite441.user@example.invalid', format('username resolution broke: %s', v);

  -- 2) Phone spellings still resolve to the same account.
  v := public.auth_login_resolve_email('01005556666');
  ASSERT v = 'suite441.user@example.invalid', format('phone resolution broke: %s', v);
  v := public.auth_login_resolve_email('+20 100 555 6666');
  ASSERT v = 'suite441.user@example.invalid', format('intl phone resolution broke: %s', v);

  -- 3) THE 441 CHANGE: an email-shaped identifier never resolves, even
  --    for an account whose email it exactly is.
  v := public.auth_login_resolve_email('suite441.user@example.invalid');
  ASSERT v IS NULL, format('email bridge still open: %s', v);
  v := public.auth_login_resolve_email('SUITE441.USER@example.invalid');
  ASSERT v IS NULL, format('email bridge open for case variant: %s', v);

  -- 4) Unknown username / unknown phone still NULL.
  v := public.auth_login_resolve_email('no_such_user_441');
  ASSERT v IS NULL, format('unknown username resolved: %s', v);
  v := public.auth_login_resolve_email('01099999999');
  ASSERT v IS NULL, format('unknown phone resolved: %s', v);

  -- 5) Deactivated accounts never resolve (regression guard).
  UPDATE public.users SET account_status='deactivated' WHERE id=(select b from zz441);
  v := public.auth_login_resolve_email('Suite441Other');
  ASSERT v IS NULL, format('deactivated account resolved: %s', v);

  -- 6) Grants unchanged: EXECUTE stays service-role only.
  ASSERT NOT has_function_privilege('anon', 'public.auth_login_resolve_email(text)', 'EXECUTE'),
    'anon still has EXECUTE';
  ASSERT NOT has_function_privilege('authenticated', 'public.auth_login_resolve_email(text)', 'EXECUTE'),
    'authenticated still has EXECUTE';
  ASSERT has_function_privilege('service_role', 'public.auth_login_resolve_email(text)', 'EXECUTE'),
    'service_role lost EXECUTE';
END $$;

SELECT '441 suite OK' AS result;
