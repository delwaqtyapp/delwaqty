# INTEGRATION_STATUS.md

> **Last updated:** 2026-07-16

---

## Authentication

| Provider | Status | Notes |
|----------|--------|-------|
| Email/Password | Complete | Full pipeline: domain → data → Supabase GoTrue |
| Phone OTP | Complete | `signInWithOtp` → `verifyOTP` (sms) |
| Google OAuth | Complete | `signInWithOAuth` with redirect callback |
| Apple OAuth | Complete | `signInWithOAuth` with redirect callback |
| Anonymous | Complete | `signInAnonymously` |
| Password Reset | Complete | `resetPasswordForEmail` |
| Session Persistence | Complete | Supabase handles token storage |
| Auth State Listener | Complete | Auto-refresh on `onAuthStateChange` |
| Token Refresh | Complete | Auto-refresh via auth state listener |
| Delete Account | Complete | Calls `delete-user` edge function |

**Files modified:**
- `lib/domain/repositories/auth_repository.dart` — 7 new methods, AuthResult expanded, AuthEvent model
- `lib/data/datasources/remote/supabase_auth_data_source.dart` — 7 new Supabase methods
- `lib/data/repositories/auth_repository_impl.dart` — 7 new implementations, auth state mapping
- `lib/domain/usecases/auth/auth_usecases.dart` — 5 new use cases (phone, OTP, Google, Apple, anonymous, delete)
- `lib/features/auth/domain/auth_state.dart` — added `phoneVerificationRequired` state
- `lib/features/auth/presentation/auth_provider.dart` — 7 new methods, auth listener lifecycle
- `lib/app/app.dart` — auth listener start/stop

---

## Supabase Database

| Component | Status | Notes |
|-----------|--------|-------|
| Schema | Blocked | Requires Dashboard SQL Editor action |
| Tables (14) | Blocked | users, merchants, products, orders, etc. |
| RLS Policies (29) | Blocked | 12 need hardening (`USING (true)`) |
| Indexes (16) | Blocked | Composite + GIN indexes |
| Storage Buckets | Blocked | Products, avatars, documents |
| Edge Functions | Blocked | delete-user, notifications |
| Realtime | Blocked | Order tracking, driver location |

**Action required:**
1. Open https://supabase.com/dashboard/project/bttnlkmwhorjamzemwda/sql/new
2. Paste contents of `supabase/migrations/001_initial_schema.sql`
3. Execute
4. Verify all 14 tables created

---

## Google Maps

| Component | Status | Notes |
|-----------|--------|-------|
| API Key | Blocked | Required from Google Cloud Console |
| Maps SDK | Not started | Waiting for API key |
| Places | Not started | |
| Directions | Not started | |
| Distance Matrix | Not started | |
| Navigation | Not started | |
| Geocoding | Not started | |
| Tracking | Not started | |

**Credentials required:** Google Maps API key with Maps SDK, Places, Directions, Distance Matrix enabled.

---

## Firebase

| Component | Status | Notes |
|-----------|--------|-------|
| Project Setup | Blocked | Requires Firebase Console access |
| google-services.json | Blocked | Required for Android |
| Cloud Messaging | Not started | |
| Analytics | Not started | |
| Crashlytics | Not started | |
| Performance | Not started | |
| Remote Config | Not started | |
| App Check | Not started | |

**Credentials required:** Firebase project + `google-services.json` for Android.

---

## Cloudflare

| Component | Status | Notes |
|-----------|--------|-------|
| Account Setup | Blocked | Requires Cloudflare account |
| CDN | Not started | |
| Images | Not started | |
| R2 Storage | Not started | |
| Cache | Not started | |
| DNS | Not started | |
| Workers | Not started | |
| Edge Functions | Not started | |

**Credentials required:** Cloudflare account ID, API token, R2 bucket credentials.

---

## Verification

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors, 0 warnings |
| `flutter test` | 443/443 passing |
| `flutter build apk --debug` | Build successful |
| GitHub sync | Pending commit |

---

## Credentials Required

| Service | Credential | Status |
|---------|-----------|--------|
| Supabase | DB schema deployment | Manual action required |
| Google Maps | API key | Not provided |
| Firebase | google-services.json | Not provided |
| Cloudflare | Account + API token | Not provided |

---

## Next Action

1. Deploy Supabase DB schema (manual)
2. Harden RLS policies
3. Obtain Google Maps API key
4. Obtain Firebase credentials
5. Obtain Cloudflare credentials
