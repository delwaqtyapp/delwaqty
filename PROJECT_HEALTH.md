# PROJECT_HEALTH.md

> **Generated:** 2026-07-16 | **Sprint:** 11.5 | **Status:** Healthy

---

## GitHub Synchronization

| Check | Status |
|-------|--------|
| Remote | `origin` → `https://github.com/delwaqtyapp/delwaqty` |
| Branch | `master` (single branch) |
| Local SHA | `3e941d7` |
| Remote SHA | `3e941d7` |
| Sync Status | **IN SYNC** |
| Total Commits | 18 |
| `.env.dev` Tracked | No (`.gitignore` enforced) |
| Secrets in Git History | None confirmed |

---

## Codebase Metrics

| Metric | Value |
|--------|-------|
| Dart Source Files | 262 |
| Lines of Code (lib/) | 31,025 |
| Test Files | 40 |
| Tests Passing | 443 / 443 |
| Test Coverage | Mock-based (no coverage report yet) |
| Analysis Errors | 0 |
| Analysis Warnings | 0 |
| Analysis Info | 162 (style suggestions) |
| Generated Files | 36 (19 `.freezed.dart` + 17 `.g.dart`) |
| Feature Modules | 11 registered |
| Repository Interfaces | 14 (6 domain + 8 commerce) |
| Service Files | 29 |
| Freezed Entities | 19 |
| ADRs Documented | 23 |
| TODO/FIXME/HACK | 1 TODO |

---

## Dependency Health

| Package | Current | Latest | Status |
|---------|---------|--------|--------|
| flutter_riverpod | 2.6.1 | 3.3.2 | Outdated (major) |
| go_router | 14.8.1 | 17.3.0 | Outdated (major) |
| freezed_annotation | 2.4.4 | 3.1.0 | Outdated (major) |
| supabase_flutter | 2.5.0 | — | Current |
| firebase_core | 2.32.0 | 4.12.1 | Outdated (major) |
| firebase_messaging | 14.9.4 | 16.4.3 | Outdated (major) |
| google_maps_flutter | 2.14.2 | 2.17.1 | Outdated (minor) |
| flutter_secure_storage | 9.2.4 | 10.3.1 | Outdated (major) |
| connectivity_plus | 6.1.5 | 7.3.0 | Outdated (major) |
| json_serializable | 6.9.5 | 6.14.0 | Outdated (minor) |

**48 packages have newer versions.** Major version upgrades required for Riverpod, GoRouter, Freezed, Firebase.

---

## Build Health

| Check | Status |
|-------|--------|
| `flutter pub get` | Passing |
| `flutter analyze` | 0 errors, 0 warnings |
| `flutter test` | 443/443 passing |
| `flutter build apk --debug` | 155.9 MB APK |
| `flutter build apk --release` | Passing |
| `adb install` | Success |
| App launch on DNP NX9 | Running (PID confirmed) |

---

## CI/CD Health

| Pipeline | Status |
|----------|--------|
| `.github/workflows/ci.yml` | Active |
| Format check (`dart format`) | Enforced |
| Lint check (`flutter analyze`) | Enforced |
| Test gate (`flutter test --coverage`) | Enforced |
| Debug APK build | Enforced |
| Release APK build | Enforced |
| Auto-release on master push | Active |
| Flutter version pinned | 3.44.6 |
| Java version | 17 |
| Concurrency groups | Active |

---

## Security Health

| Check | Status |
|-------|--------|
| Hardcoded secrets in Dart | None |
| `.env.dev` in git | No |
| `.keystore` / `.jks` files | None |
| `google-services.json` | Not present |
| Config classes | `abstract final` |
| Environment isolation | `.env.dev`, `.env.staging`, `.env.prod` |
| RLS policies | 29 total, **12 overly permissive** |
| `// ignore:` suppressions | 14 (11 `avoid_print`) |
| Deprecated API usage | 8 (`withOpacity`) |

---

## Documentation Health

| Document | Status |
|----------|--------|
| `AGENTS.md` | Created (governance rules) |
| `SESSION_STATUS.md` | Active (continuously updated) |
| `docs/DECISION_LOG.md` | 23 ADRs |
| `docs/ROADMAP.md` | Current (Sprint 11 complete) |
| `docs/HANDOFF/` | 10 files |
| `CONTRIBUTING.md` | Present |
| `PROJECT_HEALTH.md` | This file |
| `ARCHITECTURE_SCORE.md` | Created (Sprint 11.5) |
| `TECHNICAL_DEBT.md` | Created (Sprint 11.5) |
| `FEATURE_REGISTRY.md` | Created (Sprint 11.5) |
| `PLUGIN_REGISTRY.md` | Created (Sprint 11.5) |
| `SERVICE_REGISTRY.md` | Created (Sprint 11.5) |

---

## Overall Health Score

| Category | Score |
|----------|-------|
| Code Quality | 9/10 |
| Test Coverage | 8/10 |
| Architecture | 9/10 |
| Security | 6/10 (RLS policies need hardening) |
| Documentation | 9/10 |
| CI/CD | 9/10 |
| Dependencies | 5/10 (48 outdated) |
| **Overall** | **8/10** |

---

## Recommendations

1. **[CRITICAL]** Harden RLS policies before production deployment
2. **[HIGH]** Rotate Supabase service role key if exposed
3. **[HIGH]** Deploy database schema via Supabase Dashboard
4. **[MEDIUM]** Upgrade major dependencies (Riverpod 3.x, GoRouter 17.x, Freezed 3.x)
5. **[MEDIUM]** Replace `avoid_print` suppressions with `AppLogger`
6. **[MEDIUM]** Replace deprecated `withOpacity()` with `withValues()`
7. **[LOW]** Add coverage reporting to CI
8. **[LOW]** Add `google-services.json` to `.gitignore` preemptively
