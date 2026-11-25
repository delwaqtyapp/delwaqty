# Rollout runbook: session-only login (440 + 441 + auth-login-identifier + app swap)

Sequence for enabling server-side session-only login in production.
Hard order (security reviewer): **apply 440 and 441 -> deploy the function ->
smoke 200/401/429 -> only then ship a build that includes the app swap
(#60).** Every prod step requires the owner's explicit order. This
document is a checklist, NOT authorization: each write step names its
exact target, and the operator records the target (project ref, host,
database - REDACTED, never a full DSN and never any password), the SHA
and the output in the release log before and after every write.

Project refs (always explicit, never defaulted):

- prod: `--project-ref bttnlkmwhorjamzemwda`
- staging: `--project-ref adcgqoccrgauqdoplsgg`

Parts:

- PR 1 (#59): migration 440 (`auth_login_attempts`,
  `auth_login_begin` / `auth_login_finish` / `auth_login_resolve_email`,
  all service-role only) + edge function `auth-login-identifier`.
- PR 2 (#60): app sign-in routes through the function.
- #64: migration 441 removes the legacy email bridge (owner decision
  2026-11-25: no email as a login identifier - username/phone only).
  Email-shaped input resolves to NULL and is answered exactly like an
  unknown identifier; email stays for signup, reset and contact only.
- PR 3 (later release): revoke anon/authenticated EXECUTE on
  `lookup_email_by_phone` / `lookup_email_by_username`. NOT before old
  builds are gone from the wild - old builds still depend on them, and
  after the revoke the old-build fallback no longer exists.

## 0. Preconditions

- #59 and #60 merged to master with both reviewer GOs and green CI.
  Record the exact master SHA being rolled out.
- No build 13 and no release from master until the owner says so.
- Every command below carries an explicit `--project-ref`; migration
  applies use an explicit, checked DB target. Record the target
  REDACTED (project ref + host + database name only - never a full DSN,
  never credentials) plus SHA and result for each write.
- **Pending migration chain on prod (context as of writing - the
  operator MUST recheck the live migration registry and the migration
  file hashes immediately before applying; the max/count claims here
  are context, not authority):** prod registry max was 435 with
  436-439 unapplied. They must land BEFORE 440 and the app swap:
  437 then 436 (the ask-anything pair - 437 with or before 436, on the
  owner's order for that stack), then 438, then 439. 439 in particular
  is required before 440 and the app swap: the prod username index is
  still the old case-sensitive one, and the app now depends on the
  439 semantics. After this chain + 440 + 441, expect the registry
  max to be 441 (recheck live). Each apply keeps its own preflight and
  the owner's explicit order.
- **Tell the security reviewer when the prod apply is planned** so they
  can run their post-check against the live database.

## 1. Staging

1. Apply migration 440 and then 441 to the STAGING database
   (explicit staging target; record target redacted + migration SHAs).
2. Privilege audit on staging. Run all of it; an empty result is a
   FAILURE of the audit, not a green.
   a. The three functions must exist - exactly these three:

   ```sql
   SELECT p.proname::text
     FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('auth_login_begin', 'auth_login_finish', 'auth_login_resolve_email')
    ORDER BY 1;
   -- expect exactly 3 rows
   ```

   Then pin each function by IDENTITY (regprocedure signature + owner +
   security-definer flag) and by SOURCE HASH, comparing against the
   reviewed migration file - a same-named replacement with a different
   body must fail this check:

   ```sql
   SELECT p.oid::regprocedure AS signature,
          r.rolname AS owner,
          p.prosecdef,
          md5(p.prosrc) AS body_md5
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     JOIN pg_roles r ON r.oid = p.proowner
    WHERE n.nspname = 'public'
      AND p.proname IN ('auth_login_begin', 'auth_login_finish', 'auth_login_resolve_email')
    ORDER BY 1;
   -- compare signatures (argument types), owner and md5 against the
   -- values recorded when 440+441 were reviewed/applied on staging
   -- (441 changed the resolver body, so its md5 differs from 440's).
   -- Note: md5(prosrc) covers the function BODY only - the signature,
   -- owner, prosecdef, search_path and ACL checks above are what catch
   -- a same-body replacement with different properties, so keep them.
   ```

   b. Named roles via has_function_privilege (PUBLIC is NOT a role and
   must not be queried this way - it errors on PG17):

   ```sql
   SELECT p.proname,
          has_function_privilege('anon',          p.oid, 'EXECUTE') AS anon,   -- f
          has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authent, -- f
          has_function_privilege('service_role',  p.oid, 'EXECUTE') AS service -- t (helpers must work)
     FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('auth_login_begin', 'auth_login_finish', 'auth_login_resolve_email');
   ```

   c. PUBLIC (the implicit everyone-group, grantee oid 0) via
   aclexplode over the EFFECTIVE acl (default included):

   ```sql
   SELECT p.proname, a.privilege_type
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace,
     LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    WHERE n.nspname = 'public'
      AND p.proname IN ('auth_login_begin', 'auth_login_finish', 'auth_login_resolve_email')
      AND a.grantee = 0 AND a.privilege_type = 'EXECUTE';
   -- expect 0 rows
   ```

   d. Client table rights - enumerate ALL privilege types for anon,
   authenticated and PUBLIC on the table, not a sample. The aclexplode
   query shows DIRECT grants; also check EFFECTIVE rights via
   has_table_privilege (role memberships could grant more):

   ```sql
   SELECT g.rolname AS grantee, a.privilege_type
     FROM pg_class c
     JOIN pg_namespace n ON n.oid = c.relnamespace,
     LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
     LEFT JOIN pg_roles g ON g.oid = a.grantee
    WHERE n.nspname = 'public' AND c.relname = 'auth_login_attempts'
      AND (a.grantee = 0
           OR g.rolname IN ('anon', 'authenticated'));
   -- expect 0 rows

   SELECT priv,
          has_table_privilege('anon',          'public.auth_login_attempts', priv) AS anon,
          has_table_privilege('authenticated', 'public.auth_login_attempts', priv) AS authent
     FROM (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                  ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) AS v(priv);
   -- every value false

   SELECT c.relrowsecurity
     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'auth_login_attempts'; -- t

   SELECT count(*) FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'auth_login_attempts'; -- 0
   ```

   e. As corroboration only (not a substitute for the explicit checks
   above): the baseline-wide counts of security-definer functions
   executable by anon / PUBLIC must be unchanged by 440 - anon = 11,
   PUBLIC = 4. These counts MUST come from pg_proc ACLs, NOT
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
   fresh identifier buckets, so earlier attempts never pollute counts).
   Watch the shared per-IP budget (20 failures / 10 min): the full suite
   can exhaust one tester IP - use a fresh trusted egress IP per full
   run, or reset the DESIGNATED test ledger rows afterwards
   (`DELETE FROM public.auth_login_attempts WHERE identifier_key IN (<the
   exact rollout-test keys used>)` - each key listed explicitly, with
   the OWNER'S ACTUAL APPROVAL for that specific cleanup obtained
   beforehand, not a blanket delete and not a standing permission):
   - For EACH identifier class - phone and username (email is NOT a
     login identifier since 441) - do a REAL client login through the
     merged #60 app build (or the
     exact supabase-js calls it makes: `functions.invoke` +
     `auth.setSession`): expect 200, `auth.setSession` adopts the
     session, and the profile loads. This proves SDK session adoption
     end to end, not just the raw HTTP shape.
   - Biometric re-login: enroll biometrics on a fresh account, log out,
     log back in with biometrics (stored identifier + password through
     the same path).
   - Wrong password -> 401 `invalid_credentials`; unknown identifier ->
     byte-identical 401 `invalid_credentials`.
   - Email-bridge check (441): a REAL account's email + its CORRECT
     password must now FAIL with the same byte-identical 401
     `invalid_credentials` as an unknown identifier. If it succeeds,
     the rollout is a FAIL - the bridge is still open.
   - Slow-but-working GoTrue: with GoTrue artificially delayed UNDER
     the function's 5s timeout (isolated staging or a mock - NEVER
     impair a shared/prod GoTrue), a credential rejection stays 401 on
     BOTH the known- and unknown-identifier branches. Only a true
     timeout/unavailable produces 503, also identical on both branches.
   - Lockout: 5 rapid wrong-password attempts on a FRESH bucket -> the
     6th returns 429 `too_many_attempts`. Use a fresh bucket each time
     this is re-run; the bucket clears after 10 minutes.
5. **Last-XFF gate (security):** first learn the tester's true egress IP
   independently (e.g. `curl ifconfig.me`). Then exercise:
   (a) a PLAIN request with no XFF manipulation - the stored row must
       show the tester's REAL IP; two different testers (or two
       networks) must produce DIFFERENT stored values;
   (b) header omitted entirely;
   (c) a single forged entry;
   (d) multiple forged entries - in (b)-(d) ALL supplied values are
       bogus and NONE equals the real IP.
   Read the stored row in `auth_login_attempts` after each:
   - PASS: plain requests store the real, per-tester-distinct client
     IP, and no user-supplied bogus value is ever stored.
   - FAIL (rollout blocked): any user-supplied bogus value is stored
     (lockout is spoofable), OR the stored value is 'unknown' or a
     shared infrastructure address for plain requests (the function
     cannot tell clients apart - the per-IP budget becomes a global
     bucket: one attacker's 20 failures lock out EVERYONE). Unblock
     only via a trusted non-spoofable client-IP design, or the owner's
     explicit acceptance of the global-bucket behavior.
   Record stored values in the release log. This gate is repeated in
   prod (step 2.4).

## 2. Production (owner's explicit order for each step)

1. Recheck the live migration registry and file hashes (see section 0),
   then apply migrations 440 and 441 to the PROD database (explicit
   prod target; record target redacted + SHAs). Re-run the full
   privilege audit from step 1.2.
2. Deploy the function to prod:
   `supabase functions deploy auth-login-identifier --no-verify-jwt --project-ref bttnlkmwhorjamzemwda`.
3. Repeat the smoke suite from step 1.4 against prod with fresh prod
   test fixtures. Do NOT inject any GoTrue outage or delay against prod
   - outage parity is proven on staging/mocks only; on prod verify only
   that the healthy-path responses match.
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
