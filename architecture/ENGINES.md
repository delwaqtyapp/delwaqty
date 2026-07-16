# ENGINES.md — Platform Engine Catalog

> **Authority:** PROJECT_CONSTITUTION.md §20
> **Version:** 2.0

---

## Engine Definition

An Engine is a reusable platform capability that owns a cross-cutting domain concern. Engines are the building blocks of the Platform Kernel.

---

## Engine Catalog

### 1. Identity Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Authentication, Authorization, Roles, Permissions, Profiles, Devices, Sessions |
| **Current Status** | Partially implemented (Auth, Profile) |
| **Dependencies** | None (foundational) |
| **Extension Points** | New auth providers, new role types, new permission models |

### 2. Commerce Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Merchants, Branches, Catalogs, Products, Variants, Modifiers, Inventory, Pricing, Taxes, Fees, Offers, Coupons, Orders |
| **Current Status** | Partially implemented (Merchants, Products, Orders, Favorites) |
| **Dependencies** | Identity Engine, Payments Engine |
| **Extension Points** | New product types, new pricing models, new order flows |

### 3. Marketplace Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Listings, Categories, Search, Favorites, Media, Messaging |
| **Current Status** | Not started |
| **Dependencies** | Identity Engine, Commerce Engine, Search Engine |
| **Extension Points** | New listing types, new category models |

### 4. Mobility Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Ride Hailing, Drivers, Vehicles, Trips, Navigation, Tracking, Dispatch |
| **Current Status** | Not started |
| **Dependencies** | Identity Engine, Maps Engine, Payments Engine |
| **Extension Points** | New vehicle types, new dispatch algorithms |

### 5. Home Services Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Providers, Scheduling, Availability, Bookings, Technicians |
| **Current Status** | Not started |
| **Dependencies** | Identity Engine, Maps Engine, Payments Engine, Notifications Engine |
| **Extension Points** | New service types, new scheduling models |

### 6. Payments Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Wallet, Cards, Cash, QR, Invoices, Refunds, Installments |
| **Current Status** | Not started |
| **Dependencies** | Identity Engine |
| **Extension Points** | New payment providers, new financial instruments |

### 7. Notifications Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Push, SMS, Email, WhatsApp, In-App, Templates, Campaigns |
| **Current Status** | Partially implemented (Push via FCM) |
| **Dependencies** | Identity Engine |
| **Extension Points** | New channels, new template engines |

### 8. Maps Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Location, Places, Routes, Navigation, Tracking, Geocoding |
| **Current Status** | Partially implemented (Google Maps) |
| **Dependencies** | None |
| **Extension Points** | New map providers, new routing algorithms |

### 9. Search Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Nearby Search, Global Search, Recommendations, Ranking, Filtering |
| **Current Status** | Mock (in-memory) |
| **Dependencies** | Identity Engine |
| **Extension Points** | New ranking algorithms, new filter types |

### 10. Analytics Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Events, Metrics, Dashboards, Funnels, Reporting |
| **Current Status** | Partially implemented (Firebase Analytics) |
| **Dependencies** | Identity Engine |
| **Extension Points** | New metric types, new dashboard builders |

### 11. Logging Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Application Logs, Audit Logs, Security Logs, Monitoring |
| **Current Status** | Partially implemented (AppLogger) |
| **Dependencies** | None |
| **Extension Points** | New log destinations, new audit triggers |

### 12. AI Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Recommendations, Predictions, Context Awareness, Natural Language, Provider Abstraction |
| **Current Status** | Not started |
| **Dependencies** | Identity Engine, Analytics Engine |
| **Extension Points** | New AI providers, new model types |

### 13. Storage Engine

| Aspect | Detail |
|--------|--------|
| **Responsibility** | Media, Documents, Images, CDN, Caching, Synchronization |
| **Current Status** | Partially implemented (Cloudflare R2, SharedPreferences) |
| **Dependencies** | None |
| **Extension Points** | New storage backends, new cache strategies |

---

## Engine Dependency Graph

```
Identity Engine (foundational)
    ├── Commerce Engine
    │   ├── Marketplace Engine
    │   └── Orders Engine
    ├── Mobility Engine
    ├── Home Services Engine
    ├── Payments Engine
    ├── Notifications Engine
    ├── Search Engine
    ├── Analytics Engine
    ├── AI Engine
    └── Storage Engine

Maps Engine (independent)
    ├── Mobility Engine
    ├── Home Services Engine
    └── Commerce Engine (location-based)

Logging Engine (independent)
    └── All Engines (observability)
```
