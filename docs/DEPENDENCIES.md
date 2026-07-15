# Dependencies

## Production Dependencies

| Package | Version | Required | Purpose | Alternatives |
|---|---|---|---|---|
| `flutter_riverpod` | ^2.5.1 | Yes | State management, dependency injection, reactive state | Bloc, Provider, GetX, Signals |
| `go_router` | ^14.0.2 | Yes | Declarative routing with auth guards, shell routes, nested navigation | auto_route, Beamer, Navigator 2.0 |
| `freezed_annotation` | ^2.4.1 | Yes | Annotations for Freezed immutable data classes and union types | Equatable, data_class |
| `json_annotation` | ^4.9.0 | Yes | Annotations for json_serializable code generation | None (required by Freezed for JSON) |
| `shared_preferences` | ^2.2.3 | Yes | Local key-value storage for theme, locale, and onboarding preferences | Hive, Isar, flutter_data |
| `flutter_secure_storage` | ^9.0.0 | Yes | Encrypted storage for authentication tokens (access/refresh) | flutter_keychain, SFSafariViewController |
| `logger` | ^2.4.0 | Yes | Structured logging with pretty-print output | timber, logging package, print (avoid) |
| `supabase_flutter` | ^2.5.0 | Yes | Supabase SDK — auth, database, storage, real-time | Firebase, AppWrite, custom backend |
| `firebase_core` | ^2.30.1 | Yes* | Firebase initialization (required for FCM) | None (required by firebase_messaging) |
| `firebase_messaging` | ^14.8.2 | Yes* | Push notification support (FCM) | OneSignal, Pushy, Workmanager |
| `flutter_localizations` | SDK | Yes | Localization delegates for Material widgets | None (built-in) |
| `intl` | ^0.20.2 | Yes | Internationalization utilities, date/number formatting, message syntax | None (required by flutter_localizations) |
| `cupertino_icons` | ^1.0.8 | Yes | iOS-style icons for Cupertino widgets | None |

**\* `firebase_core` and `firebase_messaging`** are installed for FCM architecture. The FCM service file exists and imports from these packages, but FCM is not yet initialized in the app. If Firebase is not needed immediately, these can be removed and re-added when FCM is actually implemented.

## Dev Dependencies

| Package | Version | Required | Purpose | Alternatives |
|---|---|---|---|---|
| `flutter_lints` | ^3.0.0 | Yes | Official Flutter lint rules | very_good_analysis, dart_code_metrics |
| `build_runner` | ^2.4.9 | Yes | Runs code generators for Freezed, json_serializable | None (required) |
| `freezed` | ^2.5.2 | Yes | Generates immutable classes, copyWith, pattern matching | None (required) |
| `json_serializable` | ^6.8.0 | Yes | Generates JSON serialization code | None (required) |
| `flutter_test` | SDK | Yes | Unit and widget testing framework | integration_test |

## Removed Dependencies (Sprint 1)

| Package | Reason for Removal |
|---|---|
| `riverpod_annotation` | No `@riverpod` annotations used in codebase — manual providers only |
| `riverpod_generator` | No providers generated — manual providers only |
| `dio` | HTTP client unused — all networking goes through Supabase SDK |
| `connectivity_plus` | NetworkInfo unused — Supabase handles connectivity internally |

## Dependency Size Impact

Current dependency count: **12 production + 5 dev = 17 total packages**

Removed 4 unused packages in Sprint 1, reducing:
- Compilation time
- APK/IPA binary size
- Dependency management overhead
- Security audit surface

## Unused Dependencies Summary

| Package | Status | Recommendation |
|---|---|---|
| `firebase_core` | FCM service file exists but not wired | Keep if FCM is planned, remove if not |
| `firebase_messaging` | FCM service file exists but not wired | Keep if FCM is planned, remove if not |

All production dependencies are now actively used or intentionally staged for upcoming features.
