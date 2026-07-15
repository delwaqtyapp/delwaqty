# Roadmap

## Phase 1: Foundation Stabilization ✅
**Status:** Complete
**Duration:** Completed

- [x] Clean Architecture setup (Domain/Data/Presentation/Core)
- [x] Material 3 theming (light/dark)
- [x] Arabic/English localization
- [x] Riverpod DI with provider overrides
- [x] GoRouter with auth shell route
- [x] Reusable UI components
- [x] Auth flow (Login, Register, Forgot Password)
- [x] Supabase data sources and repository implementations
- [x] Unit tests for utilities (51 tests, all passing)
- [x] `flutter analyze` → 0 issues

---

## Phase 1.5: Sprint 1 — Bug Fixes & Dead Code Cleanup ✅
**Status:** Complete
**Duration:** Completed

### Bugs Fixed
- [x] Fix `watchProfile()` StreamController memory leak
- [x] Implement `refreshSession()` using Supabase's `refreshSession()` API
- [x] Fix `_signIn` getter shadow warning in `auth_provider.dart`

### Dead Code Removed
- [x] Remove unused Dio infrastructure (`dio_client.dart`, `api_interceptor.dart`, `network_info.dart`)
- [x] Remove unused `connectivity_plus` from pubspec.yaml
- [x] Remove unused `riverpod_annotation` from pubspec.yaml
- [x] Remove unused `riverpod_generator` from pubspec.yaml
- [x] Remove unused `dio` from pubspec.yaml
- [x] Remove unused `handleException()` DioException tests
- [x] Remove unused shared widgets (`ResponsiveLayout`, `EmptyStateWidget`, `AppLoading`)
- [x] Remove unused `Helpers` class in `utils/helpers.dart`
- [x] Remove unused `PaginatedResult` and `PaginationParams` entities

### Infrastructure Added
- [x] Wire `handleException()` into auth provider for typed error mapping
- [x] Improve GoRouter rebuild performance with `refreshListenable`
- [x] Remove Dio dependency from `error_handler.dart`

---

## Phase 2: Core Feature Development
**Status:** Pending
**Priority:** High
**Duration:** 2-3 weeks

### Profile Feature
- [ ] Profile page (view/edit profile)
- [ ] Avatar upload with image picker
- [ ] Profile completion flow
- [ ] Profile state management (Riverpod provider)

### Home Feature
- [ ] Real home page content (replace placeholder)
- [ ] Dashboard or main screen based on user role
- [ ] Pull-to-refresh functionality

### Settings Feature
- [ ] User account settings (change email, password)
- [ ] Notification preferences
- [ ] App version and build info
- [ ] About page

### Error Handling Integration
- [ ] Wire `handleException()` into all repository implementations (currently only in auth provider)
- [ ] Create `Failure`-aware UI (error states in pages)
- [ ] Add error boundaries for unhandled exceptions

---

## Phase 3: Advanced Features
**Status:** Pending
**Priority:** Medium
**Duration:** 3-4 weeks

### Networking & Caching
- [ ] Implement pagination for list features
- [ ] Add image caching (`cached_network_image`)
- [ ] Add request cancellation support
- [ ] Implement offline-first caching (if needed)

### Push Notifications
- [ ] Wire FCM service into app lifecycle
- [ ] Handle foreground/background notifications
- [ ] Deep linking from notifications
- [ ] Notification preferences per type

### State Management Improvements
- [ ] Evaluate `@riverpod` code generation for new features
- [ ] Add provider tests for auth flow
- [ ] Add provider tests for profile flow

### Security Hardening
- [ ] Add ProGuard/R8 rules for Android release builds
- [ ] Implement screenshot prevention on sensitive screens
- [ ] Add certificate pinning (if custom API endpoints are added)
- [ ] Verify iOS App Transport Security settings

---

## Phase 4: Production Readiness
**Status:** Pending
**Priority:** Medium
**Duration:** 2-3 weeks

### Testing
- [ ] Widget tests for all reusable components
- [ ] Repository implementation tests (mock Supabase data sources)
- [ ] Use case tests (mock repositories)
- [ ] Integration tests for auth flow
- [ ] Golden tests for critical UI states

### CI/CD
- [ ] GitHub Actions workflow for linting and testing
- [ ] Build automation for Android and iOS
- [ ] Code coverage reporting
- [ ] Automated release notes

### Documentation
- [ ] API documentation for public methods
- [ ] Contributing guidelines
- [ ] Architecture decision records (ADRs)

### Performance
- [ ] App profiling with DevTools
- [ ] Startup time optimization
- [ ] Memory leak detection
- [ ] Asset optimization

---

## Phase 5: Scale & Polish
**Status:** Pending
**Priority:** Low
**Duration:** 4-6 weeks

### Feature Scaling
- [ ] Add 5-10 additional features following the established pattern
- [ ] Implement deep linking
- [ ] Add multi-language support beyond EN/AR
- [ ] Implement feature flags

### UI Polish
- [ ] Animations and transitions
- [ ] Haptic feedback
- [ ] Accessibility audit (WCAG compliance)
- [ ] Tablet/desktop layout support

### Monitoring
- [ ] Crash reporting (Firebase Crashlytics or Sentry)
- [ ] Analytics integration
- [ ] Performance monitoring
- [ ] User feedback mechanism

---

## Timeline Summary

| Phase | Duration | Dependencies | Status |
|---|---|---|---|
| Phase 1: Foundation | — | — | ✅ Complete |
| Phase 1.5: Sprint 1 | — | Phase 1 | ✅ Complete |
| Phase 2: Core Features | 2-3 weeks | Phase 1.5 | Pending |
| Phase 3: Advanced Features | 3-4 weeks | Phase 2 | Pending |
| Phase 4: Production Readiness | 2-3 weeks | Phase 2 | Pending |
| Phase 5: Scale & Polish | 4-6 weeks | Phase 3-4 | Pending |
| **Total** | **11-16 weeks** | — | — |

---

## Critical Path

```
Phase 1.5 (Sprint 1) ✅ → Phase 2 (Core Features) → Phase 4 (Production Readiness)
```

Phase 3 (Advanced Features) and Phase 5 (Scale & Polish) can be parallelized with Phase 4.

---

## Risk Factors

| Risk | Impact | Mitigation |
|---|---|---|
| Supabase RLS policies not configured | High — data access broken | Verify before Phase 2 |
| FCM integration complexity | Medium — delayed notifications | Phase 3 can be deferred |
| Test coverage gap | High — regression risk | Prioritize Phase 4 testing |
| Manual Riverpod boilerplate | Medium — slows development | Evaluate code-gen in Phase 3 |
| Arabic RTL edge cases | Medium — poor UX for Arabic users | Test early with native speakers |
