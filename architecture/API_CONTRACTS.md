# API_CONTRACTS.md — API Design Standards

> **Authority:** PROJECT_CONSTITUTION.md §4
> **Version:** 2.0

---

## API Layers

```
┌──────────────────────────────┐
│     Plugin Public API        │  (what Plugins expose)
├──────────────────────────────┤
│    Platform Service API      │  (what Services expose)
├──────────────────────────────┤
│      Engine Interface        │  (what Engines expose)
├──────────────────────────────┤
│    Repository Interface      │  (what Repositories expose)
├──────────────────────────────┤
│     Data Source Interface    │  (what DataSources expose)
├──────────────────────────────┤
│     External API (HTTP)      │  (what Supabase/Firebase expose)
└──────────────────────────────┘
```

---

## Naming Conventions

| Layer | Prefix | Example |
|-------|--------|---------|
| Entity | None | `Merchant`, `Product`, `Order` |
| Value Object | None | `Money`, `Address`, `PhoneNumber` |
| Repository Interface | None | `MerchantRepository` |
| Repository Impl | None | `MerchantRepositoryImpl` |
| DataSource Interface | None | `MerchantDataSource` |
| DataSource Impl | `Supabase` | `SupabaseMerchantDataSource` |
| Service Interface | None | `MerchantService` |
| Service Impl | `Supabase` | `SupabaseMerchantService` |
| Engine Interface | None | `CommerceEngine` |
| Plugin | Domain | `RestaurantPlugin` |

---

## Method Conventions

| Operation | HTTP | Method | Return |
|-----------|------|--------|--------|
| Get single | GET | `getById(String id)` | `Future<Entity?>` |
| Get list | GET | `getMany(Filter filter)` | `Future<List<Entity>>` |
| Create | POST | `create(Data data)` | `Future<Entity>` |
| Update | PUT | `update(String id, Data data)` | `Future<Entity>` |
| Delete | DELETE | `delete(String id)` | `Future<void>` |
| Search | GET | `search(String query, Filter filter)` | `Future<List<Entity>>` |
| Count | GET | `count(Filter filter)` | `Future<int>` |

---

## Error Response Pattern

```dart
sealed class AppException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  AppException({required this.message, this.statusCode, this.code});
}

class ServerException extends AppException { ... }
class CacheException extends AppException { ... }
class AuthException extends AppException { ... }
class ValidationException extends AppException { ... }
class NotFoundException extends AppException { ... }
class PermissionException extends AppException { ... }
```

---

## Pagination Pattern

```dart
class PaginatedResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;
}

class PaginationParams {
  final int page;
  final int pageSize;
  final String? sortBy;
  final bool sortDescending;

  PaginationParams({
    this.page = 1,
    this.pageSize = 20,
    this.sortBy,
    this.sortDescending = false,
  });
}
```

---

## Filter Pattern

```dart
class MerchantFilter {
  final MerchantType? type;
  final String? city;
  final bool? isOpenNow;
  final SearchFilter? search;
  final PaginationParams? pagination;
}
```

---

## API Versioning

| Strategy | Description |
|----------|-------------|
| URL versioning | `/v1/merchants`, `/v2/merchants` |
| Header versioning | `Accept: application/vnd.delwaqty.v1+json` |
| Current version | v1 |

---

## Authentication

All API calls require authentication:

```dart
// Automatic via Platform Kernel
final merchant = await kernel.engine<CommerceEngine>().getMerchant('m1');
// Kernel automatically attaches auth token
```

---

## Rate Limiting

| Endpoint | Limit |
|----------|-------|
| Auth endpoints | 10/minute |
| Read endpoints | 100/minute |
| Write endpoints | 30/minute |
| Search endpoints | 60/minute |

Rate limits enforced by Supabase RLS and edge functions.
