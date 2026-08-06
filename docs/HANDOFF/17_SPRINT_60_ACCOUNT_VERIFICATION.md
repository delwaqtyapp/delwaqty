# Sprint 60 — Account Verification / Approval Workflow

**Date:** 2026-08-06 · **Branch:** master (uncommitted) · **Session:** 21p

## Feature

Providers and delivery users must verify their identity before using the platform. Customers are approved instantly. Registration now has 4 steps (account type → info → preferences → confirmation); provider/delivery sign-ups upload an ID card + profile photo, land on a `pending-verification` page, and stay there until an admin approves or rejects them from a new dashboard page. Email confirmation is enabled and confirmation links open the app.

## What shipped this session

### Code (finishing uncommitted work)

- **Lint cleanup** on the new code: `@override` on `getVerificationRequests`/`approveVerification`/`rejectVerification`; `DecoratedBox` instead of decoration-only `Container`; `const SizedBox`; removed redundant `radius` arg + its now-unused `AppSpacing` import; `Switch.activeColor` → `activeThumbColor`.
- **BOM artifact removed** from the top of `lib/features/auth/presentation/auth_provider.dart` (invisible U+FEFF that had been introduced at file start).
- **Pending-verification page rewritten** (`pending_verification_page.dart`) from `ConsumerWidget` → `ConsumerStatefulWidget`: loads the current user, shows an ID-card + profile-photo upload flow for users missing documents (calls `uploadDocument` then `updateProfileUseCaseProvider`), and a review-only state when documents already exist. New `uploadDocument` seam across profile repository + `UploadDocumentUseCase` (+ tests).

### Live database (`bttnlkmwhorjamzemwda`)

- **Migration `020_user_verification.sql` — APPLIED live**:
  1. `ALTER TABLE users` adds `user_type TEXT NOT NULL DEFAULT 'customer'`, `verification_status TEXT NOT NULL DEFAULT 'approved'`, `id_card_url TEXT`, `profile_photo_url TEXT` (+ `user_type`/`verification_status` CHECK constraints).
  2. `users_role_check` dropped and recreated to allow `'provider'`, `'delivery'`, `'owner'` — required because `_persistSignUpProfile` writes `role = userType.code`.
  3. Admin RLS on `users`: `users_select_admin` (SELECT) + `users_update_admin` (UPDATE) via the existing `public.is_admin()` helper (016). `GRANT SELECT, UPDATE ... TO authenticated`.
  4. Guarantees the public `profiles` storage bucket exists + `authenticated upload to profiles bucket` policy.
- **Migration `021_signup_type_flow.sql` — APPLIED live**: rewrites `handle_new_user()` to derive role/user_type/verification_status from `raw_user_meta_data` (defaults customer/approved; provider|delivery/pending) instead of hardcoding `role='customer'` + `DO NOTHING` — the root cause that collapsed provider/delivery sign-ups into customer rows once email confirmation strips the session before the client-side upsert. Also backfills orphaned auth users, reconciles previously-broken provider/delivery rows, and preserves the owner account. Verified rows: `cyfyfuf@gmail.com` → provider/pending; customers stay customer/approved; owner role preserved.
- **Email confirmation verified + deep-link config**: live GoTrue already `mailer_autoconfirm: false` (confirmations ON). Set `site_url` **and** `uri_allow_list` to `io.delwaqty://login-callback` so confirmation links open the app; supabase_flutter's default PKCE flow completes the session (deep link already declared in AndroidManifest). Note: `uri_allow_list` is a **comma-separated string** in the Management API (an array body returns HTTP 400). Built-in mailer used; free-tier `rate_limit_email_sent=2`/hour (429 beyond that).

## Feature anatomy (from the uncommitted work)

| Layer | Files |
|-------|-------|
| Domain enums | `lib/domain/enums/user_type.dart`, `lib/domain/enums/verification_status.dart` (+ `test/domain/enums/auth_enums_test.dart`) |
| Models | `UserModel`/`User` + generated: `userType`, `verificationStatus`, `idCardUrl`, `profilePhotoUrl`; `fromSupabase` falls back to customer/approved |
| Auth | `AuthState.pendingVerification`; `_resolveAuthenticated` gate; register page 4-step flow + document pickers; `_persistSignUpProfile` uploads to `profiles` bucket then upserts; email-confirmation dialog localized |
| Routing | `/pending-verification` route + router redirect for non-approved provider/delivery; `PendingVerificationPage` (upload + review states) |
| Admin | `AdminVerificationsPage` (`/admin/verifications`, dashboard quick action), zoomable doc preview, approve/reject; `verificationRequestsProvider`; `AdminService`/`AdminRepository` methods |
| Platform | AndroidManifest CAMERA/READ_MEDIA_IMAGES/READ_EXTERNAL_STORAGE; Info.plist camera/photo/location usage strings |
| Home | Ride tile removed from Home grid; Home Services re-indexed |

## Rationale

Gating at the auth-state level (not per screen) means the rule holds on splash, deep links, and guest flows. Storing the gate on the existing `users` row (safe defaults) avoids historical-row migration. Admin RLS reuses the ADR-026 `is_admin()` pattern. Identity derivation belongs in the DB trigger (the only code that runs on every signup regardless of email-confirmation state), and the confirmation link must return to the app via `site_url` — see `docs/DECISION_LOG.md` ADR-039 + ADR-040.

## Quality Gates

- `flutter analyze` — **0 errors** (remaining output is pre-existing info lints).
- `flutter test` — **556/556 passing** (was 542 → +14 new tests).
- `flutter pub get` — ✅ clean.
- Debug APK rebuilt + installed on DNP NX9 (`flutter build apk --debug --dart-define-from-file=.env.dev` → `flutter install --debug`).

## Files Changed

- New: `supabase/migrations/020_user_verification.sql`, `supabase/migrations/021_signup_type_flow.sql`, `lib/domain/enums/{user_type,verification_status}.dart`, `lib/features/admin/presentation/pages/admin_verifications_page.dart`, `lib/features/auth/presentation/pages/pending_verification_page.dart`, `test/domain/enums/auth_enums_test.dart`.
- Edited (session): `lib/data/repositories/admin_repository.dart`, `lib/features/admin/presentation/pages/admin_verifications_page.dart`, `lib/features/auth/presentation/pages/register_page.dart`, `lib/features/auth/presentation/auth_provider.dart`, profile repository + `UploadDocumentUseCase`, l10n (documents-section keys).
- Edited (from prior uncommitted work): user/auth/admin models, data sources, repositories, providers, routers, l10n, manifest/plist, home page, dashboard, tests.
- Docs: `SESSION_STATUS.md` (session 21p + M13k), `ROADMAP.md` (sprint 60 row + status), `docs/DECISION_LOG.md` (ADR-039 + ADR-040).

## Next

1. **On-device E2E on DNP NX9** (needs the user): register as provider → tap the confirmation email link (opens the app) → land on pending page → upload ID + photo → admin approves in `/admin/verifications` → provider can enter home. Free-tier email budget is 2/hour.
2. **Commit + push** the Sprint 60 milestone + sprint report.
3. **Security:** the Supabase Personal Access Token used to apply the migrations must be revoked after use.
