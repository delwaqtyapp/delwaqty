# STEP 12 — Verification Re-apply + Login-Callback Deep Link (Sprint 80)

> **Date:** 2026-08-17 (Session 52G)
> **Commit:** PENDING (after this report)
> **Preceding audit:** `docs/HANDOFF/STEP_12_VERIFICATION_DEEP_LINK_AUDIT.md`
> **ADR:** 040 (auth deep-link allowlist), 065 (deep-link classification layer), 066 (re-apply RPCs)

---

## 1. Objective

Deliver the final two gaps from the STEP 12 audit:

1. **Verification deep-linking** — after email-confirm / OAuth return via `io.delwaqty://login-callback`,
   the app must land the member on the correct page (router redirect gates; the auth listener re-resolves
   the session). Add an allowlisted, testable classification layer as an explicit hook.
2. **Rejected → Re-apply flow** — rejected members see the admin's reason and can resubmit documents
   through a secured RPC; admins must provide a reason when rejecting (raw `/users.update` of
   `verification_status` is now blocked by the DB guard).

## 2. Backend (migration `047_verification_reapply.sql` — applied live, probe-verified)

| Migration | Contents | Grants |
|-----------|----------|--------|
| `047_verification_reapply.sql` | `users.rejection_reason` + `users.rejection_reason_at` columns; `reapply_verification(p_id_card_url, p_profile_photo_url)`; `decide_user_verification(p_user_id, p_decision, p_reason)`; `users_guard_account_fields` updated to block direct `verification_status` writes | `reapply_verification` + `decide_user_verification` → authenticated + service_role (REVOKE-before-GRANT) |

### Live verification (Management API, all `[]` clean)
- Columns exist; RPCs exist with correct signatures and grants.
- `SET ROLE authenticated` direct UPDATE is blocked (guard fires `'Verification status is managed by the
  verification RPCs'`).
- Full cycle probe: owner-reject → member-reapply → owner-approve, with notifications + audit rows
  observed; **fixture restored** (rejected member back to original state; owner unchanged).

## 3. Client — Deep Link (Phase 12.1–12.3)

| File | Role |
|------|------|
| `lib/core/deep_link/deep_link_resolver.dart` | Pure allowlist classifier: `io.delwaqty://login-callback` → `DeepLinkRoute.loginCallback`; unknown hosts / foreign schemes → `null`. |
| `lib/services/deep_link/deep_link_service.dart` | Wraps `app_links` 7.2.1: `routes` broadcast stream, `initialRoute` (cold start), injectable `overrideStream` for tests. |
| `lib/app/app.dart` | Starts the service post-frame; on `loginCallback` triggers `checkAuthStatus()` (idempotent safety net after the SDK PKCE exchange). |
| `pubspec.yaml` | `app_links: ^7.2.1` promoted from transitive to direct dependency. |

`AndroidManifest.xml` already declares the `io.delwaqty://login-callback` intent filter (lines 37–42) —
no change. supabase_flutter keeps its own `AppLinks` subscription and completes `getSessionFromUrl`;
our service never re-consumes `code`/`access_token`.

## 4. Client — Re-apply flow (Phase 12.4–12.7)

| Layer | Change |
|-------|--------|
| Entity/Model | `User`/`UserModel` + `rejectionReason` (Freezed regen via `flutter pub run build_runner`). |
| Repository IF | `ProfileRepository.reapplyVerification(...)`; data source calls `rpc('reapply_verification', ...)`. |
| Usecase | `ReapplyVerificationUseCase` + provider. |
| Page | `pending_verification_page.dart` `_buildRejected`: shows `verificationRejectionReason`, adds **Re-apply** CTA → documents flow → reapply RPC → reload user. |
| Admin repo | `approveVerification`/`rejectVerification` switched to `rpc('decide_user_verification', ...)`; `rejectVerification` now requires `reason` (abstract interface updated). |
| Admin service | `AdminService.rejectVerification` passes `reason`. |
| Admin page | `admin_verifications_page.dart`: reject opens reason prompt (`_askRejectReason`) before `ConfirmDialog`; reason is required. |
| l10n | EN + AR: `verificationRejectionReason`, `verificationRejectReasonTitle/Hint`, `reapplyVerification`, `reapplyVerificationConfirmation`, `reapplyVerificationSuccess`, `verificationReapplyFailed`. |

## 5. Tests (`flutter test` gates)

- `test/core/deep_link/deep_link_resolver_test.dart` — 5 tests (host match, query params, unknown/foreign reject).
- `test/services/deep_link/deep_link_service_test.dart` — 5 tests (stream emit, ignore foreign, idempotent start, initialRoute).
- `test/domain/usecases/profile/profile_usecases_test.dart` — +2 (reapply call + exception propagation).
- `test/features/auth/presentation/pages/pending_verification_page_test.dart` — +2 (reason display, re-apply → docs flow).
- Full gates: `dart analyze` (touched files) 0 errors/warnings (remaining `annotate_overrides` infos are
  pre-existing); affected suites → **All tests passed** (25 + 88 + 4 targeted).

## 6. Relevant Files
- `supabase/migrations/047_verification_reapply.sql`
- `lib/core/deep_link/deep_link_resolver.dart`, `lib/services/deep_link/deep_link_service.dart`
- `lib/app/app.dart`, `pubspec.yaml` / `pubspec.lock`
- `lib/domain/entities/user.dart`, `lib/data/models/user_model.dart`
- `lib/domain/repositories/profile_repository.dart`, `lib/data/repositories/profile_repository_impl.dart`
- `lib/data/datasources/remote/supabase_profile_data_source.dart`
- `lib/domain/usecases/profile/profile_usecases.dart`
- `lib/features/auth/presentation/pages/pending_verification_page.dart`
- `lib/features/admin/{domain/repositories,data}"` — `admin_repository.dart` (abstract + impl)
- `lib/services/admin/admin_service.dart`, `lib/features/admin/presentation/pages/admin_verifications_page.dart`
- `lib/l10n/app_en.arb`, `app_ar.arb` (+ generated `app_localizations*.dart`)

## 7. Remaining Work / Next
- (none blocking) — commit + push; SESSION_STATUS + ROADMAP updated in this milestone.
- Future: notification `deep_link` allowlist route for `/pending-verification` could drive a router entry
  if cold-start push-navigation is ever required (currently router redirect handles gating).