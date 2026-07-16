# ENGINE_INTERFACES.md — Engine Public API Contracts

> **Authority:** PROJECT_CONSTITUTION.md §19
> **Version:** 2.0

---

## Purpose

Every Engine must define a public interface. This document specifies the contract for each Engine's public API.

---

## Interface Design Principles

| Principle | Description |
|-----------|-------------|
| Abstract only | Interfaces use `abstract interface class` |
| No implementation | Interface file contains zero implementation logic |
| No framework imports | Domain interfaces have no Flutter/Supabase imports |
| Method contracts | Every method documents parameters, return type, exceptions |
| Event integration | Methods that cause state changes publish events |

---

## Identity Engine Interface

```dart
abstract interface class IdentityEngine {
  // Authentication
  Future<User> signIn(SignInMethod method, Credential credential);
  Future<User> signUp(SignUpMethod method, Credential credential);
  Future<void> signOut();
  Future<User?> get currentUser;
  Stream<AuthState> get authStateChanges;

  // Authorization
  Future<bool> hasPermission(Permission permission);
  Future<List<Role>> getRoles(String userId);
  Future<void> assignRole(String userId, Role role);

  // Sessions
  Future<Session> createSession(String userId, DeviceInfo device);
  Future<void> revokeSession(String sessionId);
  Future<List<Session>> getActiveSessions(String userId);

  // Profiles
  Future<Profile> getProfile(String userId);
  Future<Profile> updateProfile(String userId, ProfileUpdate update);
  Future<void> deleteProfile(String userId);
}
```

---

## Commerce Engine Interface

```dart
abstract interface class CommerceEngine {
  // Merchants
  Future<Merchant?> getMerchant(String id);
  Future<List<Merchant>> searchMerchants(MerchantFilter filter);
  Future<Merchant> createMerchant(MerchantData data);

  // Products
  Future<List<Product>> getProducts(ProductFilter filter);
  Future<Product?> getProduct(String id);
  Future<Product> createProduct(ProductData data);

  // Orders
  Future<Order> createOrder(OrderData data);
  Future<Order?> getOrder(String id);
  Future<List<Order>> getOrders(OrderFilter filter);
  Future<Order> updateOrderStatus(String orderId, OrderStatus status);

  // Catalog
  Future<List<Category>> getCategories(String merchantId);
  Future<Category> createCategory(CategoryData data);
}
```

---

## Payments Engine Interface

```dart
abstract interface class PaymentsEngine {
  // Wallet
  Future<Wallet> getWallet(String userId);
  Future<void> topUp(String userId, double amount, PaymentMethod method);
  Future<void> deduct(String userId, double amount, String reason);

  // Transactions
  Future<Transaction> charge(ChargeRequest request);
  Future<Transaction?> getTransaction(String id);
  Future<List<Transaction>> getTransactions(TransactionFilter filter);

  // Refunds
  Future<Refund> refund(String transactionId, double amount, String reason);

  // Invoices
  Future<Invoice> createInvoice(InvoiceData data);
  Future<Invoice?> getInvoice(String id);
}
```

---

## Maps Engine Interface

```dart
abstract interface class MapsEngine {
  // Location
  Future<Position?> getCurrentLocation();
  Stream<Position> trackLocation();

  // Places
  Future<List<Place>> searchPlaces(String query, Position? near);
  Future<PlaceDetails> getPlaceDetails(String placeId);

  // Routes
  Future<Route> getRoute(Position origin, Position destination);
  Future<List<Step>> getDirections(Position origin, Position destination);

  // Geocoding
  Future<String> getAddress(Position location);
  Future<Position> getCoordinates(String address);
}
```

---

## Notifications Engine Interface

```dart
abstract interface class NotificationsEngine {
  // Send
  Future<void> push(String userId, Notification notification);
  Future<void> sms(String phone, String message);
  Future<void> email(String address, EmailMessage message);

  // Subscribe
  Future<void> subscribe(String userId, String topic);
  Future<void> unsubscribe(String userId, String topic);

  // Preferences
  Future<NotificationPrefs> getPrefs(String userId);
  Future<void> updatePrefs(String userId, NotificationPrefs prefs);

  // History
  Future<List<Notification>> getHistory(String userId, {int limit});
}
```

---

## Search Engine Interface

```dart
abstract interface class SearchEngine {
  // Global search
  Future<List<SearchResult>> search(String query, SearchFilter filter);

  // Nearby
  Future<List<SearchResult>> nearby(String type, Position location, double radiusKm);

  // Autocomplete
  Future<List<String>> autocomplete(String partial, {String? type});

  // Recommendations
  Future<List<SearchResult>> recommendations(String userId, String context);
}
```

---

## Analytics Engine Interface

```dart
abstract interface class AnalyticsEngine {
  // Events
  Future<void> track(String event, {Map<String, dynamic>? properties});
  Future<void> identify(String userId, {Map<String, dynamic>? traits});

  // Queries
  Future<Metric> getMetric(String name, TimeRange range);
  Future<List<DataPoint>> getTimeSeries(String metric, TimeRange range);
  Future<Map<String, dynamic>> getFunnel(FunnelDefinition funnel);
}
```

---

## Logging Engine Interface

```dart
abstract interface class LoggingEngine {
  // Application logs
  Future<void> log(LogLevel level, String message, {Map<String, dynamic>? data});

  // Audit logs
  Future<void> audit(String action, String resource, {String? resourceId, Map<String, dynamic>? details});

  // Security logs
  Future<void> security(String event, {Map<String, dynamic>? details});

  // Query
  Future<List<LogEntry>> query(LogFilter filter);
}
```

---

## AI Engine Interface

```dart
abstract interface class AIEngine {
  // Recommendations
  Future<List<Recommendation>> getRecommendations(String userId, String context);

  // Natural Language
  Future<String> processNaturalLanguage(String input, {Map<String, dynamic>? context});

  // Predictions
  Future<Prediction> predict(String model, Map<String, dynamic> features);

  // Provider management
  Future<void> setProvider(AIProvider provider);
  AIProvider get currentProvider;
}
```

---

## Storage Engine Interface

```dart
abstract interface class StorageEngine {
  // Upload
  Future<String> upload(Uint8List data, StoragePath path, {String? contentType});
  Future<String> uploadFile(File file, StoragePath path);

  // Download
  Future<Uint8List> download(StoragePath path);
  Future<String> getDownloadUrl(StoragePath path);

  // Manage
  Future<void> delete(StoragePath path);
  Future<List<StorageItem>> list(StoragePath directory);

  // Cache
  Future<void> cache(String key, Uint8List data, {Duration? ttl});
  Future<Uint8List?> getCached(String key);
}
```
