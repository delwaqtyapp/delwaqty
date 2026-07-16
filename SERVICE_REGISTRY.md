# SERVICE_REGISTRY.md

> **Generated:** 2026-07-16 | **Sprint:** 11.5
> **Purpose:** Every platform service MUST register here with its interface and implementation status.

---

## Service Architecture

All services follow the Abstract Interface pattern (ADR-007):

```
lib/services/<domain>/
  ├── <service>_service.dart          # Abstract interface
  └── <service>_service_impl.dart     # Concrete implementation
```

Modules consume only the abstract interface. Implementations are swapped via Riverpod provider overrides.

---

## Active Services

| Service | Interface | Implementation | Mock | Status |
|---------|-----------|----------------|------|--------|
| Authentication | `AuthService` | `AuthServiceImpl` | Yes | Active |
| Admin | `AdminService` | `AdminService` | Yes | Active |
| Analytics | `AnalyticsService` | `AnalyticsServiceImpl` | Yes | Active |
| Connectivity | `ConnectivityService` | — (self-contained) | No | Active |
| FCM | `FcmService` | — (self-contained) | No | Active |
| Image | `ImageService` | `ImageServiceImpl` | Yes | Active |
| Location | `LocationService` | `LocationServiceImpl` | Yes | Active |
| Logger | `AppLogger` | — (self-contained) | No | Active |
| Logging | `LoggingService` | `LoggingServiceImpl` | Yes | Active |
| Maps | `MapsService` | `MapsServiceImpl` | Yes | Active |
| Google Maps | `GoogleMapsService` | — (wraps plugin) | No | Active |
| Notification | `NotificationService` | `NotificationServiceImpl` | Yes | Active |
| Payment | `PaymentService` | `PaymentServiceImpl` | Yes | Active |
| Search | `SearchService` | `SearchServiceImpl` | Yes | Active |
| Storage | `StorageService` | `StorageServiceImpl` | Yes | Active |
| Cloudflare R2 | `CloudflareR2Service` | — (wraps HTTP) | No | Active |
| Supabase | `SupabaseService` | `SupabaseInitializer` | No | Active |
| SharedPreferences | `SharedPreferencesService` | — (wraps plugin) | No | Active |
| SecureStorage | `SecureStorageService` | — (wraps plugin) | No | Active |

---

## Planned Services

| Service | Interface | Purpose | Priority | Sprint |
|---------|-----------|---------|----------|--------|
| AI Engine | `AiEngine` | LLM integration (OpenAI/Gemini) | High | 15 |
| Smart Routing | `SmartRoutingService` | AI-powered delivery routing | Medium | 15 |
| Fraud Detection | `FraudDetectionService` | Transaction fraud detection | Medium | 15 |
| Pricing | `PricingService` | Dynamic pricing engine | Medium | 15 |
| Recommendation | `RecommendationService` | Product recommendations | Medium | 15 |
| Geofencing | `GeofencingService` | Location-based triggers | Medium | 16 |
| Driver Tracking | `DriverTrackingService` | Real-time driver positions | Medium | 16 |
| Dynamic Pricing Zones | `DynamicPricingZoneService` | Zone-based pricing | Low | 16 |
| WebSocket | `WebSocketService` | Real-time communication | Medium | 19 |
| Cache | `CacheService` | Multi-layer caching | High | 14 |
| Feature Flags | `FeatureFlagsService` | Remote feature toggles | Medium | 15 |
| Health Check | `HealthCheckService` | Service health monitoring | Medium | 14 |
| Crash Reporter | `CrashReporter` | Crash reporting (Crashlytics) | High | 12 |
| Performance Monitor | `PerformanceMonitor` | App performance tracking | Medium | 14 |

---

## Service Dependency Matrix

| Service | Depends On |
|---------|------------|
| Authentication | Supabase, SecureStorage |
| Admin | Supabase, Authentication |
| Analytics | Logging, Connectivity |
| FCM | Firebase Messaging |
| Location | Geolocator (planned) |
| Maps | Google Maps plugin |
| Payment | Authentication, Supabase |
| Search | Commerce entities |
| Storage | Cloudflare R2 (planned) |
| Notification | FCM, Supabase |
| AI Engine | HTTP, Feature Flags (planned) |

---

## Service Interface Template

```dart
// lib/services/<domain>/<service>_service.dart

abstract class MyService {
  Future<MyResult> doSomething(String param);
  Stream<MyEvent> watchEvents();
}

// lib/services/<domain>/<service>_service_impl.dart

class MyServiceImpl implements MyService {
  @override
  Future<MyResult> doSomething(String param) async {
    // Implementation using external plugin
  }

  @override
  Stream<MyEvent> watchEvents() {
    // Stream implementation
  }
}
```

---

## Adding a New Service — Checklist

- [ ] Create directory: `lib/services/<domain>/`
- [ ] Create abstract interface: `<service>_service.dart`
- [ ] Create implementation: `<service>_service_impl.dart`
- [ ] Create mock: `data/repositories/mock/mock_<service>_repository.dart` (if data access)
- [ ] Create Riverpod providers for the service
- [ ] Register initialization in `lib/main.dart`
- [ ] Update this file (SERVICE_REGISTRY.md)
- [ ] Update `PLUGIN_REGISTRY.md` if new plugin dependency added
- [ ] Add test coverage
- [ ] Run `flutter pub get && flutter analyze && flutter test`
