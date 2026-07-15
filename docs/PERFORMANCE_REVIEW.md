# Performance Review

## 1. App Startup

### Current Flow
```
main()
  → WidgetsFlutterBinding.ensureInitialized()
  → SystemChrome.setPreferredOrientations()
  → SharedPreferences.getInstance() [async, ~50-200ms]
  → FlutterSecureStorage instantiation [sync]
  → Supabase.initialize() [async, ~200-800ms]
  → runApp(ProviderScope(...))
```

### Assessment
- **Good:** Initialization is sequential and necessary. No unnecessary work on the main thread.
- **Good:** Orientation lock is set before first frame, preventing visual jumps.
- **Risk:** `SharedPreferences.getInstance()` and `Supabase.initialize()` are both async. Combined, they add 250-1000ms to cold start depending on device/network.
- **Risk:** `Supabase.initialize()` failure is caught and printed but not surfaced. The app continues without backend, leading to downstream errors that are expensive to diagnose.

### Recommendations
1. Show a splash screen during initialization (use `flutter_native_splash`).
2. Consider lazy-loading Supabase if the user doesn't need it immediately (but this conflicts with auth check).
3. Profile startup with `dart:developer` Timeline to measure actual phase durations.

---

## 2. Widget Rebuild Optimization

### Provider Watching

| Provider | Watch Location | Rebuild Scope |
|---|---|---|
| `goRouterProvider` | `App.build()` | Entire app on auth state change (expected) |
| `themeModeProvider` | `App.build()` | Entire app on theme toggle (expected) |
| `localeProvider` | `App.build()` | Entire app on locale change (expected) |
| `authStateProvider` | GoRouter redirect | Router refreshes via ValueNotifier (optimized) |

### Assessment
- **Good:** The `App` widget is a `ConsumerStatefulWidget` with `initState` callback for auth check — avoids rebuild on first frame.
- **Good:** GoRouter redirect is lightweight (simple type checks and string comparisons).
- **FIXED:** GoRouter now uses `refreshListenable` with a `ValueNotifier` instead of `ref.watch()`. This means the GoRouter is created once and only refreshes its redirect logic when auth state changes, instead of recreating the entire router object.
- **Good:** `ref.read()` is used inside the redirect callback instead of `ref.watch()`, avoiding unnecessary dependency tracking.

### Recommendations
1. For future features, ensure page-level providers don't leak into the shell route.
2. Use `select()` on providers where possible to narrow rebuild scope.

---

## 3. Memory Management

### StreamController in watchProfile() — FIXED
```dart
// lib/data/repositories/profile_repository_impl.dart
Stream<User> watchProfile(String userId) {
  final controller = StreamController<User>.broadcast();
  controller.onCancel = () {
    if (!controller.isClosed) {
      controller.close();
    }
  };
  // ... fetch logic with isClosed checks
  return controller.stream;
}
```

**FIXED:** The `StreamController` now uses `broadcast` mode and properly closes via `onCancel`. All `add()` and `addError()` calls check `isClosed` before operating.

### Riverpod Provider Disposal
- `authStateProvider` is `NotifierProvider` — auto-disposed when no longer watched (good).
- `goRouterProvider` is `Provider` — lives for the app lifetime (correct for router).
- `signInUseCaseProvider`, etc. are `Provider` — not auto-disposed (acceptable for singletons).

### Assessment
- **Good:** Most providers follow correct disposal patterns.
- **Good:** The `watchProfile` StreamController leak is fixed.
- **Good:** GoRouter provider uses `ref.onDispose()` for cleanup.

---

## 4. Network Performance

### Current State
- All networking goes through Supabase SDK (handles connection pooling, retry, caching internally).
- No request deduplication or caching layer.
- No image caching for avatars.

### Assessment
- **Good:** Supabase SDK handles HTTP/2, connection reuse, and token refresh internally.
- **Missing:** No pagination implementation despite list features being planned.
- **Missing:** No image caching for profile avatars. Every avatar load is a network request.
- **Missing:** No request cancellation support. If a user navigates away during a request, it continues wasting resources.

### Recommendations
1. Implement pagination for list features before they're added.
2. Use `cached_network_image` for avatar/profile image caching.
3. Use `CancelableOperation` or Riverpod auto-dispose for in-flight requests.

---

## 5. Build Performance

### Current State
- 49 source files + 6 generated files
- `build_runner` generates Freezed + JSON serialization
- `flutter gen-l10n` generates localization
- All generated files are excluded from analysis

### Assessment
- **Good:** Generated files are excluded from `analysis_options.yaml` to speed up analysis.
- **Good:** `flutter_lints` (not `very_good_analysis`) is used — lighter weight, faster analysis.
- **Good:** Unused dependencies (`riverpod_annotation`, `riverpod_generator`, `dio`, `connectivity_plus`) have been removed, reducing `build_runner` execution time and pub resolution time.
- **Good:** Dead source files (network layer, unused widgets, helpers, pagination) have been removed, reducing compilation time.

### Recommendations
1. For future features, profile `build_runner` execution time as the codebase scales.
2. Consider `freezed_annotation`'s `@freezed` over `@Freezed()` where possible (minor).

---

## 6. Scalability Concerns

| Area | Current | Scaling Risk |
|---|---|---|
| Provider count | ~25 manually defined providers | Medium — manual providers don't scale as well as code-gen |
| Route count | 5 routes | Low — GoRouter handles this well up to ~50 routes |
| Entity count | 1 (User) | Low — Freezed handles this well |
| Feature count | 3 (auth, home, settings) | Medium — each new feature adds providers, routes, pages |
| Dependency count | 12 production packages | Low — all actively used or staged for features |

### Assessment
The architecture is clean enough to scale to ~20 features without major refactoring. The main scaling risk is the manual Riverpod provider pattern — as the codebase grows, the number of boilerplate provider definitions will increase significantly.

### Recommendations
1. Evaluate `@riverpod` code generation for new features to reduce boilerplate.
2. Establish a consistent feature structure template.
3. Consider a feature scaffolding script (`mason` or custom).

---

## 7. Performance Summary

| Category | Score (Before) | Score (After) | Notes |
|---|---|---|---|
| Startup | 7/10 | 7/10 | No change — sequential async init, no splash screen |
| Widget Rebuilds | 6/10 | 8/10 | GoRouter uses refreshListenable instead of full rebuild |
| Memory | 5/10 | 9/10 | StreamController leak fixed, proper cleanup |
| Network | 7/10 | 7/10 | No change — Supabase SDK handles most concerns |
| Build | 8/10 | 9/10 | Removed 4 unused deps and 9 dead source files |
| Scalability | 7/10 | 7/10 | No change — architecture unchanged |
| **Overall** | **6.7/10** | **7.8/10** | **+1.1 points — significant improvement** |
