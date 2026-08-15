# Sprint 75 — Biometric Final Hardening (Phase 1)

**Date:** 2026-08-15
**Status:** Complete (code-gate passed; commit/push pending user approval)

---

## Summary

Phase 1 hardening of the biometric login system: stale stored credentials are now invalidated
**event-driven** (on the first failed `signInWithEmail` after a biometric unlock), all invalidation
flows converge on a **single centralized method**, account deletion wipes local biometric
credentials, the login-page biometric flag refreshes after auth-state changes, and the flow is
covered by 9 new focused tests (603/603 total).

## What changed

### 1. Centralized invalidation — single source of truth
`AuthStateNotifier.invalidateBiometricCredentials({required String userId})`
(`lib/features/auth/presentation/auth_provider.dart`) is now THE method every invalidation path
calls. It:
1. Deletes the encrypted credential (`clearForUser` → `auth_biometric_<userId>`),
2. Clears the active-user key when it matches,
3. Resets `users.is_biometric_enabled = false` in the DB **when authenticated**,
4. (UI state + auto-retry prevention follow automatically — the button is driven by
   `hasAnyCredentials()` and the splash by `activeCredentials()`, both empty after step 1).

### 2. Event-driven stale-credential invalidation (no timers)
- `login_page.dart`: `_authenticateWithBiometric()` records `_pendingBiometricUserId` before
  calling `signIn(...)`. If the resulting auth state is `error`, the listener calls the centralized
  invalidation for that exact user, re-runs `_checkBiometric()` (hides the button), and shows the
  new `biometricStaleCredentials` message. Manual login failures are untouched.
- `splash_page.dart`: when biometric auto-login fails (`AuthError`/`AuthUnauthenticated`), the
  credential is invalidated through the centralized method and a re-login message is shown before
  navigating to `/login`.

### 3. Account deletion clears local credentials
`AuthStateNotifier.deleteAccount()` now captures the authenticated user id before clearing state and
calls `clearForUser(userId)` after a successful deletion, so no biometric secret (or active-user
marker) survives a deleted account.

### 4. `_checkBiometric()` refresh
The login-page error listener re-invokes `_checkBiometric()` after any biometric sign-in failure so
the fingerprint button state reflects the (now-empty) store instead of stale widget state.

### 5. Logout preserved by design
`signOut()` still does NOT touch biometric credentials (intentional: enrollment survives logout so
the next login can use biometrics). Verified by a new test.

### 6. Localization
New key `biometricStaleCredentials` (EN + AR), regenerated via `flutter gen-l10n`.

## Tests added (+9 → 603/603)

| Scenario | Location |
|----------|----------|
| Stale stored password → sign-in failure → invalidation clears it | `auth_provider_test.dart` |
| Auth rejection after biometric unlock → invalidate + state reset | `auth_provider_test.dart` |
| Stale-credential invalidation (cred, active key, index) | `biometric_auth_store_test.dart` |
| Biometric state reset after invalidation (no auto-login remnants) | `biometric_auth_store_test.dart` |
| Biometric button hidden after invalidation | `login_page_test.dart` (new) |
| Re-enrollment after invalidation | `biometric_auth_store_test.dart` |
| Account deletion clears local creds | `auth_provider_test.dart` |
| Logout preserves enrollment | `auth_provider_test.dart` |
| Password change clears enrollment (centralized, server flag off) | `auth_provider_test.dart` |
| No auth loop after invalidation (empty store ⇒ no retry) | `biometric_auth_store_test.dart` |

## Gate results

- `flutter analyze` → **0 errors**, 543 issues (24 warning + 519 info — **unchanged baseline**;
  no new issues in any touched file)
- `flutter test --no-pub --concurrency=2` → **603/603 passed** (was 594; +9 new)

## Files touched

- `lib/features/auth/presentation/auth_provider.dart` — centralized invalidation + account-deletion cleanup
- `lib/features/auth/presentation/pages/login_page.dart` — event-driven stale handling + `_checkBiometric` refresh
- `lib/features/splash/presentation/pages/splash_page.dart` — stale auto-login handling via centralized method
- `lib/features/settings/presentation/pages/privacy/change_password_page.dart` — delegates to centralized method
- `lib/l10n/app_en.arb`, `app_ar.arb` + generated `app_localizations*.dart` — `biometricStaleCredentials`
- `test/data/datasources/local/biometric_auth_store_test.dart` — 4 new store tests
- `test/features/auth/presentation/auth_provider_test.dart` — 4 new notifier tests
- `test/features/auth/presentation/pages/login_page_test.dart` — new (widget: button hidden post-invalidation)

## Design notes / decisions

- **Event-driven, not timer-based:** invalidation fires only when Supabase rejects the stored
  credentials; there is no periodic password-validation sweep (per requirement).
- **Server flag best-effort in the unauthenticated stale case:** after a failed biometric sign-in
  there is no session, so `is_biometric_enabled` cannot be reset remotely. This is safe — local
  credential deletion is what gates biometric login, and the flag is reset on the next
  authenticated invalidation path (password change). Documented in ADR-048.
- **No new storage:** the password remains exclusively inside `flutter_secure_storage`; nothing is
  logged, and no new credentials copies were introduced.
- **Not done in this sprint:** no commit/push (explicit user instruction), no Supabase changes, no
  device verification (DNP-NX9 not required per instruction), and no work on the later phases
  (Emergency Chat, Notifications, Regional System, Admin Hierarchy).

## Next steps

1. User review + approval → commit (`sprint 75: harden biometric stale credential invalidation`) + push.
2. Device-only verification (sensor prompt, stale-password scenario on a real phone) when desired.
3. Proceed to Phase 2 only after approval.
