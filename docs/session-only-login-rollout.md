# Rollout runbook: session-only login (440 + auth-login-identifier + app swap)

Sequence for enabling server-side session-only login in production.
Hard order (security reviewer): **apply 440 -> deploy the function ->
smoke 200/401/429 -> only then ship a build that includes the app swap
(#60).** Every prod step requires the owner's explicit order. This
document is a checklist, NOT authorization: each write step names its
exact target, and the operator records target + SHA + output in the
release log before and after every write.

Project refs (always explicit, never defaulted):

- prod: `--project-ref bttnlkmwhorjamzemwda`
- staging: `--project-ref adcgqoccrgauqdoplsgg`

Parts:

- PR 1 (#59): migration 440 (`auth_login_attempts`,
  `auth_login_begin` / `auth_login_finish` / `auth_login_resolve_email`,
  all service-role only) + edge function `auth-login-identifier`.
- PR 2 (#60): app sign-in routes through the function.
- PR 3 (later release): revoke anon/authenticated EXECUTE on
  `lookup_email_by_phone` / `lookup_email_by_username`. NOT before old
  builds are gone from the wild - old builds still depend on them, and
  after the revoke the old-build fallback no longer exists.

## 0. Preconditions

- #59 and #60 merged to master with both reviewer GOs and green CI.
  Record the exact master SHA being rolled out.
- No build 13 and no release from master until the owner says so.
- Every command below carries an explicit `--project-ref`; migration
  applies use an explicit, checked DB target (direct connection string
  or pooler session DSN for THAT project, echoed and confirmed before
  running). Record target, SHA and result for each write.
- **Pending migration chain on prod:** the prod registry max is 435;
  436-439 are unapplied. They must land BEFORE 440 and the app swap:
  437 then 436 (the ask-anything pair - 437 with or before 436, on the
  owner's order for that stack), then 438, then 439. 439 in particular
  is required before 440 and the app swap: the prod username index is
  still the old case-sensitive one, and the app now depends on the
  439 semantics. After this chain + 440, the prod registry shows 440
  as its max. Each apply keeps its own preflight and the owner's
  explicit order.
- **Tell the security reviewer when the prod apply is planned** so they
  can run their post-check against the live database.

## 1. Staging

1. Apply migration 440 to the STAGING database (explicit staging target;
   record target + migration SHA).
2. Privilege audit on staging - each of the 3 new functions x each of
   anon / authenticated / PUBLIC must be false, the table must have no
   client rights, and RLS must be on with no policies:

   ```sql
   SELECT p.proname,
          has_function_privilege('anon',          p.oid, 'EXECUTE') AS anon,
          has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated,
          has_function_privilege('PUBLIC',        p.oid, 'EXECUTE') AS public
     FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('auth_login_begin', 'auth_login_finish', 'auth_login_resolve_email');
   -- every value false

   SELECT has_table_privilege('anon',          'public.auth_login_attempts', 'SELECT') AS anon_sel,
          has_table_privilege('authenticated', 'public.auth_login_attempts', 'SELECT') AS auth_sel,
          has_table_privilege('anon',          'public.auth_login_attempts', 'INSERT') AS anon_ins;
   -- all false

   SELECT relrowsecurity FROM pg_class WHERE relname = 'auth_login_attempts'; -- t
   SELECT count(*) FROM pg_policies WHERE tablename = 'auth_login_attempts';  -- 0
   ```

   As corroboration only (not a substitute for the explicit checks
   above): the baseline-wide counts of security-definer functions
   executable by anon / PUBLIC must be unchanged by 440 - anon = 11,
   PUBLIC = 4. NOTE: these counts must come from pg_proc ACLs, NOT
   information_schema.routine_privileges (which expands role
   memberships and reports inflated numbers - 801/4162 on prod):

   ```sql
   SELECT count(*) FROM pg_proc
    WHERE prosecdef AND proacl::text ~ '(^|\{|,)anon=X';  -- expect 11
   SELECT count(*) FROM pg_proc
    WHERE prosecdef AND proacl::text ~ '(^|\{|,)=X/';     -- expect 4 (PUBLIC)
   ```

3. Deploy the function to staging:
   `supabase functions deploy auth-login-identifier --no-verify-jwt --project-ref adcgqoccrgauqdoplsgg`
   (`--no-verify-jwt`: a caller at login time has no session JWT.)
   Record the deployed function version.
4. Smoke on staging, with FRESH fixtures per run (new test accounts and
   fresh identifier buckets, so earlier attempts never pollute counts):
   - For EACH identifier class - phone, username, legacy real email -
     do a REAL client login through the merged #60 app build (or the
     exact supabase-js calls it makes: `functions.invoke` +
     `auth.setSession`): expect 200, `auth.setSession` adopts the
     session, and the profile loads. This proves SDK session adoption
     end to end, not just the raw HTTP shape.
   - Biometric re-login: enroll biometrics on a fresh account, log out,
     log back in with biometrics (stored identifier + password through
     the same path).
   - Wrong password -> 401 `invalid_credentials`; unknown identifier ->
     byte-identical 401 `invalid_credentials`.
   - Parity under stress: repeat wrong-password once with GoTrue
     artificially slow/unavailable where the environment allows -
     unknown and known identifiers must both degrade to the SAME
     controlled response (503 `temporarily_unavailable`), never a 401.
   - Lockout: 5 rapid wrong-password attempts on a FRESH bucket -> the
     6th returns 429 `too_many_attempts`. Use a fresh bucket each time
     this is re-run; the bucket clears after 10 minutes.
5. **Last-XFF gate (security):** first learn the tester's true egress IP
   independently (e.g. `curl ifconfig.me`). Then send requests whose
   `x-forwarded-for` values are ALL bogus and NONE equals that real IP:
   (a) header omitted entirely, (b) a single forged entry,
   (c) multiple forged entries. Read the stored row in
   `auth_login_attempts` after each:
   - If the platform edge appends the true client IP, the stored value
     is the REAL IP (or 'unknown' when the platform strips it) - a
     user-supplied bogus value must NEVER be stored.
   - If any user-supplied bogus value is stored, the gate FAILS: stop
     the rollout, lockout bucketing is spoofable, design needs review.
   Record stored values in the release log. This gate is repeated in
   prod (step 2.4).

## 2. Production (owner's explicit order for each step)

1. Apply migration 440 to the PROD database (explicit prod target;
   record target + SHA). Re-run the full privilege audit from step 1.2.
2. Deploy the function to prod:
   `supabase functions deploy auth-login-identifier --no-verify-jwt --project-ref bttnlkmwhorjamzemwda`.
3. Repeat the smoke suite from step 1.4 against prod with fresh prod
   test fixtures.
4. Repeat the last-XFF gate from step 1.5 against prod. A fail stops the
   rollout before any app ships.
5. Exercise the REAL WhatsApp password-reset flow end to end on a test
   account (request code, receive it, complete the reset) - it must be
   untouched by this change (it never used the lookup RPCs, and the
   point is proving the neighboring auth surface still works, not just
   the OTP request).

## 3. Ship the app

Only after steps 1 and 2 are fully green: build and release the apps
including #60 (build 13 or later, on the owner's order). Old builds
keep working until part 3 - they still use the lookup RPCs.

## 4. Part 3, one release later

After old builds are gone from the wild (store rollout state / minimum
supported version confirms it): migration revoking anon and
authenticated EXECUTE on `lookup_email_by_phone` and
`lookup_email_by_username` (service_role keeps its grant). Both GOs and
green CI as usual; prod apply on the owner's order. NOTE: after this
revoke the old-build fallback is gone - there is no going back to
pre-#60 builds.

## 5. Incidents, containment and cleanup (honest labels)

- **Emergency disable (outage containment, NOT a rollback):**
  `supabase functions delete auth-login-identifier --project-ref <ref>`.
  New (#60) builds then fail closed with the stable "temporarily
  unavailable" message; pre-#60 builds still work via the lookup RPCs
  (until part 3's revoke - after that, disabling the function breaks
  ALL builds' password login). This buys time; it does not restore a
  previous state.
- **Redeploy:** keep the last-known-good function artifact (the exact
  `index.ts` at the rolled-out SHA) so a known-good version can be
  redeployed at any time. "Rollback" for the function means redeploying
  that artifact, never deleting.
- **Mobile releases do not roll back installed clients.** A bad app
  release is answered by shipping a FIXED release (or the emergency
  disable above), not by "reverting" the store listing - users keep
  what is on their phones.
- **Migration 440 is never a rollback target.** Dropping
  `auth_login_attempts` or the three functions is destructive cleanup,
  not rollback: it loses the audit/lockout ledger and breaks the
  deployed function. Do it only as a separate, explicit decision with
  an export/retention answer for the ledger and the owner's explicit
  approval during a declared outage or decommissioning. If that cleanup
  is ever approved, delete the FUNCTION first - a function left running
  without its table answers every login attempt with 503.

## 6. Monitoring after enable

- `auth_login_attempts`: failure-volume spikes or single-IP floods mean
  the lockout is doing its job - or that a client bug is hammering
  login; check before raising any limit.
- 503 rate from the function: 503s are deliberately distinct from 401s.
  A sustained 503 rate is a GoTrue/Postgres availability problem OR an
  abuse pattern (an attacker indifferent to answers can still force
  work) - check GoTrue health first, then look at bucket distributions.
- Lockout complaints: buckets clear after 10 minutes; the per-IP budget
  (20/10 min) can bite shared networks (universities, cafes) - expect
  occasional 429s there.
