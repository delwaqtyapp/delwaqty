# Rollout runbook: session-only login (440 + auth-login-identifier + app swap)

Sequence for enabling server-side session-only login in production.
Hard order (security reviewer): **apply 440 -> deploy the function ->
smoke 200/401/429 -> only then ship a build that includes the app swap
(#60).** Every prod step requires the owner's explicit order.

Parts:

- PR 1 (#59): migration 440 (`auth_login_attempts`,
  `auth_login_begin` / `auth_login_finish` / `auth_login_resolve_email`,
  all service-role only) + edge function `auth-login-identifier`.
- PR 2 (#60): app sign-in routes through the function.
- PR 3 (later release): revoke anon/authenticated EXECUTE on
  `lookup_email_by_phone` / `lookup_email_by_username`. NOT before old
  builds are gone from the wild.

## 0. Preconditions

- #59 and #60 merged to master with both reviewer GOs and green CI.
- No build 13 and no release from master until the owner says so.
- Supabase CLI access for project `bttnlkmwhorjamzemwda` (prod) and
  `adcgqoccrgauqdoplsgg` (staging).

## 1. Staging

1. Apply migration 440 to staging.
2. Grant audit on staging - anon and authenticated must have NOTHING
   new. Expected posture matches the prod baseline counts: functions
   executable by anon = 11, by PUBLIC = 4 (the 440 functions are
   service-role only and must not change either count):

   ```sql
   SELECT count(*) FROM information_schema.routine_privileges
    WHERE grantee = 'anon' AND privilege_type = 'EXECUTE';   -- expect 11
   SELECT count(*) FROM information_schema.routine_privileges
    WHERE grantee = 'PUBLIC' AND privilege_type = 'EXECUTE'; -- expect 4
   ```

   And specifically:

   ```sql
   SELECT has_function_privilege('anon', 'public.auth_login_begin(text,text)', 'EXECUTE'),      -- f
          has_function_privilege('authenticated', 'public.auth_login_resolve_email(text)', 'EXECUTE'), -- f
          has_table_privilege('anon', 'public.auth_login_attempts', 'SELECT');                    -- f
   ```

3. Deploy the function to staging:
   `supabase functions deploy auth-login-identifier --no-verify-jwt`
   (`--no-verify-jwt`: a caller at login time has no session JWT).
4. Smoke on staging:
   - Known account, right password -> 200 with
     `access_token`/`refresh_token` and NO `user` object, NO standalone
     email anywhere in the body.
   - Same account, wrong password -> 401 `invalid_credentials`.
   - Unknown username -> identical 401 `invalid_credentials`
     (compare bodies byte for byte).
   - 6 rapid wrong-password attempts -> the 6th returns 429
     `too_many_attempts`.
5. **Last-XFF check (security gate):** call the staging function with a
   forged `x-forwarded-for: 1.2.3.4, <real client IP>` header, then read
   the row in `auth_login_attempts`: the stored `ip` must be the REAL
   client IP (the trusted last hop), not `1.2.3.4`. If the platform's
   edge does not append the true client IP, the lockout buckets by the
   forged value and the design must be revisited BEFORE prod.

## 2. Production (owner's explicit order for each step)

1. Apply migration 440 to prod. Re-run the grant audit from step 1.2
   (anon = 11, PUBLIC = 4, all three 440 checks false).
2. Deploy the function to prod with `--no-verify-jwt`.
3. Repeat the smoke suite from step 1.4 against prod (one known test
   account; count its lockout row afterwards so the tester's own bucket
   does not surprise them - failures clear after 10 minutes anyway).
4. Verify the OTP and password-reset flows are untouched (they never
   used the lookup RPCs): request a WhatsApp OTP on a test account.

## 3. Ship the app

Only after 1 and 2 are green: build and release the apps including #60
(build 13 or later, on the owner's order). Old builds keep working -
they still use the lookup RPCs, which stay live until part 3.

## 4. Part 3, one release later

After old builds are gone from the wild (check the app's minimum
supported version / store rollout state): migration revoking anon and
authenticated EXECUTE on `lookup_email_by_phone` and
`lookup_email_by_username` (keep service_role: the edge function's
resolver does not use them, but internal tooling might). Both GOs and
green CI as usual; prod apply on the owner's order.

## 5. Rollback

- App problem after release: the previous build still works (lookup
  RPCs untouched) - roll back the release, keep the function deployed.
- Function problem: `supabase functions delete auth-login-identifier`
  makes the NEW builds fail closed (stable "temporarily unavailable"
  message, no credential or email exposure) while old builds are
  unaffected. Redeploy when fixed.
- 440 rollback (only if the migration itself misbehaves): drop the
  three functions and `auth_login_attempts`. Safe any time: nothing
  reads the table except the function.

## 6. Monitoring after enable

- `auth_login_attempts`: sudden failure-volume spikes or single-IP
  floods mean the lockout is doing its job - or that a client bug is
  hammering login; check before raising limits.
- 503 rate from the function: availability failures are deliberately
  distinct from 401s; a sustained 503 rate is a GoTrue/Postgres problem,
  not an attack.
- Lockout complaints: buckets clear after 10 minutes; the per-IP budget
  (20/10 min) can bite shared networks (universities, cafes) - expect
  occasional 429s there.
