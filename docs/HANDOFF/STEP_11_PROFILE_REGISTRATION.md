# HANDOFF: Step 11 — Profile + Registration (customer/provider/driver)

**Commit:** (sprint 80: complete profile and registration flows)
**Date:** 2026-08-17
**Gate:** 868/868 tests, 0 analyzer errors, live DB probes green

---

## What was delivered

### 1. Migration 046 — `supabase/migrations/046_profile_registration_roles_language.sql` (live, deployed, idempotent)

| Gap found | Fix |
|---|---|
| `users.user_type` CHECK (migration 020) allowed only `customer/provider/delivery`, but the register wizard and `UserType` enum register `merchant` and `driver` — every such sign-up violated the CHECK on insert | Widen `users_user_type_check` to `('customer','merchant','driver','provider','delivery')` (same vocabulary `users.role` already allows) |
| `handle_new_user()` hardcoded `language='en'` even though the register wizard step 2 collects ar/en | Read `language` from `raw_user_meta_data` (default `en`); applies to both the email-confirmation trigger path and any metadata-backed signup |

No new tables, no new RPCs, no ACL surface change. **DOB was already fully wired DB-side** (migration 035: `users.date_of_birth` + `users_guard_account_fields` trigger + `update_member_dob` RPC granted to authenticated) — Step 11 connects the client to it.

### 2. Date-of-birth (privacy rule enforced)

| Layer | Change |
|---|---|
| `User` / `UserModel` | New `dateOfBirth` field (date-only); `fromSupabase` parses `date_of_birth`; deliberately **excluded** from `toInsertJson`/`toUpdateJson` (guard trigger rejects direct writes) |
| `SupabaseProfileDataSource` | `updateDateOfBirth(userId, dateOfBirth)` → calls the sanctioned RPC `update_member_dob(p_date_of_birth, p_member_id)` then re-fetches the profile |
| `ProfileRepository` (+ impl) | `updateDateOfBirth` |
| `ProfileUsecases` | `updateDateOfBirthUseCaseProvider` |
| `profile_page.dart` | Edit dialog gains a **date picker** (1900 → today), clear action, and an explicit **privacy note** (`dateOfBirthPrivacy`) |
| Rewards text | Unchanged and already compliant: renders only a derived **year** from the reward `period_key`, never the raw DOB |

**Privacy contract:** DOB is stored via the single sanctioned writer, editable by the owner, and never shown raw in rewards text.

### 3. Registration role flows + language

- **Role registration unblocked:** merchant/driver sign-up (4-role wizard) now passes the DB CHECK (migration 046).
- **Language end-to-end:** register page `_selectedLanguage` (default `ar`) → `AuthStateNotifier.signUp(language)` → `SignUpUseCase` → `AuthRepositoryImpl` → `_auth.signUp(data: {..., 'language': ...})`; client-side `_persistSignUpProfile` now uses the passed language instead of hardcoded `'en'`. Both the session path and the email-confirmation trigger path persist the same preference.

### 4. Verification integration

- `admin_repository.dart` `getVerificationRequests` filter widened from `['provider','delivery']` to include `merchant` + `driver`.
- `pending_verification_page.dart` gains `_buildRejected` (visible when `verificationStatus.isRejected`) — a rejected user is no longer stuck on the upload/review loop.
- `VerificationStatus` gains `isRejected`.

---

## Live verification (all probes green)

| # | Probe | Result |
|---|---|---|
| 1 | `users_user_type_check` widened | ✅ `('customer','merchant','driver','provider','delivery')` |
| 2 | Insert `merchant`/`merchant`/`pending` row | ✅ succeeds (was CHECK-violating) |
| 3 | `handle_new_user()` reads `language` from metadata | ✅ function def shows `v_language` with `en` default |
| 4 | Real trigger path: insert `auth.users` with `user_type=merchant` + `language=ar` | ✅ profile row created with `role=merchant, user_type=merchant, language=ar, verification_status=pending` |
| 5 | `update_member_dob('1990-05-14', member)` | ✅ `date_of_birth` written |
| 6 | Direct `UPDATE users SET date_of_birth=...` | ✅ blocked by guard for `authenticated`/`anon` (service_role/system exempt by design) |
| 7 | `update_member_dob` with future date | ✅ rejected (`Date of birth cannot be in the future`) |
| 8 | Migration re-run → idempotent | ✅ |
| 9 | Fixtures cleaned (public + auth) | ✅ 0 remaining |

---

## Test results

| Suite | Count | Status |
|---|---|---|
| Full suite (`flutter test`) | **868/868** | ✅ |
| New/changed tests | `user_model_test` (+3 DOB), `profile_usecases_test` (+2 updateDateOfBirth), `auth_usecases_test` (language), `pending_verification_page_test` (NEW, 2 widget tests: rejected + review-only) | ✅ |

---

## Analyzer / gate

- `flutter analyze`: **0 errors**; touched files issue-free (project-wide infos remain pre-existing)
- `flutter pub run build_runner build`: succeeded
- `git diff --check`: clean
- Secret scan: clean
- One-time normalization: `docs/DECISION_LOG.md` CRLF → LF (matches other markdown; eliminates `git diff --check` trailing-whitespace failures)

---

## Owner verification (unchanged, re-confirmed)

| Field | Value |
|---|---|
| Email | `said.3pkarino@gmail.com` |
| UID | `8a23b719-a923-4a18-bd6e-04972097fb4b` |
| Role | `owner` |
| Authorization path | `users.role` + admin hierarchy + `has_permission()` + RLS/RPC — no hardcoded auth bypass |

---

## Files touched

**Modified:**
- `lib/domain/entities/user.dart` (+ generated `user.freezed.dart` / `user.g.dart`)
- `lib/data/models/user_model.dart`
- `lib/domain/repositories/profile_repository.dart`
- `lib/data/repositories/profile_repository_impl.dart`
- `lib/data/datasources/remote/supabase_profile_data_source.dart`
- `lib/domain/usecases/profile/profile_usecases.dart`
- `lib/features/profile/presentation/pages/profile_page.dart`
- `lib/domain/repositories/auth_repository.dart` / `lib/data/repositories/auth_repository_impl.dart`
- `lib/data/datasources/remote/supabase_auth_data_source.dart`
- `lib/domain/usecases/auth/auth_usecases.dart`
- `lib/features/auth/presentation/auth_provider.dart`
- `lib/features/auth/presentation/pages/register_page.dart`
- `lib/features/auth/presentation/pages/pending_verification_page.dart`
- `lib/domain/enums/verification_status.dart`
- `lib/data/repositories/admin_repository.dart`
- `lib/l10n/app_en.arb` / `app_ar.arb` (+ generated `app_localizations*.dart`)
- `docs/DECISION_LOG.md` (ADR-063), `ROADMAP.md`, `SESSION_STATUS.md`

**Created:**
- `supabase/migrations/046_profile_registration_roles_language.sql`
- `test/features/auth/presentation/pages/pending_verification_page_test.dart`

---

## Next step

**Step 12 — Verification deep-linking + rejected re-apply flow:** wire `io.delwaqty://login-callback` / email-confirm deep links to a real in-app handler, and let a rejected user re-submit documents (with admin re-review) instead of only a static rejected screen.
