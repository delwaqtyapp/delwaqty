# PLUGIN_REGISTRY.md

> **Generated:** 2026-07-16 | **Sprint:** 11.5
> **Purpose:** Every platform service plugin MUST register here. No hardcoded modules.

---

## Plugin System Architecture

The Delwaqty platform uses a plugin architecture where:
- **Modules** are feature-level plugins (registered in `module_registry.dart`)
- **Plugins** are platform-level services (registered in this file)
- **Services** are abstract interfaces (registered in `SERVICE_REGISTRY.md`)

Plugins are platform capabilities that modules consume. They are NOT features — they are infrastructure.

---

## Active Plugins

| Plugin | Package | Version | Platform | Status |
|--------|---------|---------|----------|--------|
| Supabase | `supabase_flutter` | 2.5.0 | All | Active |
| Firebase Core | `firebase_core` | 2.32.0 | All | Configured |
| Firebase Messaging | `firebase_messaging` | 14.9.4 | All | Configured |
| Google Maps | `google_maps_flutter` | 2.14.2 | Android/iOS | Configured |
| Shared Preferences | `shared_preferences` | 2.2.3 | All | Active |
| Flutter Secure Storage | `flutter_secure_storage` | 9.2.4 | All | Active |
| Connectivity Plus | `connectivity_plus` | 6.1.5 | All | Active |
| HTTP | `http` | 1.2.0 | All | Active |
| Crypto | `crypto` | 3.0.3 | All | Active |
| Logger | `logger` | 2.4.0 | All | Active |
| Intl | `intl` | 0.20.2 | All | Active |

---

## Planned Plugins

| Plugin | Package | Purpose | Priority | Sprint |
|--------|---------|---------|----------|--------|
| Cloudflare R2 | `http` (custom) | Asset storage, CDN | High | 12 |
| Stripe | `flutter_stripe` | Card payments | High | 16 |
| Tap Payments | `tap_payments` | Mada, STC Pay | High | 16 |
| Apple Pay | `pay` | iOS payments | Medium | 16 |
| Google Pay | `pay` | Android payments | Medium | 16 |
| Geolocator | `geolocator` | GPS location | High | 16 |
| Permission Handler | `permission_handler` | Runtime permissions | High | 16 |
| Image Picker | `image_picker` | Camera/gallery access | Medium | 14 |
| File Picker | `file_picker` | Document selection | Low | 18 |
| URL Launcher | `url_launcher` | Open URLs externally | Low | 18 |
| Share Plus | `share_plus` | Share content | Low | 18 |
| Path Provider | `path_provider` | File system access | Medium | 14 |
| Package Info | `package_info_plus` | App version info | Low | 18 |
| Device Info | `device_info_plus` | Device identification | Low | 18 |
| Local Auth | `local_auth` | Biometric authentication | Medium | 16 |
| QR Code Scanner | `mobile_scanner` | QR/barcode scanning | Medium | 17 |
| In App Review | `in_app_review` | App store reviews | Low | 20 |
| Firebase Crashlytics | `firebase_crashlytics` | Crash reporting | High | 12 |
| Firebase Analytics | `firebase_analytics` | Event analytics | High | 12 |
| Firebase Remote Config | `firebase_remote_config` | Feature flags | Medium | 15 |

---

## Plugin Registration Convention

Every plugin must be:

1. **Declared** in `pubspec.yaml` with a pinned version range
2. **Initialized** in `lib/main.dart` or a service initializer
3. **Abstracted** behind a service interface (see `SERVICE_REGISTRY.md`)
4. **Mockable** for testing (mock implementation in `data/repositories/mock/`)

### Initialization Order

```
1. SharedPreferences
2. FlutterSecureStorage
3. Supabase
4. Firebase Core
5. Firebase Messaging
6. Connectivity
7. Feature Modules
```

---

## Adding a New Plugin — Checklist

- [ ] Add package to `pubspec.yaml` with version constraint
- [ ] Run `flutter pub get`
- [ ] Create abstract service interface in `lib/services/<service>/`
- [ ] Create concrete implementation wrapping the plugin
- [ ] Create mock implementation for testing
- [ ] Register initialization in `lib/main.dart`
- [ ] Update this file (PLUGIN_REGISTRY.md)
- [ ] Update `SERVICE_REGISTRY.md` if new service interface created
- [ ] Add test coverage for the service wrapper
- [ ] Run `flutter pub get && flutter analyze && flutter test`
