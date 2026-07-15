# Next Tasks

## Priority: Critical
*Must be done before any new feature work.*

### 1. Implement deleteUser() or Remove from Interface
**File:** `lib/data/repositories/user_repository_impl.dart`
**Impact:** Misleading API — callers expect functionality that doesn't exist
**Effort:** 15 minutes (remove) or 1 hour (implement)

**Recommended:** Remove `deleteUser()` from `UserRepository` interface and `UserRepositoryImpl` until account deletion is actually needed.

### 2. Surface Supabase Init Failure
**File:** `lib/main.dart:42-44`
**Impact:** App runs without backend connectivity, leading to confusing auth errors
**Effort:** 30 minutes

Show a user-facing error screen instead of silently continuing without backend.

---

## Priority: High
*Should be done before Phase 2 feature work.*

### 3. Build Profile Page
**Impact:** Core user feature
**Effort:** 1-2 days

- Profile view with user info
- Edit profile form
- Avatar upload with image picker
- Profile state management provider

### 4. Build Real Home Page
**Impact:** Replaces placeholder, provides value
**Effort:** 1 day

- Dashboard or main content based on user role
- Pull-to-refresh
- Loading and error states

### 5. Add Provider Tests for Auth Flow
**Impact:** Confidence in critical auth logic
**Effort:** 1 day

- Test `AuthStateNotifier` state transitions
- Mock repositories and use cases
- Test signIn/signUp/signOut/resetPassword flows

### 6. Create .env.example
**Impact:** Developer onboarding
**Effort:** 10 minutes

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

---

## Priority: Medium
*Should be done during Phase 3.*

### 7. Wire handleException() into All Repositories
**Impact:** Consistent error handling across all repos
**Effort:** 1 hour

Currently `handleException()` is only used in the auth provider. Wire it into profile and user repositories for consistent error mapping.

### 8. Add Widget Tests for Reusable Components
**Impact:** Confidence in UI components
**Effort:** 2 days

- `AppButton` — all variants, loading state, expanded mode
- `AppTextField` — validation, obscure text toggle
- `AppShell` — navigation, logout dialog

### 9. Implement Pagination
**Impact:** Required for any list feature
**Effort:** 1 day

- Create pagination entities (re-add PaginatedResult)
- Implement cursor-based or offset pagination
- Create reusable pagination widget/provider

### 10. Wire FCM Service
**Impact:** Push notification support
**Effort:** 1 day

- Initialize in `main.dart` after Supabase init
- Handle token refresh
- Handle foreground/background messages

---

## Priority: Low
*Can be done during Phase 4-5.*

### 11. Add Integration Tests for Auth Flow
**Impact:** End-to-end confidence
**Effort:** 2 days

### 12. Add ProGuard/R8 Rules
**Impact:** Android release build security
**Effort:** 30 minutes

### 13. Create Contributing Guidelines
**Impact:** Team onboarding
**Effort:** 30 minutes

### 14. Add Crash Reporting
**Impact:** Production visibility
**Effort:** 1 day

### 15. Add Analytics
**Impact:** User behavior insights
**Effort:** 1 day

---

## Task Dependencies

```
1 (deleteUser) ──────────────────────────┐
2 (supabase init) ───────────────────────┤
6 (.env.example) ────────────────────────┤
                                         ↓
3 (profile page) ──→ 7 (wire error handling)
4 (home page)    ──→ 5 (auth tests)
                                         ↓
                                   8-10 (Phase 3 work)
                                         ↓
                                  11-15 (Phase 4-5 work)
```

**Critical path:** Tasks 1-2 should be completed before Phase 2. Tasks 3-6 are Phase 2 deliverables.
