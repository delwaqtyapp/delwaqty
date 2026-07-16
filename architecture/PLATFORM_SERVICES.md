# PLATFORM_SERVICES.md — Platform Service Layer

> **Authority:** PROJECT_CONSTITUTION.md §12
> **Version:** 2.0

---

## Purpose

Platform Services are reusable capabilities available to all Plugins through the Platform Kernel. Each service wraps an Engine's functionality for easy access.

---

## Service Registry

```dart
abstract interface class PlatformServices {
  // Identity
  AuthService get auth;
  ProfileService get profile;

  // Commerce
  MerchantService get merchant;
  ProductService get product;
  OrderService get order;

  // Payments
  WalletService get wallet;
  PaymentService get payment;

  // Maps
  LocationService get location;
  NavigationService get navigation;

  // Notifications
  NotificationService get notification;

  // Search
  SearchService get search;

  // Storage
  StorageService get storage;

  // Analytics
  AnalyticsService get analytics;

  // Logging
  LoggingService get logging;

  // AI
  AIService get ai;
}
```

---

## Service Implementation Pattern

Every service follows this pattern:

```dart
// Abstract interface (domain layer)
abstract interface class MerchantService {
  Future<Merchant?> getById(String id);
  Future<List<Merchant>> search(String query);
  Future<Merchant> create(MerchantData data);
}

// Implementation (data layer)
class SupabaseMerchantService implements MerchantService {
  final SupabaseClient _client;
  // ... implementation
}

// Provider (DI layer)
final merchantServiceProvider = Provider<MerchantService>((ref) {
  return SupabaseMerchantService(ref.watch(supabaseClientProvider));
});
```

---

## Service Catalog

| Service | Engine | Current Provider |
|---------|--------|-----------------|
| AuthService | Identity | Supabase GoTrue |
| ProfileService | Identity | Supabase Realtime |
| MerchantService | Commerce | Supabase |
| ProductService | Commerce | Supabase |
| OrderService | Commerce | Supabase |
| LocationService | Maps | geolocator |
| NavigationService | Maps | Google Maps |
| NotificationService | Notifications | FCM + flutter_local_notifications |
| AnalyticsService | Analytics | Firebase Analytics |
| LoggingService | Logging | AppLogger |
| StorageService | Storage | SharedPreferences + SecureStorage |
| SearchService | Search | In-memory (mock) |
| WalletService | Payments | Not started |
| PaymentService | Payments | Not started |
| AIService | AI | Not started |

---

## Service Lifecycle

1. **Registration** — Service registered as Riverpod provider
2. **Initialization** — Service sets up connections, caches
3. **Operation** — Service handles requests
4. **Disposal** — Service releases resources

---

## Service Testing

Every service must be testable:

```dart
test('merchantService.getById returns merchant', () async {
  final service = MockMerchantService();
  when(() => service.getById('m1')).thenAnswer((_) async => testMerchant);

  final result = await service.getById('m1');
  expect(result, testMerchant);
});
```
