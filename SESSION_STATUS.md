# SESSION_STATUS.md

> **Last updated:** 2026-08-17 Session 52G — **ADB KEEPALIVE → TERMUX:Boot (MIGRATED LIVE)** — keepalive moved to an independent Termux:Boot daemon (`~/.termux/boot/keep-adb-alive-init.sh`), hook removed from `opencode-omniroute-start`, flock leak fixed (adb server was inheriting lock fd 9), dynamic uid-2000 port discovery replaces stale KNOWN_PORTS. Incident resolved: transport dropped mid-migration (dual adb binaries fighting + key mismatch) — restored on port 45417, OpenCode 200, OmniRoute alive. Report: `docs/HANDOFF/36_ADB_KEEPALIVE_TERMUX_BOOT_MIGRATION.md`.

---

## Current Task — ADB KEEPALIVE ON INDEPENDENT TERMUX:Boot LIFECYCLE (Session 52G)

**Status:** Complete — migrated live, transport healthy

### What changed this session
- **New independent daemon:** `tool/opencode/keep-adb-alive-init.sh` installed at
  `~/.termux/boot/keep-adb-alive-init.sh` — launches the loop in its own session
  (`setsid`), so the keepalive survives OpenCode / proot / OmniRoute restarts.
- **Hook removed** from `opencode-omniroute-start` (OmniRoute logic untouched).
- **flock leak fixed:** the forked adb *server* inherited lock fd 9 and held the
  flock forever. `adb()` now runs `( exec 9>&-; adb ... )` — lock stays with the
  keepalive only.
- **Dynamic port discovery:** reads phone `/proc/net/tcp[6]` uid-2000 (adbd)
  listeners via rish, decodes hex port, validates with `adb connect`. Survived a
  live rotation 34797 → 45417 and reconnected automatically.
- **Incident (resolved):** transport dropped mid-migration — dual adb binaries
  (proot v34 vs host v35) shared one 5037 server + host adb key ≠ authorized
  proot key → `offline`. Fixed: aligned host key to the authorized proot key,
  identified the real adbd listener (uid 2000, not the system uid-1000 ports).

### Verified
- Single keepalive (PID 13974, TracerPid 0, UID 10526, outside proot); old 13774 GONE.
- `adb devices` → `192.168.8.36:45417 device`; OpenCode `:4096` = 200; OmniRoute `:20128` listening.
- Report: `docs/HANDOFF/36_ADB_KEEPALIVE_TERMUX_BOOT_MIGRATION.md`.

### Root cause (diagnosed on-device)
- Wireless debugging toggle was ON (`adb_wifi_enabled=1`), but the **adb-over-Wi-Fi port is dynamic**
  (changes on every toggle/adbd restart); adbd does not register via mDNS in this PRoot, so the adb
  server kept stale `offline` transports and lost the device → `flutter run`/`adb install` broke.
- MagicOS PowerGenius / smart battery could suspend the Wi-Fi transport: `stay_on_while_plugged_in=0`,
  `wifi_sleep_policy` unset, `com.termux` not doze-whitelisted.

### Fix delivered
- **`tool/opencode/keep_adb_alive.sh`** — background loop (20s): re-asserts
  `stay_on_while_plugged_in=7` / `wifi_sleep_policy=2` / `adb_wifi_enabled=1` / doze-whitelist +
  RUN_IN_BACKGROUND for `com.termux` via Shizuku/rish (shell uid), auto-rediscovers the current
  wireless-debugging port, prunes stale `offline` transports, never kills a healthy connection.
- **Auto-start hook** in `opencode-omniroute-start` (idempotent, non-fatal, same pattern as OmniRoute).
- Verified: `flutter devices` → `DNP NX9 (mobile) • 192.168.8.36:39775 • android-arm64 • Android 16 (API 36)`.
- Docs: ADR-064 in `docs/DECISION_LOG.md`.

### Files touched
- `tool/opencode/keep_adb_alive.sh` (new)
- `.opencode-ctl/opencode-omniroute-start` (hook, outside repo)
- `docs/DECISION_LOG.md` (ADR-064)

---

## Previous Task — STEP 11: PROFILE + REGISTRATION — COMPLETE (Session 52E)

**Commit:** sprint 80: complete profile and registration flows
**Push:** origin/master (pending push)

### Completed this session
- **Migration 046 live + verified:** `supabase/migrations/046_profile_registration_roles_language.sql` (additive/idempotent, re-applied live).
- **Role registration unblocked:** `users.user_type` CHECK widened to `('customer','merchant','driver','provider','delivery')` — merchant/driver sign-up previously violated the 020 CHECK on insert.
- **Registration language persisted:** `handle_new_user()` now reads `language` from `raw_user_meta_data` (default `en`); client threads `_selectedLanguage` from register wizard → provider → usecase → repo → signUp metadata → `_persistSignUpProfile` (was hardcoded `'en'`).
- **DOB end-to-end (privacy rule):** `User`/`UserModel.dateOfBirth` (date-only, excluded from insert/update JSON — guard trigger rejects direct writes); `updateDateOfBirth` DS/repo/usecase calling the sanctioned `update_member_dob` RPC; profile edit dialog gains date picker + clear + `dateOfBirthPrivacy` note; rewards text unchanged (year-only, never raw DOB).
- **Verification integration:** admin verification queue includes `merchant`/`driver`; `pending_verification_page` gains `_buildRejected` (via new `VerificationStatus.isRejected`).
- **Tests:** +6 (3 model DOB, 2 updateDateOfBirth usecase, 1 auth language, +2 widget tests in new `pending_verification_page_test.dart` → net +6); full suite **868/868**.
- **Gate:** `flutter analyze` 0 errors on touched files, build_runner ok, `git diff --check` clean, secret scan clean, `DECISION_LOG.md` CRLF→LF normalized.

### Live probes (9/9 green)
- user_type CHECK widened · merchant insert succeeds · `handle_new_user` reads language · real trigger path (auth.users → profile row `merchant/merchant/ar/pending`) · `update_member_dob` writes DOB · direct UPDATE blocked (guard) · future date rejected · migration re-run idempotent · fixtures cleaned.

### Files modified (16 + generated)
- `lib/domain/entities/user.dart`, `lib/data/models/user_model.dart`
- `lib/domain/repositories/profile_repository.dart`, `lib/data/repositories/profile_repository_impl.dart`, `lib/data/datasources/remote/supabase_profile_data_source.dart`, `lib/domain/usecases/profile/profile_usecases.dart`
- `lib/features/profile/presentation/pages/profile_page.dart`
- `lib/domain/repositories/auth_repository.dart`, `lib/data/repositories/auth_repository_impl.dart`, `lib/data/datasources/remote/supabase_auth_data_source.dart`, `lib/domain/usecases/auth/auth_usecases.dart`, `lib/features/auth/presentation/auth_provider.dart`, `lib/features/auth/presentation/pages/register_page.dart`, `lib/features/auth/presentation/pages/pending_verification_page.dart`
- `lib/domain/enums/verification_status.dart`, `lib/data/repositories/admin_repository.dart`
- `lib/l10n/app_en.arb`, `app_ar.arb` + generated `app_localizations*.dart`
- `docs/DECISION_LOG.md` (ADR-063), `ROADMAP.md`

### Files created (2)
- `supabase/migrations/046_profile_registration_roles_language.sql`
- `test/features/auth/presentation/pages/pending_verification_page_test.dart`
- `docs/HANDOFF/STEP_11_PROFILE_REGISTRATION.md`

---

## Previous Task — STEP 10: BIRTHDAY + ANNIVERSARY REWARDS — COMMITTED (Session 52D)

**Commit `878fdc9`** + docs `2db9762` pushed: "sprint 80: implement birthday and anniversary rewards"

---

## Previous Task — STEP 9: MEMBER MANAGEMENT + SANCTIONS RPC WIRING — COMMITTED (Session 52C)

**Commit `a87b314`** + docs `2bc1a26` pushed: "sprint 80: add member management Flutter module + sanctions RPC wiring"

---

## Previous Task — STEPS 5 + 7/8: CAMPAIGN CAROUSEL + NOTIFICATION GAP WIRING — COMMITTED (Session 52A)

**Commit `6f90688`** pushed: "sprint 79: DB-driven campaign carousel + notification gap wiring"

---

## Previous Task — PHASE 2.4.1: NOTIFICATION DELIVERY LAYER — COMMITTED (Session 52)

**Commit `2bc8efb`** pushed: "sprint 78: implement notification delivery and deep links"
