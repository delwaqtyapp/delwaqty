# TECHNICAL_DEBT.md

> **Generated:** 2026-07-16 | **Sprint:** 11.5

---

## Current Debt

### Critical — Must Fix Before Production

#### TD-001: Overly Permissive RLS Policies
- **Location:** `supabase/migrations/001_initial_schema.sql`
- **Impact:** 12 of 29 RLS policies use `USING (true)` — no access control
- **Tables affected:**
  - `admin_users` — ALL 4 policies use `USING (true)` (any user can CRUD admin accounts)
  - `activity_logs` — INSERT unrestricted (audit trail poisoning)
  - `platform_settings` — UPDATE unrestricted (anyone can toggle maintenance)
  - `order_items` — SELECT unrestricted (cross-user data leak)
  - `merchants`, `products`, `categories`, `reviews`, `coupons` — SELECT public (intentional but verify)
- **Fix:** Replace `USING (true)` with `auth.uid()` checks or role-based policies
- **Effort:** 2-4 hours
- **Risk:** Data breach if deployed as-is

#### TD-002: Database Schema Not Deployed
- **Location:** `supabase/migrations/001_initial_schema.sql`
- **Impact:** All Supabase-backed features return 404
- **Fix:** Run SQL in Supabase Dashboard SQL Editor
- **Effort:** 5 minutes (manual)
- **Risk:** Blocks all backend integration

#### TD-003: Mock-Only Repositories
- **Location:** `lib/data/repositories/mock/` (8 files), `lib/data/repositories/` (6 files)
- **Impact:** No persistent data. All state lost on app restart.
- **Fix:** Replace mock implementations with Supabase-backed repositories
- **Effort:** 2-3 days
- **Risk:** High — core functionality depends on real data

### High — Fix Before Sprint 12

#### TD-004: No Authentication Flow Wired
- **Location:** `lib/features/auth/` + `lib/services/authentication/`
- **Impact:** Cannot register or login real users
- **Fix:** Wire auth pages to `AuthService` with Supabase Auth
- **Effort:** 1-2 days
- **Risk:** Core feature gap

#### TD-005: Missing Firebase Configuration
- **Location:** `android/app/` (missing `google-services.json`)
- **Impact:** No push notifications, no analytics, no crash reporting
- **Fix:** Create Firebase project, add config files
- **Effort:** 1 hour (manual setup)
- **Risk:** No production monitoring

#### TD-006: Missing Google Maps API Key
- **Location:** `.env.dev` (empty `GOOGLE_MAPS_API_KEY`)
- **Impact:** Map views, delivery tracking, geofencing non-functional
- **Fix:** Get API key from Google Cloud Console
- **Effort:** 30 minutes (manual setup)
- **Risk:** Delivery feature gap

### Medium — Fix During Sprint 12-14

#### TD-007: 8 Deprecated `withOpacity()` Calls
- **Location:**
  - `lib/features/admin/presentation/pages/admin_dashboard_page.dart:214`
  - `lib/features/admin/presentation/pages/admin_merchants_page.dart:102,103,118,119`
  - `lib/features/admin/presentation/pages/admin_orders_page.dart:119,146`
  - `lib/features/admin/presentation/pages/admin_users_page.dart:244`
- **Impact:** Deprecation warnings, will break in future Flutter versions
- **Fix:** Replace `color.withOpacity(x)` with `color.withValues(alpha: x)`
- **Effort:** 15 minutes
- **Risk:** Future breakage

#### TD-008: 11 `avoid_print` Lint Suppressions
- **Location:**
  - `lib/services/analytics/analytics_service_impl.dart` (8 suppressions)
  - `lib/services/logging/logging_service_impl.dart` (3 suppressions)
- **Impact:** `print()` calls produce output in release builds (info-leak, performance)
- **Fix:** Replace `print()` with `AppLogger` calls
- **Effort:** 30 minutes
- **Risk:** Minor info-leak in release builds

#### TD-009: 48 Outdated Dependencies
- **Location:** `pubspec.yaml`
- **Impact:** Missing security patches, performance improvements, new features
- **Major upgrades needed:**
  - Riverpod 2.x → 3.x (breaking API changes)
  - GoRouter 14.x → 17.x (breaking API changes)
  - Freezed 2.x → 3.x (breaking API changes)
  - Firebase Core 2.x → 4.x (breaking API changes)
- **Fix:** Upgrade one major dependency at a time, fix breaking changes
- **Effort:** 2-3 days per major upgrade
- **Risk:** Breaking changes require code modifications

#### TD-010: No Test Coverage Report
- **Location:** CI config (`flutter test --coverage`)
- **Impact:** Cannot quantify test coverage percentage
- **Fix:** Generate lcov report, upload to codecov or coveralls
- **Effort:** 1 hour
- **Risk:** Unknown coverage gaps

### Low — Fix During Sprint 15+

#### TD-011: 162 Info-Level Lint Warnings
- **Location:** Various files (see `flutter analyze` output)
- **Impact:** Minor style inconsistencies
- **Fix:** Batch-fix in dedicated cleanup sprint
- **Effort:** 2-3 hours
- **Risk:** None

#### TD-012: 1 TODO Comment
- **Location:** `lib/features/welcome/presentation/pages/welcome_page.dart:100`
- **Content:** `// TODO: Implement guest mode`
- **Impact:** Feature gap
- **Fix:** Implement guest mode or remove TODO
- **Effort:** 1 hour
- **Risk:** None

#### TD-013: Missing `.gitignore` Entries
- **Location:** `.gitignore`
- **Missing:**
  - `*.p12` / `*.pem` (iOS signing certificates)
  - `google-services.json` (preemptive)
  - `GoogleService-Info.plist` (preemptive)
- **Fix:** Add entries to `.gitignore`
- **Effort:** 5 minutes
- **Risk:** Low (files not present yet)

---

## Future Debt

### Sprint 12-14: Admin Backend
- AdminRepository needs real Supabase implementation
- RLS policies must be hardened before admin features work
- Activity logging needs proper auth checks

### Sprint 15: AI Core
- AI engine interface defined but no implementation
- No AI provider configured (OpenAI/Gemini/Claude)
- No rate limiting for AI API calls

### Sprint 16: Payments
- Payment gateway integration not started
- No PCI compliance framework
- No transaction idempotency

### Sprint 17: Search
- Search engine interface defined but no implementation
- No full-text search index
- No search analytics

### Sprint 19-20: Chat
- No WebSocket infrastructure
- No message encryption
- No chat persistence

---

## Refactoring Opportunities

### R-001: Commerce Module Decomposition
- **Current:** 66 files in `lib/features/commerce/`
- **Proposed:** Split into `commerce_merchant`, `commerce_product`, `commerce_cart`, `commerce_order` sub-modules
- **Benefit:** Easier navigation, clearer boundaries
- **When:** When file count exceeds 80

### R-002: Service Layer Consolidation
- **Current:** 3 separate logger services (`app_logger.dart`, `logging_service.dart`, `logger/`)
- **Proposed:** Single `LoggerService` with multiple sinks (console, file, remote)
- **Benefit:** Reduced duplication, consistent logging
- **When:** Sprint 14

### R-003: Config Class Unification
- **Current:** Separate config classes for each service (CloudflareConfig, FirebaseConfig, MapsConfig, SupabaseConfig)
- **Proposed:** Single `AppConfig` class with nested config objects
- **Benefit:** Single source of truth, easier environment switching
- **When:** Sprint 14

### R-004: Error Handling Standardization
- **Current:** Mixed error handling (try-catch, Result types, Failure classes)
- **Proposed:** Standardize on `Either<Failure, T>` pattern from dartz or similar
- **Benefit:** Consistent error propagation, better testability
- **When:** Sprint 15

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| RLS breach in production | High (if deployed as-is) | Critical | Fix RLS before any deployment |
| Dependency upgrade breakage | Medium | High | Upgrade one at a time, test thoroughly |
| Data loss (no backups) | Medium | High | Configure Supabase automated backups |
| API key exposure | Low | Critical | Verify .gitignore, rotate keys if needed |
| Performance degradation at scale | Medium | Medium | Add caching layer before scaling |
| Missing auth = no user data | High | High | Wire auth flow in Sprint 12 |

---

## Priority Matrix

| Priority | Debt Items | Sprint |
|----------|------------|--------|
| Critical | TD-001, TD-002, TD-003 | Before Sprint 12 |
| High | TD-004, TD-005, TD-006 | Sprint 12 |
| Medium | TD-007, TD-008, TD-009, TD-010 | Sprint 12-14 |
| Low | TD-011, TD-012, TD-013 | Sprint 15+ |
| Future | R-001, R-002, R-003, R-004 | Sprint 14+ |
