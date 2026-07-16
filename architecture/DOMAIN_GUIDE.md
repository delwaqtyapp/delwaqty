# DOMAIN_GUIDE.md — Domain-First Development

> **Authority:** PROJECT_CONSTITUTION.md §5
> **Version:** 2.0

---

## Core Rule

Never implement a feature before designing its domain. The domain model is the contract. Implementation follows the domain — not the opposite.

---

## Domain Design Process

### Step 1: Identify Entities

List all nouns in the domain. Each noun becomes a potential entity.

Example for Restaurant domain:
- Restaurant, Branch, Menu, Category, Item, Modifier, Order, OrderItem, Reservation, Table

### Step 2: Define Relationships

Map entity relationships:
- Restaurant HAS MANY Branches
- Branch HAS MANY Menus
- Menu HAS MANY Categories
- Category HAS MANY Items
- Item HAS MANY Modifiers
- Order HAS MANY OrderItems

### Step 3: Define Value Objects

Identify value objects (immutable, identity-less):
- Money (amount, currency)
- Address (street, city, lat, lng)
- PhoneNumber (code, number)
- TimeRange (start, end)

### Step 4: Define Aggregates

Group entities into aggregates (consistency boundaries):
- **Restaurant Aggregate:** Restaurant, Branch
- **Menu Aggregate:** Menu, Category, Item, Modifier
- **Order Aggregate:** Order, OrderItem

### Step 5: Define Repository Interfaces

Each aggregate gets a repository interface:
```dart
abstract interface class RestaurantRepository {
  Future<Restaurant?> getById(String id);
  Future<List<Restaurant>> search(String query);
  Future<Restaurant> create(Restaurant restaurant);
  Future<void> update(Restaurant restaurant);
}
```

### Step 6: Define Events

What happens in this domain?
- `RestaurantCreated`
- `MenuUpdated`
- `OrderPlaced`
- `OrderDelivered`

### Step 7: Document

Write the domain documentation in `architecture/domains/`:
- `DOMAIN_NAME.md` — Entities, Value Objects, Aggregates, Events
- `DOMAIN_NAME_ENTITIES.md` — Detailed entity specifications
- `DOMAIN_NAME_EVENTS.md` — Event definitions

---

## Domain Documentation Template

```markdown
# [Domain Name] Domain

## Entities
| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| ... | ... | ... |

## Value Objects
| Value Object | Description | Fields |
|--------------|-------------|--------|
| ... | ... | ... |

## Aggregates
| Aggregate | Root Entity | Contained Entities |
|-----------|-------------|-------------------|
| ... | ... | ... |

## Repository Interfaces
| Interface | Methods |
|-----------|---------|
| ... | ... |

## Events
| Event | Trigger | Payload |
|-------|---------|---------|
| ... | ... | ... |

## Business Rules
- Rule 1
- Rule 2

## Dependencies
| Depends On | Reason |
|------------|--------|
| ... | ... |
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Why It's Wrong |
|--------------|---------------|
| Implementing before designing | Leads to architectural drift |
| Anemic domain models | Entities with only getters/setters, no behavior |
| God objects | One entity doing everything |
| Feature coupling | One feature depending on another's internals |
| Skipping value objects | Losing type safety and validation |

---

## Current Domains Implemented

| Domain | Status | Location |
|--------|--------|----------|
| Auth | ✅ Implemented | `lib/features/auth/` |
| Commerce | ✅ Implemented | `lib/features/commerce/` |
| Expenses | ✅ Implemented | `lib/features/expenses/` |
| Categories | ✅ Implemented | `lib/features/categories/` |
| Settings | ✅ Implemented | `lib/features/settings/` |

## Future Domains (per Constitution §15)

| Domain | Priority | Status |
|--------|----------|--------|
| Restaurant | 10 | Not started |
| Marketplace | 15 | Not started |
| Ride | 16 | Not started |
| Home Services | 17 | Not started |
| Wallet | 18 | Not started |
| Payments | 19 | Not started |
| Subscriptions | 20 | Not started |
| AI | 21 | Not started |
