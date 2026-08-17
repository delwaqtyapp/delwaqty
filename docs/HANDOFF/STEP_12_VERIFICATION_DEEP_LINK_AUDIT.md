# STEP 12 — Verification Deep-Linking + Rejected Re-Apply Flow: Architecture Audit (Phase 12.0)

> **Date:** 2026-08-17 (Session 52H)
> **Status:** Audit complete → implementation next
> **Scope from STEP_11_HANDOFF:** wire `io.delwaqty://login-callback` / email-confirm deep links to a real in-app handler, and let a rejected user re-submit documents (with admin re-review) instead of only a static rejected screen.

---

## 1. Objective

Verify every layer that participates in the verification deep link and the rejected
re-apply flow, then produce a grounded design before touching any code:

1. How does an email-confirm / login callback deep link reach the app and complete auth?
2. Where is the verification state stored, who may change it, and how does the router gate it?
3. What primary/secondary data does the admin queue read, and what is missing to support a re-apply cycle?
4. Where is the rejected user stranded today, and what backend/client pieces must exist so a rejected user can resubmit documents and be re-reviewed?

---

## 2. Backend audit (live probes via `oneq.py` — all green)

### 2.1 Canonical verification state lives on `public.users`

| Column | Type | Notes |
|--------|------|-------|
| `users.user_type` | text | `customer` \| `provider` \| `delivery` \| `merchant` \| `driver` (CHECK, widened by 046) |
| `users.verification_status` | text | CHECK `('pending','approved','rejected')`, default `approved` (020) |
| `users.id_card_url` / `profile_photo_url` | text | document URLs in `profiles` storage bucket (020) |
| `users.role` | text | merchant/driver/provider/delivery/customer/admin/owner (020) |
| `users.account_status` | text | moderation lifecycle (035) |

- `handle_new_user()` (021, rewritten by 046) is **authoritative** at sign-up: reads
  `user_type`, `verification_status`, `full_name`, `language` from `raw_user_meta_data`.
  Provider/delivery/merchant/driver → `verification_status='pending'`; customer → `approved`.
- DB trigger — not the client — derives identity at signup. Client `_persistSignUpProfile`
  is a no-op for provider/delivery (session withheld until email confirm), so the trigger is
  the only guaranteed write on that path.

### 2.2 Who may write verification status today

`public.users` RLS (live):

| Policy | CMD | Qual/With-check |
|--------|-----|-----------------|
| Users can insert own profile | INSERT | `(auth.uid() = id)` |
| Users can update own profile | UPDATE | `(auth.uid() = id)` |
| Users can view own profile | SELECT | `(auth.uid() = id)` |
| `users_select_admin` | SELECT | `is_admin()` |
| `users_update_admin` | UPDATE | `is_admin()` |

- Admin approve/reject today is a **direct `UPDATE users SET verification_status`**
  (client `admin_repository.dart:878-905`) relying on `users_update_admin` (RLS `is_admin()`).
- `users_guard_account_fields()` (035) blocks authenticated direct writes to
  `role` / `account_status` / `date_of_birth` / `anonymized_at` — it does **not**
  guard `verification_status`. A *rejected* user can therefore already flip their own
  `verification_status` back to `pending` with a plain authenticated UPDATE. That is the
  existing (unstructured, unlogged) path for "re-apply" — it must be replaced by a logged RPC.

### 2.3 Admin queue

- Client `getVerificationRequests()` (`admin_repository.dart:843-875`): `SELECT users
  WHERE verification_status='pending' AND user_type IN (provider,delivery,merchant,driver)`,
  ordered by `created_at` desc. `VerificationRequest` carries `userId/email/fullName/phone/
  userType/idCardUrl/profilePhotoUrl/createdAt`.
- Server `list_members()` (044) also exposes `verification_status` and is region-scoped via
  `has_permission('MEMBER_VIEW', _member_region_id(uid))`. Not used by the verification queue.
- **No `rejection_reason` / review-decision history on `users`.** The workflow keeps no
  record of who rejected, when, or why. `approval_requests` (generic approval table with
  reasons/decision) is **not** wired to user verification (`_valid_approval_type` covers
  admin/campaign/member/reward/offer types only).

### 2.4 Notifications infrastructure (relevant to a re-review callback)

- `notifications` table has a `deep_link` column; `decide_approval_request()` already sends
  `type='approval'` notifications with `deep_link='/admin/approvals'`.
- Push path: `notifications.notify_notification_push` → `_enqueue_push()` →
  `dispatch_push()` (FCM); token lifecycle RPCs (`register_device_token`,
  `refresh_token_heartbeat`, `deactivate_stale_tokens`) exist.
- `notification_destinations` is the in-app deep-link allowlist (route patterns) — does NOT
  currently include a verification landing route.

### 2.5 Storage

- `profiles` bucket: public, 5 MB, png/jpeg/webp; INSERT policy `bucket_id='profiles' AND
  auth.role()='authenticated'`. Documents are `userId/documents/*` uploads via
  `supabase_profile_data_source.uploadFile(folder: 'documents')`.
- The same bucket guarantees the rejected user can re-upload new ID/photo — RLS allows any
  authenticated user to upload into it. No policy change required for re-apply.

---

## 3. Client audit (code inspection)

### 3.1 Auth state machine — no `AuthRejected`

`auth_state.dart` (freezed): `initial | loading | authenticated | guest | unauthenticated |
phoneVerificationRequired | emailConfirmationRequired | pendingVerification | error`.

- `auth_provider._resolveAuthenticated(User)` → `AuthPendingVerification` whenever
  `user.userType.requiresVerification && !user.verificationStatus.isApproved`.
- **A rejected user resolves to `AuthPendingVerification`** (the enum has no rejected variant),
  which the router sends to `/pending-verification`; the page branches on
  `user.verificationStatus.isRejected` to render the static rejected card.
- No `refreshProfile`; closest is `checkAuthStatus()` (re-reads session + full user from DB).

### 3.2 Router

`lib/core/router/app_router.dart` (`goRouterProvider`, Provider):

- `initialLocation: '/splash'`; `refreshListenable` = `ValueNotifier` bumped by
  `authStateProvider` changes; `redirect()` gates by auth state.
- Pending-verification audience is diverted: `isVerificationPending && !isVerificationPendingRoute
  && !isAuthRoute → '/pending-verification'`.
- Route registry: `FeatureRegistry` modules; `/pending-verification` registered in
  `auth_module.dart`.
- **No `deepLinkBuilder`, `initialDeepLink`, `uriStrategy`, or inbound-URI handling.** Supabase's
  PKCE email-confirm flow is completed by `supabase_flutter` internally when the deep link
  launches the activity; the router then picks up the session change via its listenable.

### 3.3 Manifest / auth config

- `AndroidManifest.xml:37-42` already declares the `VIEW` intent-filter:
  `scheme=io.delwaqty host=login-callback`, BROWSABLE+DEFAULT, on `MainActivity` (singleTop).
- Auth config (live, ADR-040): `site_url` + `uri_allow_list` = `io.delwaqty://login-callback`.
  Confirmation links open the app; SDK PKCE exchanges the code and completes the session.
- `supabase_auth_data_source` passes `redirectTo: 'io.delwaqty://login-callback'` on OAuth
  sign-ins (Google/Apple/Facebook paths remain, currently unused).

### 3.4 Rejected user surface today (the gap)

`pending_verification_page.dart`:

- `_buildRejected`: icon + `verificationRejectedTitle/Message` + logout. **Static. No re-submit
  button, no reason shown, no admin re-review loop.**
- `_buildDocumentsFlow` + `_submitDocuments`: uploads ID photo + profile photo via
  `uploadDocumentUseCaseProvider` then `updateProfileUseCase` writing `id_card_url` and
  `profile_photo_url`. This is the exact upload UX the rejected re-apply flow must reuse,
  but **submitting documents does not change verification status** (stays `rejected`), so
  admin queue never sees the applicant again.

---

## 4. Gap list (implementation scope of Step 12)

| # | Gap | Required fix |
|---|-----|--------------|
| G1 | No explicit in-app deep-link handler for `io.delwaqty://login-callback` | Add a `DeepLinkHandler` (allowlist scheme/host, param validation) that: (a) records the pending URI, (b) lets the app react after session resolution (e.g. route to verification landing), (c) is unit-testable without platform channels |
| G2 | Rejected → re-apply has no user-facing path | Rejected surface gains a "Re-apply" action reusing the documents flow; after upload the user must trigger a *logged* status transition back to `pending` |
| G3 | `verification_status` flips one-way; no re-apply RPC; no rejection reason | New migration adds `users.rejection_reason` + `users.rejection_reason_at` + a SECURITY DEFINER RPC `reapply_verification(p_id_card_url, p_profile_photo_url)` (validates caller owns the row, requires current status `rejected`, sets `pending`, clears reason, writes audit) |
| G4 | Admin re-review shows no reason | `VerificationRequest` + admin page display rejection reason when present; admin decision path unchanged (approve/reject), but reject should persist the reason (via new RPC or column update) |
| G5 | Auth `AuthState` conflates rejected with pending | Not required for gating (both route to pend-verification), but the *page* must distinguish rejected (add reason + re-apply) from pending (review-only / docs). Keep enum as-is; branch on user |
| G6 | No regression coverage for the new handler/flow | Unit + widget tests mirroring the profile-edit pattern (mocktail); no full-suite hangs on device |

---

## 5. Proposed design (Phase 12.1–12.9, subject to DECISION_LOG ADR-065)

### Phase 12.1 — `DeepLinkHandler` (core service)

- New `lib/services/deep_link/deep_link_service.dart`: parses inbound URIs, allowlists
  scheme `io.delwaqty`, host `login-callback` (+ optional verification path for future use),
  rejects everything else; exposes the pending URI to the router.
- No new dependency: consume the URI stream the platform hands to `MainActivity`; the SDK
  already consumes PKCE. Handler is testable with plain `Uri` fixtures.

### Phase 12.2 — Router integration

- `goRouterProvider` gains `initialDeepLink` wiring that consults the pending URI once on
  cold start (after auth resolves) and navigates to the verification landing when a pending
  login-callback is present; otherwise keeps current `/splash` → redirect behavior.

### Phase 12.3 — Android intent filter

- Verify the existing `io.delwaqty://login-callback` filter stays; **no change expected**
  (already declared). Add `android:autoVerify` only if moving to HTTPS app links (out of scope).

### Phase 12.4 — Migration `047_verification_reapply.sql`

- Add `users.rejection_reason TEXT`, `users.rejection_reason_at TIMESTAMPTZ`.
- `reapply_verification(p_id_card_url text, p_profile_photo_url text) RETURNS void`,
  SECURITY DEFINER: `auth.uid()` owns the row, current status `rejected`, sets `pending`,
  writes doc URLs, clears reason, `write_audit('VERIFICATION_REAPPLIED','users',id,...)`.
- `decide_user_verification(p_user_id uuid, p_decision text, p_reason text) RETURNS void`,
  SECURITY DEFINER: `is_admin()`, approve → `approved`, reject → `rejected` + reason; both
  `write_audit` + `INSERT notifications (type='verification', deep_link=...)`.

### Phase 12.5 — Repository/usecase layer

- `profile_repository` + impl: `reapplyVerification(userId, idCardUrl, profilePhotoUrl)`
  calling the RPC; surfaced as `reapplyVerificationUseCaseProvider`.

### Phase 12.6 — Rejected re-apply UI

- `_buildRejected` gains "Re-apply" → flows into `_buildDocumentsFlow` in resubmit mode;
  after successful uploads, invokes the re-apply usecase, then `checkAuthStatus()` →
  router lands on review-only PendingVerification.

### Phase 12.7 — Admin reason capture

- Admin verification card shows `rejection_reason` if present; reject action prompts for a
  reason and calls `decide_user_verification(..., 'reject', reason)`.

### Phase 12.8 — l10n (en/ar)

- New keys for re-apply CTA, reason prompt, reason display, status labels.

### Phase 12.9 — Tests + docs + gate

- Unit tests: `DeepLinkHandler` fixtures; `reapplyVerification` usecase; reason mapping.
- Widget tests: rejected page shows re-apply; documents resubmit triggers RPC.
- Migration applied live + probes; `flutter analyze`/targeted tests; commit/push + reports.

---

## 6. Relevant files

Backend:
- `supabase/migrations/020_user_verification.sql`, `021_signup_type_flow.sql`, `046_...sql`
- `public.users` RLS + `users_guard_account_fields()` (035)
- Notifications infra (041, 043) + `approval_requests`/`decide_approval_request`

Client:
- `lib/core/router/app_router.dart`
- `lib/features/auth/domain/auth_state.dart`, `lib/features/auth/presentation/auth_provider.dart`
- `lib/features/auth/presentation/pages/pending_verification_page.dart`
- `lib/features/auth/auth_module.dart`
- `lib/data/repositories/admin_repository.dart`, `lib/features/admin/domain/entities/admin_models.dart`
- `lib/data/repositories/profile_repository_impl.dart`, `lib/domain/usecases/profile/profile_usecases.dart`
- `lib/services/supabase/supabase_initializer.dart`, `lib/main.dart`
- `android/app/src/main/AndroidManifest.xml`
- `lib/l10n/app_en.arb` / `app_ar.arb`

---

## 7. Next move

1. Apply `047_verification_reapply.sql` live + probe (RLS, RPC guards, audit, notification rows).
2. Implement Phase 12.1–12.3 (deep-link handler + router + manifest verify) with tests.
3. Implement Phase 12.5–12.8 (repo/usecase, re-apply UI, admin reason, l10n).
4. Full regression (targeted), live probes, `docs/DECISION_LOG` ADR-065, ROADMAP update,
   `SESSION_STATUS.md`, commit+push.