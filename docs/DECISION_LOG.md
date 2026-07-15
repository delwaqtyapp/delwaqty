# Architectural Decision Log

This document records significant architectural decisions made during the development of Delwaqty. Each decision includes context, rationale, and consequences.

---

## ADR-001: Use Clean Architecture

**Date:** Sprint 1
**Status:** Accepted
**Deciders:** Core team

### Context
Delwaqty needs a scalable architecture that supports multiple feature teams, testability, and long-term maintainability.

### Decision
Adopt **Clean Architecture** with four layers: Presentation, Domain, Data, and Core. Features are organized in a feature-first directory structure.

### Rationale
- Enforces separation of concerns
- Domain layer has zero external dependencies (pure Dart + Freezed)
- Testable at every layer (mock data sources, mock repositories, widget tests)
- Clear dependency flow: Presentation → Domain ← Data, Core supports all layers

### Consequences
- More files per feature (entities, repositories, data sources, providers)
- Requires discipline to maintain layer boundaries
- Benefits compound as the codebase grows

---

## ADR-002: FeatureModule Plugin System

**Date:** Sprint 7
**Status:** Accepted
**Deciders:** Core team

### Context
As features grew, adding new modules required modifying core files (router, shell, drawer). This violated the Open/Closed Principle.

### Decision
Implement a `FeatureModule` plugin architecture where each feature registers itself with the platform core. The core never needs modification to add new features.

### Rationale
- Adding a new module = one class + one registration line
- Module lifecycle hooks (onRegister, onActivate, onDeactivate)
- Dependency resolution via topological sort
- Dynamic route, navigation, and drawer generation from modules
- Badge aggregation across modules

### Consequences
- Core is stable and rarely changes
- New features can be developed independently
- Modules can be enabled/disabled by commenting out registration
- Requires all modules to follow the FeatureModule contract

---

## ADR-003: Freezed for Immutable Entities

**Date:** Sprint 1
**Status:** Accepted
**Deciders:** Core team

### Context
Mutable data models lead to unpredictable state changes and make equality comparison unreliable.

### Decision
Use `freezed` for all domain entities and data models. Entities are immutable with `copyWith` methods.

### Rationale
- Immutable by default prevents accidental mutation
- Built-in `==`, `hashCode`, `toString`, `copyWith`
- Union types for state modeling (AuthState: loading, authenticated, unauthenticated, error)
- JSON serialization via `json_serializable`

### Consequences
- Requires `build_runner` for code generation
- Generated files (`.freezed.dart`, `.g.dart`) are committed
- `explicit_to_json: true` in `build.yaml` for nested entities
- Slightly more boilerplate but significantly more safety

---

## ADR-004: Riverpod for State Management

**Date:** Sprint 1
**Status:** Accepted
**Deciders:** Core team

### Context
Need a state management solution that supports dependency injection, testability, and doesn't require BuildContext for provider access.

### Decision
Use `flutter_riverpod` for all state management and dependency injection.

### Rationale
- Compile-time safety (no runtime provider-not-found errors)
- Provider overrides enable easy testing and mock injection
- Doesn't require BuildContext (unlike Provider/InheritedWidget)
- AutoDispose for resource management
- Well-documented and actively maintained

### Consequences
- All providers are top-level or in module files
- Provider overrides happen at ProviderScope level in `main.dart`
- Riverpod providers are the single source of truth for shared state
- Module-specific providers live in module files

---

## ADR-005: GoRouter for Routing

**Date:** Sprint 1
**Status:** Accepted
**Deciders:** Core team

### Context
Need declarative routing with auth guards, shell routes for bottom navigation, and deep link support.

### Decision
Use `go_router` for all routing, built dynamically from the FeatureRegistry.

### Rationale
- Declarative route definition
- StatefulShellRoute for bottom navigation preservation
- Auth redirect for protected routes
- Deep link support via route paths
- URL-based navigation for web platform

### Consequences
- Router is built from module registrations (no central route file)
- Auth guard is a single redirect function
- Shell routes preserve state across tab switches
- Standalone routes bypass the shell (login, splash, commerce)

---

## ADR-006: Mock Repositories for Development

**Date:** Sprint 5
**Status:** Accepted
**Deciders:** Core team

### Context
Backend (Supabase) is being developed in parallel. Frontend needs to be fully functional without backend connectivity.

### Decision
Every repository has a mock implementation that returns realistic sample data. Mock is the default provider; real implementations are swapped in via provider overrides.

### Rationale
- Frontend and backend can be developed in parallel
- App is always runnable (no broken builds due to backend changes)
- Mock data represents real Saudi merchants and products
- Easy to test UI with controlled data

### Consequences
- Mock repositories are committed to the repository
- Switching to real backend requires one provider override change
- Mock data must be kept realistic and up-to-date
- Real implementations go in `data/repositories/` (not mock)

---

## ADR-007: Abstract Service Interfaces

**Date:** Sprint 9
**Status:** Accepted
**Deciders:** Core team

### Context
External services (payments, maps, AI) will be integrated over time. Need to decouple business logic from specific service implementations.

### Decision
Define abstract interfaces for all external services. Concrete implementations are provided via Riverpod providers.

### Rationale
- Can swap service providers (e.g., switch from Stripe to Tap Payments)
- Business logic never depends on specific SDK implementations
- Enables testing with mock service implementations
- Future-proofs for new service integrations

### Consequences
- Extra layer of abstraction (interface + implementation)
- Required for all external integrations (payments, maps, AI, etc.)
- Provider overrides handle the wiring

---

## ADR-008: Merchant-Type Agnostic Commerce Engine

**Date:** Sprint 8
**Status:** Accepted
**Deciders:** Core team

### Context
The commerce engine needs to support restaurants, grocery stores, pharmacies, electronics, furniture, fashion, and future merchant types — without code branching per type.

### Decision
Build a single, type-agnostic commerce engine. MerchantType is a data flag that drives display labels/icons only, not business logic branches.

### Rationale
- One codebase for all merchant types
- New merchant types require zero code changes (just a new enum value)
- Screens, widgets, and repositories work identically for all types
- Reduces testing surface (test one flow, not N flows)

### Consequences
- All commerce screens are type-agnostic
- Merchant type drives UI labels/icons, not logic
- Future merchant types are added via enum extension only
- Requires discipline to avoid type-specific branching

---

## ADR-009: Unified Design System with Tokens

**Date:** Sprint 9
**Status:** Accepted
**Deciders:** Core team

### Context
Visual consistency across features requires a centralized design system. Hardcoded colors and spacing lead to inconsistencies.

### Decision
Implement a design token system with `AppColors` (semantic colors, merchant type colors, order status colors) and `AppSpacing` (consistent spacing values). All theme configuration flows through `AppTheme`.

### Rationale
- Single source of truth for visual identity
- Light/dark mode support via token variants
- Merchant type colors are consistent across the app
- Order status colors match real-world semantics
- Easy to rebrand by updating tokens

### Consequences
- No hardcoded colors in widgets (use AppColors)
- No hardcoded spacing values (use AppSpacing)
- Theme changes propagate automatically
- New color categories are added to AppColors

---

## ADR-010: Provider-Agnostic AI Engine

**Date:** Sprint 12 (Planned)
**Status:** Proposed
**Deciders:** Core team

### Context
AI capabilities (LLM, recommendations, voice) need to be integrated but the specific provider may change.

### Decision
Define an abstract `AiEngine` interface. Concrete implementations for OpenAI, Gemini, Claude are provided via Riverpod providers.

### Rationale
- Can switch AI providers without changing business logic
- Enables testing with mock AI responses
- Future-proofs for new AI providers
- Supports fallback strategies (try provider A, fall back to B)

### Consequences
- Abstract interface required before any AI integration
- Provider selection happens at the platform level
- Business logic never imports specific AI SDK

---

## ADR-011: UUID-Based Entity Identification

**Date:** Sprint 1
**Status:** Accepted
**Deciders:** Core team

### Context
Entities need unique identifiers that work across distributed systems (client, Supabase, future microservices).

### Decision
Use UUID v4 strings for all entity identifiers. Supabase generates UUIDs by default.

### Rationale
- Globally unique without coordination
- Supported natively by Supabase (`gen_random_uuid()`)
- No sequential guessing (security benefit)
- Works offline (client can generate UUIDs)

### Consequences
- All `id` fields are `String` type
- UUIDs are generated at entity creation time
- No integer-based IDs anywhere in the domain layer

---

## ADR-012: Soft Delete Pattern

**Date:** Sprint 9
**Status:** Accepted
**Deciders:** Core team

### Context
Hard deletes destroy data permanently. Admin and audit requirements need historical data.

### Decision
Use soft delete pattern: entities have a `deletedAt` timestamp. Queries filter out soft-deleted records by default.

### Rationale
- Data is never permanently lost
- Supports admin audit trails
- Enables data recovery
- Historical analytics remain accurate

### Consequences
- All entity queries must filter `deletedAt IS NULL`
- Admin panel can show deleted records
- Permanent deletion requires explicit admin action
- Slightly more complex queries but significantly safer

---

## Summary

| ADR | Decision | Status | Impact |
|-----|----------|--------|--------|
| 001 | Clean Architecture | Accepted | Foundation of entire codebase |
| 002 | FeatureModule Plugin System | Accepted | Core architectural pattern |
| 003 | Freezed for Entities | Accepted | Data model standard |
| 004 | Riverpod for State Management | Accepted | DI and state standard |
| 005 | GoRouter for Routing | Accepted | Navigation system |
| 006 | Mock Repositories | Accepted | Development workflow |
| 007 | Abstract Service Interfaces | Accepted | External service integration |
| 008 | Type-Agnostic Commerce | Accepted | Commerce engine design |
| 009 | Design Tokens | Accepted | Visual consistency |
| 010 | Provider-Agnostic AI | Proposed | Future AI integration |
| 011 | UUID Identification | Accepted | Entity identity |
| 012 | Soft Delete | Accepted | Data safety |
