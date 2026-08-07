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

## ADR-013: Workspace Location at /root/Projects/delwaqty

**Date:** Sprint 10
**Status:** Accepted
**Deciders:** Core team

### Context
The project needs a consistent, reproducible workspace location that works for local development and can be backed up.

### Decision
Place the workspace at `/root/Projects/delwaqty` with a dedicated backup directory at `/root/Projects/delwaqty_backup_<timestamp>`.

### Rationale
- Predictable location for CI/CD and automation scripts
- Backup directory follows timestamped naming for easy identification
- Separates project from other workspace files
- All build scripts assume this as the root directory

### Consequences
- Build scripts and setup scripts assume `/root/Projects/delwaqty` as working directory
- Backup is manual (not automated in CI)
- Migration to a different machine requires updating paths in documentation

---

## ADR-014: Environment Variables via --dart-define

**Date:** Sprint 9
**Status:** Accepted
**Deciders:** Core team

### Context
Secrets (API keys, database URLs) must not be committed to version control. Need a build-time injection mechanism that works with both `flutter run` and `flutter build`.

### Decision
Use `--dart-define` for all secrets. Config classes (`SupabaseConfig`, `MapsConfig`, `CloudflareConfig`) read values via `String.fromEnvironment()`. A `.env` file is supported via `--dart-define-from-file=.env`.

### Rationale
- No secrets in source code or `.env` committed to git
- Works with `flutter run` and `flutter build`
- `.env` file support via `--dart-define-from-file` for convenience
- Compile-time constants enable tree-shaking
- Separate dev/prod configs via different variable names

### Consequences
- Every developer needs a `.env` file (template provided via `.env.example`)
- Build commands require `--dart-define` flags or `--dart-define-from-file`
- No runtime secret rotation (requires rebuild)
- Config classes are `abstract final` — no instantiation, no mutation

---

## ADR-015: Cloudflare for CDN/Storage (Not Replacing Supabase)

**Date:** Sprint 9
**Status:** Accepted
**Deciders:** Core team

### Context
Asset delivery (images, static files) needs a CDN for performance. Supabase handles the database and auth, but static asset delivery is better handled by a dedicated CDN.

### Decision
Use Cloudflare R2 for asset storage and Cloudflare CDN for delivery. Cloudflare does NOT replace Supabase as the primary database or auth provider.

### Rationale
- Supabase remains the primary database (PostgreSQL) and auth provider
- Cloudflare R2 provides S3-compatible object storage at lower cost
- Cloudflare CDN provides global edge caching for asset delivery
- Separation of concerns: database vs. asset delivery
- CDN domain (`cdn.delwaqty.com`) can be changed without affecting database

### Consequences
- Two separate infrastructure providers to manage
- Asset URLs use Cloudflare CDN, data queries use Supabase
- Clear boundary: Supabase = data + auth, Cloudflare = assets + CDN
- `.env` file needs both Supabase and Cloudflare credentials

---

## ADR-016: APK Workflow with Timestamped Releases

**Date:** Sprint 10
**Status:** Accepted
**Deciders:** Core team

### Context
Need a consistent build process that produces testable APKs. Developers need quick builds for iteration and full builds for validation.

### Decision
Provide multiple build scripts:
- `build.sh` — Full build (pub get → analyze → test → debug APK → copy to releases/)
- `scripts/dev_build.sh` — Quick dev build without full test suite
- `scripts/test_and_build.sh` — Test first, then build release APK

### Rationale
- `build.sh` ensures quality by running analyze + test before building
- `dev_build.sh` enables fast iteration during development
- All APKs go to `releases/` directory for easy access
- `releases/Delwaqty-Latest.apk` is always the most recent build
- Git remote setup script provides one-command GitHub configuration

### Consequences
- `releases/` directory should be in `.gitignore` (binary files)
- CI/CD can use `build.sh` for automated builds
- Release builds require Android signing configuration
- APK naming is simple (not timestamped) — use git tags for versioning

---

## ADR-017: Infrastructure Integration Phase

**Date:** Sprint 11
**Status:** Accepted
**Deciders:** Core team

### Context
The project needs a structured approach to integrate external infrastructure (Supabase, Cloudflare, GitHub) into the development workflow.

### Decision
Dedicate Sprint 11 as an infrastructure integration phase, creating all necessary documentation, configuration, and CI/CD setup before proceeding with feature development.

### Rationale
- Documentation-first approach ensures reproducibility
- Multi-environment configuration prevents environment drift
- Security policies established before production deployment
- API and database plans provide clear integration targets

### Consequences
- Sprint 11 is documentation and configuration focused
- Feature development pauses until infrastructure is stable
- All team members have clear environment setup instructions
- Reduces integration risk in later sprints

---

## ADR-018: GitHub Repository Setup

**Date:** Sprint 11
**Status:** Accepted
**Deciders:** Core team

### Context
The project needs a central code repository with proper branching, access control, and CI/CD integration.

### Decision
Host the repository at https://github.com/delwaqtyapp/delwaqty with master as the primary branch.

### Rationale
- GitHub provides free hosting for private repositories
- Built-in CI/CD via GitHub Actions
- Issue tracking and project management
- Pull request workflow for code review

### Consequences
- All commits are pushed to GitHub
- Branch protection rules can be enforced
- GitHub Actions can automate builds and tests
- Fork-based workflow for external contributors

---

## ADR-019: Multi-Environment Configuration

**Date:** Sprint 11
**Status:** Accepted
**Deciders:** Core team

### Context
The app needs to connect to different Supabase projects and service endpoints depending on whether it's running in development, staging, or production.

### Decision
Use separate `.env` files for each environment (`.env.dev`, `.env.staging`, `.env.prod`) with a `.env.example` template. Inject values via `--dart-define-from-file`.

### Rationale
- Prevents accidental production data access during development
- Each environment has isolated database and auth
- Easy to switch environments by changing the env file
- Template ensures all required variables are documented

### Consequences
- Developers must maintain separate env files
- CI/CD pipelines inject environment-specific values
- Environment selection is compile-time (not runtime)
- Config classes auto-select based on build mode

---

## ADR-020: Mobile Development Workflow

**Date:** Sprint 11
**Status:** Accepted
**Deciders:** Core team

### Context
The primary development happens on a Linux aarch64 device (Termux/PRoot on Android), which has limited resources and tooling compared to a standard development machine.

### Decision
Optimize the development workflow for mobile-first development with quick iteration cycles and minimal resource usage.

### Rationale
- `dev_build.sh` skips full test suite for faster iteration
- Mock repositories eliminate need for backend connectivity
- Environment files allow quick context switching
- Build scripts handle analysis, testing, and APK generation

### Consequences
- Development can happen on a mobile device
- Full builds still require the complete pipeline
- Code generation runs on-demand, not automatically
- Testing is optional for quick iterations

## ADR-021: AGENTS.md as Permanent Governance File

**Date:** Sprint 11
**Status:** Accepted
**Deciders:** Core team

### Context

AI agents and contributors need a single, persistent reference for project rules. Chat history is ephemeral and unreliable. Rules must live in the repository itself so every agent session starts with the same governance.

### Decision

Create `AGENTS.md` at the project root containing all permanent architectural rules, development protocols, coding standards, and workflow requirements. Every AI agent MUST read this file before writing code.

### Rationale

- Repository is the single source of truth (not chat history)
- Rules persist across sessions, agents, and machines
- Every contributor (human or AI) follows identical standards
- Pre-commit gates prevent broken code from being committed
- SESSION_STATUS.md provides real-time task tracking

### Consequences

- AGENTS.md is the first file every agent reads
- SESSION_STATUS.md is updated continuously
- All architectural decisions go to DECISION_LOG.md
- All roadmap changes go to ROADMAP.md
- Agents work autonomously unless blocked by credentials or decisions

---

## ADR-022: CI/CD Pipeline Architecture

**Date:** Sprint 11
**Status:** Accepted
**Deciders:** Core team

### Context

The project needs automated quality gates and build artifact delivery. Previous CI was incomplete (no Flutter version pinning, no format check, no caching, redundant workflows).

### Decision

Single `ci.yml` workflow with four jobs: analyze (format + lint), test (with coverage), build (debug + release APK), release (GitHub Release on master push). Flutter 3.44.6 pinned. Java 17 for Android. Concurrency groups prevent duplicate runs.

### Rationale

- Pinned versions ensure reproducible builds across local and CI
- `dart format --set-exit-if-changed` enforces consistent formatting
- Separate jobs fail fast (format issue blocks test, test failure blocks build)
- Coverage artifact enables historical tracking
- Concurrency groups save CI minutes on rapid pushes
- Single workflow replaces two redundant ones (ci.yml + auto_sync.yml)

### Consequences

- Every PR is checked for format, lint, test, and build
- Master pushes produce release artifacts automatically
- Flutter version must be updated in one place (`env.FLUTTER_VERSION`)
- `dart format` must pass locally before pushing

---

## ADR-023: Windows Desktop Development Workstation

**Date:** Sprint 11
**Status:** Accepted
**Deciders:** Core team

### Context

Development moves from Linux aarch64 (Termux/PRoot) to a Windows laptop with a physical Android device (DNP NX9). Corporation restrictions prohibit global installs and system modifications.

### Decision

Portable toolchain under `E:\app\` with environment variables set per-session. Flutter 3.44.6 (Dart 3.12.2), Node.js v24.16.0, pub cache and Gradle home on E: drive.

### Rationale

- No admin privileges available
- Cross-drive I/O (C: ↔ E:) causes Kotlin incremental compilation failures
- Keeping all artifacts on one volume eliminates the issue
- Device connected via USB for direct deployment and Hot Reload

### Consequences

- Must set `$env:PUB_CACHE` and `$env:GRADLE_USER_HOME` each terminal session
- Flutter command: `& "E:\app\flutter\bin\flutter.bat"`
- Android SDK remains on C: (user profile) but Gradle cache moves to E:
- Developer Mode symlink warning is non-blocking for Android builds

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
| 013 | Workspace Location | Accepted | Development environment |
| 014 | Environment via --dart-define | Accepted | Secrets management |
| 015 | Cloudflare CDN/Storage | Accepted | Asset delivery architecture |
| 016 | APK Build Workflow | Accepted | Build and release process |
| 017 | Infrastructure Integration Phase | Accepted | Sprint 11 focus |
| 018 | GitHub Repository Setup | Accepted | Code hosting and CI/CD |
| 019 | Multi-Environment Configuration | Accepted | Environment isolation |
| 020 | Mobile Development Workflow | Accepted | Development optimization |
| 021 | AGENTS.md Governance | Accepted | AI agent rules persistence |
| 022 | CI/CD Pipeline | Accepted | Automated quality gates and artifact delivery |
| 023 | Windows Desktop Workstation | Accepted | Portable dev environment |
| 024 | Super App Presentation Layer | Accepted | 11 customer screens with premium UI |
| 025 | Finance Code Removal | Accepted | Remove expenses/budgets/categories entirely |
| 026 | RLS Security Hardening | Accepted | Replace all USING(true) with role-based policies |
| 027 | World-Class Animation System | Accepted | Animated gradients, particles, elastic, staggered reveals |
| 028 | Arabic-Default Localization & EGP Currency | Accepted | Arabic-first UX, EGP currency |
| 029 | Server-Side Ride-Hailing Domain | Accepted | 15 tables, 6 RPCs, pricing/dispatch/lifecycle |
| 030 | M3 Passenger Booking Flow | Accepted | Real backend, no mock, 6 categories, Realtime |
| 031 | M4 Dispatch Engine & Live Trip Lifecycle | Accepted | 12 RPCs, atomic claim, OTP, driver app |
| 032 | M5 Provider-Agnostic Destination Search | Accepted | Google Places, cache, debounce, saved places |
| 033 | M6 Complete Driver Platform | Accepted | Onboarding, vehicles, documents, performance, wallet |
| 034 | M7 Unified Delivery & Logistics Platform | Accepted | 9 service types, rides table reuse, delivery pricing |

---

## ADR-034: M7 Unified Delivery & Logistics Platform

**Date:** Sprint 34
**Status:** Accepted
**Deciders:** Lead Software Architect`

### Context

Through M6 the platform had a complete ride-hailing ecosystem but no delivery capability. M7 required supporting food, grocery, pharmacy, marketplace, courier, package, document, flower, and retail delivery — without duplicating the dispatch engine, driver platform, wallet, realtime, or tracking infrastructure already built.

### Decision

1. **Reuse the `rides` table as the unified dispatch table.** Add a `service_type` column (CHECK: ride + 9 delivery types) and delivery-specific columns (merchant_id, pickup/dropoff notes, delivery proof, signature/OTP flags, scheduled time, priority, items summary, weight). No new dispatch tables.
2. **Extend `drivers`** with `service_types[]`, `accepts_deliveries`, `max_delivery_distance_km`, `max_weight_kg` so drivers self-declare which services they handle.
3. **Add `delivery_pricing`** per service type (base_fee, per_km, per_kg, minimum_fee, priority/express multipliers) — seeded with 9 rows, one per delivery type. Queryable via RPC.
4. **Add `merchant_profiles`** for merchant configuration (service types, prep time, delivery radius, auto-accept).
5. **6 new RPCs:** `dispatch_delivery` (reuses nearest-driver logic), `complete_delivery` (credits driver like complete_trip), `estimate_delivery_fee` (pricing lookup), `merchant_ready_for_dispatch` (merchant confirms readiness), `get_merchant_deliveries` (merchant's orders), `update_driver_capabilities` (driver preferences).
6. **Domain layer:** `DeliveryOrder` (unified delivery entity), `MerchantProfile`, `DriverCapability`, `DeliveryPricingModel` (with `calculateFee`), `DeliveryRequest`, `DeliveryRepository` (20-method abstract interface).
7. **Presentation:** 4 new pages — `DriverDeliveryHubPage` (driver side), `MerchantOrdersPage` (merchant side), `DeliveryTrackingPage` (customer side), `DriverCapabilitiesPage` (service type preferences).

### Rationale

- The `rides` table already has pickup/dropoff coordinates, status lifecycle, driver assignment, earnings crediting, and Realtime publication. Adding delivery columns avoids a parallel dispatch system.
- `service_type` as a CHECK constraint on `rides` is the cheapest way to multiplex 10 services through one engine.
- `delivery_pricing` as a separate table (not embedded in ride_pricing) allows per-service-type tuning without touching the ride pricing.
- Driver capability declaration (`service_types[]`) enables the same dispatch engine to filter candidates by service compatibility.

### Consequences

- `flutter analyze` = 0 errors; `flutter test` = 431/431 (18 new delivery entity tests); debug APK installed and stable on DNP NX9.
- All existing M4 dispatch RPCs (`dispatch_ride`, `accept_ride_request`, `complete_trip`) remain ride-only; delivery uses the new `dispatch_delivery` / `complete_delivery` RPCs that operate on the same table with service-type guards.
- Future services (laundry, pet transport, moving) are added via a new `service_type` CHECK value + `delivery_pricing` row + UI page — zero schema migration beyond the CHECK alter.

## ADR-026: RLS Security Hardening

**Date:** Sprint 20
**Status:** Accepted
**Deciders:** Core team

### Context

Security audit revealed 16 out of ~50 RLS policies used `USING(true)` — meaning any authenticated user (or anonymous) could read/write any row. 8 tables had a merchant ownership tautology bug (`WHERE merchant_id = merchant_id` — always true). Missing DELETE policies on most tables. Missing INSERT policies for drivers, order_tracking, notifications, activity_logs.

### Decision

Create comprehensive migration `005_rls_hardening.sql` that:
1. Drops ALL existing policies
2. Creates helper functions: `get_user_role()`, `get_user_merchant_id()`, `is_admin()`, `is_merchant_owner()`
3. Applies role-based SELECT/INSERT/UPDATE/DELETE policies for all 23 tables
4. Implements hierarchy: Guest < Customer < Driver < Merchant < Admin < Owner

### Rationale

- `USING(true)` is equivalent to no security at all
- Role-based policies ensure users can only access their own data
- Helper functions centralize role logic (DRY)
- Dropping and recreating is safer than patching individual policies

### Consequences

- Migration must be applied via Supabase SQL Editor before production deployment
- All existing RLS policies are replaced (no rollback — the old ones were broken anyway)
- Role hierarchy is enforced at the database level (not just app level)

---

## ADR-027: World-Class Animation System

**Date:** Sprint 20
**Status:** Accepted
**Deciders:** Core team

### Context

The app needs to feel premium and compete with Uber/Talabat/Noon. Default Flutter animations (linear, no staging) feel generic. Core entry screens (splash, onboarding, login, home) are the first impression.

### Decision

Replace default animations with a world-class motion design system:
1. **Splash**: Animated gradient (rotating color angles), 30 floating particles, glow ring, elastic scale logo, pulse animation, staggered text fade-in
2. **Onboarding**: 6 story slides with color gradient backgrounds, elastic bounce-in emoji/icon, staggered title/description fade-up, animated dot indicator
3. **Login**: Social auth buttons (Google/Apple/Facebook/Phone), animated form shake on error, premium logo with shadow
4. **Home**: Super App hub with gradient logo container, search bar with filter, 8-category service grid, horizontal scrollable lists, promo banner

### Rationale

- First 3 seconds determine user perception of quality
- Animated gradients create depth and premium feel
- Elastic/spring animations feel physical and satisfying
- Staggered reveals prevent visual overwhelm
- Particle systems add visual richness without complexity

### Consequences

- All 4 core screens fully rewritten with new animation system
- 5 new reusable premium widgets (ShimmerLoading, PremiumEmptyState, GlassCard, AnimatedCounter, PremiumSuccessAnimation)
- 19 new localization strings for expanded onboarding and social auth
- Code is significantly more complex but provides world-class UX

---

## ADR-028: Arabic-Default Localization & EGP Currency

**Date:** Session 4 (Transportation Platform milestone)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
Delwaqty ("دلوقتي") targets an Arabic-first, Egypt/global audience. The app defaulted to the platform locale and several modules (driver, wallet, restaurant, core error handling) still rendered hardcoded English strings. Currency was hardcoded to `SAR`.

### Decision
1. Default the app locale to Arabic (`Locale('ar')`) when no user preference is stored.
2. Route every user-visible string through `AppLocalizations` (l10n) with professional Arabic translations; introduce a shared `amountWithCurrency` + `currencySymbol` pattern.
3. Switch the default currency to Egyptian Pound (`EGP` / `ج.م`).
4. For pure-Dart, context-less strings (`error_handler.dart`), embed Arabic directly since Arabic is the guaranteed default surface language.

### Rationale
- Arabic-first matches the brand and primary market; English remains available via language toggle.
- Centralized currency helpers avoid scattered hardcoded currency codes and ease future multi-currency support.
- RTL is already supported through the GlobalMaterial/Widgets/Cupertino delegates.

### Consequences
- ~140 new ARB keys (EN+AR), including a complete ride-hailing vocabulary reserved for upcoming milestones.
- Currency now originates from data (`wallets.currency`) with an `EGP` default; legacy `SAR` rows still render via the stored value.
- error_handler holds Arabic literals (acceptable trade-off vs. a full error-code refactor; revisit if English error surfaces are required).

---


## ADR-029: Server-Side Ride-Hailing Domain (Schema + RPC Engines)

**Date:** Session 4 (Milestone 2)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
The ride module shipped with a mock-fallback data source and no real backend for the ride-hailing domain (drivers, vehicles, dispatch, pricing, earnings, safety). A complete, secure server schema was required before removing mocks.

### Decision
Introduce migration `007_transportation_platform.sql` that:
1. Adds 15 domain tables (vehicles, driver_documents, ride_requests, trip_events, driver_earnings, withdrawal_requests, ride_ratings, complaints, driver_locations, saved_places, trusted_contacts, favorite_drivers, promo_codes, promo_redemptions, ride_pricing).
2. Extends `rides`/`drivers` with pricing breakdown, surge, promo, OTP, payment, verification, and trip counters; expands ride categories to economy/comfort/premium/xl/motorbike/taxi.
3. Implements pricing/dispatch/lifecycle as SECURITY-scoped Postgres RPCs: `estimate_fare`, `find_nearest_drivers`, `accept_ride`, `advance_ride`, `validate_promo`, plus a PostGIS-free `haversine_km` helper.
4. Enforces RLS on every new table (owner/participant scope; public read only for pricing, active promos, ratings).

### Rationale
- Server-authoritative pricing and dispatch prevent client tampering with fares and driver assignment.
- `accept_ride`/`advance_ride` use row locks (`FOR UPDATE`) for atomic, race-free trip state transitions and OTP-gated trip start.
- `haversine_km` avoids a PostGIS dependency on the managed instance while enabling nearest-driver queries.
- Idempotent DDL (`IF NOT EXISTS`, `DROP POLICY IF EXISTS`) keeps the migration safely re-runnable.

### Consequences
- Dart ride/driver data sources can now call real RPCs; mock fallback is scheduled for removal in M4.
- Fare config lives in `ride_pricing` (data-driven, EGP) and is tunable without redeploys.
- Migration comments are ASCII-only after the Management API rejected UTF-8 box-drawing characters in the JSON payload.

---

## ADR-030: M3 Passenger Booking Flow on Real Backend (No Mock)

**Date:** Sprint 30
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
With the M2 transportation schema and RPCs live, the passenger ride module still relied on a mock-fallback data source. M3 required the full passenger journey (pickup -> destination -> map -> fare -> 6 categories -> ETA -> breakdown -> promo -> book -> driver search -> acceptance -> OTP -> Realtime tracking) to run entirely on the real backend.

### Decision
1. Remove all mock data from `supabase_ride_data_source.dart`; call real RPCs (`estimate_fare`, `validate_promo`, `find_nearest_drivers`, `accept_ride`/`advance_ride`) and map M2 columns via `_rideFromRow`.
2. Expand `RideType` to 6 categories with `RideTypeX` capacity metadata; extend the `Ride` entity with pricing breakdown, promo, payment, OTP, and currency. Add `FareQuote`/`PromoResult`/`NearbyDriver` entities.
3. Use Supabase Realtime (`.stream(primaryKey:['id'])`) for `watchRide`, surfaced via `rideStreamProvider`; drive tracking UI from live ride status.
4. Integrate `google_maps_flutter` through a dedicated `RideMap` widget (markers + polyline + fitBounds) and a localized `RideTypeInfo` presenter.
5. Rename the l10n key collision `estimatedArrival` (no-arg, commerce) by adding a distinct parameterized `arrivesInMinutes` for ride ETA.

### Rationale
- Server-authoritative fare/promo/dispatch keeps pricing and matching tamper-proof; the client only renders quotes.
- Realtime streams give the passenger accurate, push-based trip status without polling.
- A single `RideMap`/`RideTypeInfo` abstraction keeps booking and tracking pages consistent and reusable.
- Distinct ARB keys avoid gen-l10n inferring conflicting placeholder signatures for a shared key.

### Consequences
- `flutter analyze` = 0 errors / 0 warnings; `flutter test` = 366/366; debug APK installed and stable on DNP NX9.
- Driver-side acceptance is out of M3 scope: passengers stay on "searching" until a driver is assigned (Realtime flips to `matched`); built in M4/M6.
- Dropoff currently uses a positional offset placeholder; destination search/geocoding UI is deferred.

---

## ADR-031: M4 Dispatch Engine & Live Trip Lifecycle

**Date:** Sprint 31
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
M3 delivered the passenger booking flow but left rides stuck on `searching` because no driver-side dispatch or acceptance existed. M4 required a server-authoritative dispatch engine plus a driver ride app implementing the full trip lifecycle (offer -> accept -> arrive -> OTP -> start -> complete/cancel), earnings crediting, and withdrawals, all on the real backend with no mock data.

### Decision
1. Add `008_dispatch_engine.sql` with 12 RPCs (`dispatch_ride`, `accept_ride_request`, `reject_ride_request`, `driver_arrive`, `start_trip`, `complete_trip`, `cancel_ride_lifecycle`, `driver_set_online`, `driver_update_location`, `rate_passenger`, `driver_dashboard_stats`, `request_withdrawal`). Offers expire after 20s; unaccepted rides reassign via `reassign_count`. Acceptance is atomic (single-winner claim) and generates the pickup OTP.
2. Map the granular spec lifecycle (requested/accepted/driver_arriving/otp_verified/trip_started) onto the DB constraint states (`searching/matched/arrived/inTrip/completed/cancelled`) using `trip_events` + flag columns, avoiding a destructive constraint change.
3. Add `009_driver_onboarding.sql` with `register_ride_driver` (creates driver + active verified vehicle) and a `drivers.status` column synced to `is_online` via trigger for legacy compatibility. Dispatch requires a verified driver with an active vehicle whose `category` matches the ride type.
4. Encode legal transitions client-side as `RideStatusX` (`canTransitionTo`/`isTerminal`/`isActive`) mirroring the server machine, and unit-test it.
5. Push-based driver flow via Supabase Realtime: `watchOffers` (ride_requests joined to rides) and `watchActiveDriverRide` (rides). Online location updates stream from Geolocator to `driver_update_location`.
6. Passenger `confirmRide` now triggers `dispatch_ride` after `requestRide`; passenger cancel routes through `cancel_ride_lifecycle` (unified cancellation with `cancelled_by` attribution).

### Rationale
- Atomic server-side claim prevents double-assignment races; server-generated OTP keeps pickup verification tamper-proof.
- Mapping onto existing DB states preserves the M2 constraint and RLS while still expressing the richer lifecycle via events/flags.
- Mirroring the transition map in Dart lets the UI guard actions and fail fast without a round trip, while the server remains authoritative.
- Realtime offers/active-ride streams avoid polling and give drivers immediate, cancellable offers.

### Consequences
- `flutter analyze` = 0 errors / 0 warnings; `flutter test` = 375/375 (9 new dispatch-entity tests); debug APK installed and stable on DNP NX9.
- Driver ride app (`/driver/rides`, `/driver/trip/:id`, `/driver/earnings`) is now reachable from the driver dashboard.
- On-device interactive lifecycle walkthrough is not automated; verification relies on state-machine unit tests + live RPCs + launch stability.
- Destination search/geocoding remains deferred to M5.

---

## ADR-032: M5 Provider-Agnostic Destination Search & Geocoding

**Date:** Sprint 32
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
Through M4 the dropoff location used a positional-offset placeholder (`pickup +/- ~0.01 deg`), so trips had fake destinations. M5 required a real, Uber/Careem-class destination search: autocomplete, place details, reverse geocoding, nearby search, saved places (home/work/favorites), recent searches, Arabic + English, billing session tokens, debouncing, caching, and graceful failure - without hardcoding any API key or locking the app to a single vendor.

### Decision
1. Introduce a provider-agnostic `GeocodingProvider` contract (autocomplete / details / reverseGeocode / nearbySearch) plus a normalized `GeocodingException` taxonomy. UI and business logic depend only on this interface; providers are swappable.
2. Implement `GooglePlacesProvider` as the first provider (Autocomplete + Place Details + Geocoding reverse + Nearby Search), reading the key from the existing `AppConfig.mapsApiKey` env config - no key in source.
3. Add a business-facing `PlacesRepository`/`PlacesRepositoryImpl` that composes the provider with a Supabase-backed `saved_places` data source and a local `RecentSearchesStore` (shared_preferences, last 8), and layers `TtlCache` (LRU+TTL) over autocomplete/details/reverse.
4. Model the Places billing session token generically as `SearchSession` (providers that don't need it ignore it); reset it after each committed selection. Debounce the input at 350ms via a reusable `Debouncer`.
5. Map Google response statuses to `GeocodingException` kinds (OVER_QUERY_LIMIT/429 -> rateLimited, REQUEST_DENIED -> denied, timeouts/socket -> network) and surface a retry UI.
6. `DestinationSearchPage` returns a `PlaceDetails` to the caller; the booking page pushes it for dropoff and drives the Home/Work chips from real saved places, deleting the offset placeholder.

### Rationale
- An interface-first design future-proofs the platform: adding Mapbox/Nominatim/HERE/TomTom is a data-layer change with zero UI/business impact, satisfying the reusability and modularity rules.
- Session tokens + debounce + caching materially cut Places billing and latency, matching production ride-hailing apps.
- Keeping the key in env config preserves the project's secret-handling policy (no credentials in source).
- A normalized error taxonomy lets the UI degrade gracefully under rate limits and offline conditions.

### Consequences
- `flutter analyze` = 0 errors / 0 warnings; `flutter test` = 400/400 (25 new); debug APK installed and stable on DNP NX9.
- The Google Cloud key must have Places API + Geocoding API enabled and permit the app's requests - a console step outside the codebase.
- "Set on map" pin-drop for saving Home/Work from search is stubbed; full map pin-drop is a follow-up.

---

## ADR-033: M6 Complete Driver Platform

**Date:** Sprint 33
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
Through M4-M5 the driver had a minimal ride hub (online toggle, offer accept/reject, trip lifecycle, basic earnings). M6 required a production-ready driver platform: complete onboarding (personal info, national ID, license, vehicle registration, insurance, photos), vehicle management for multiple vehicle types (future-proofed for cars, motorcycles, scooters, vans, pickups), document management with status tracking, a full dashboard with performance metrics (acceptance rate, cancellation rate, monthly earnings, bonuses, incentives), a wallet with detailed breakdown, and an approval workflow — all in Arabic, using real Supabase RPCs, no mocks.

### Decision
1. **Schema-first:** Migrated first (010_driver_platform.sql), extending `drivers` (onboarding fields: national_id_number, address, profile_photo_url, background_check_status, onboarding_completed, onboarding_step), `vehicles` (photo_url, is_verified, registration_expires_at, insurance_expires_at), and `driver_documents` (vehicle_photo + profile_photo doc types, file_name, file_size). Added 9 new RPCs for onboarding, document upsert, vehicle CRUD, wallet detail, and performance stats. Added realtime publications for driver_earnings, wallets, withdrawal_requests, driver_documents.
2. **Domain expansion:** New entities `Vehicle` (Freezed, 10 category types), `DriverDocument` (Freezed, 6 doc types), `WalletDetail` (bonus/incentive/pending/withdrawn), `DriverPerformance` (15 fields: trips, ratings, acceptance/cancellation rates, today/week/month earnings, wallet breakdown). Extended `DriverProfile` with onboardingCompleted, onboardingStep, verificationStatus.
3. **Data layer:** New `SupabaseDriverPlatformDataSource` for all 9 RPCs, keeping the existing dispatch and driver data sources separate (single-responsibility). Extended `DriverRepositoryImpl` with a second data source dependency.
4. **Presentation:** 6-step onboarding wizard (`DriverOnboardingPage` via PageView), vehicle management list + add/edit bottom sheet, document management with status badges, rewritten dashboard with 4-section layout (online header, earnings overview, performance grid, action grid + vehicle info), enhanced earnings with wallet breakdown card. All Arabic, all real backend, no placeholder screens.
5. **Dispatch integration unchanged:** The existing `complete_trip` RPC already credits `driver_earnings` and updates `drivers.earnings_balance` automatically; `get_driver_performance` and `get_driver_wallet_detail` aggregate across the same tables, so earnings/wallet update in realtime after trip completion without additional wiring.

### Rationale
- Schema-first avoids the N+1 migration anti-pattern; all new columns ship in a single migration.
- Separate data sources preserve the existing code structure and prevent the dispatch data source from growing unbounded.
- The onboarding wizard uses `PageView` with `NeverScrollableScrollPhysics` to enforce sequential completion, matching production driver apps.
- 10 vehicle categories future-proof the schema for delivery services (M7) without additional migrations.
- The performance RPC computes acceptance/cancellation rates server-side to avoid client-side race conditions.

### Consequences
- `flutter analyze` = 0 errors / 0 warnings; `flutter test` = 413/413 (13 new entity tests); debug APK installed and stable on DNP NX9.
- Document upload uses placeholder SnackBar — requires Supabase Storage integration for production file upload.
- Admin approval workflow (approve/reject drivers + documents) needs a Supabase admin dashboard — the schema supports it but no admin UI exists.
- Background verification status is schema-ready but no external background check API is integrated.

---

## ADR-017: Management Platform — Complaints, Sanctions, Live Tracking, Support Chat

**Date:** Sprint 40
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
The platform needed admin tools for handling user complaints, issuing sanctions, tracking drivers in real-time, and providing support chat between users and admins.

### Decision
Create 4 new Clean Architecture feature modules (`complaints`, `sanctions`, `location_tracking`, `support_chat`), a single Supabase migration with 5 new tables + RLS + Storage buckets, and integrate admin pages as nested routes under the existing AdminModule.

### Rationale
- **4 separate modules** — independently testable, follow existing architecture, modular.
- **5 tables in one migration** — co-designed schema prevents future N+1 migrations.
- **AdminModule nested routes** — consistent with existing `/admin/users`, `/admin/orders` pattern.
- **Supabase Realtime** — used for chat messages and location updates (no polling).
- **GIN index on participant_ids** — efficient `@>` containment queries for chat room lookup.

### Consequences
- Complaints → Sanctions connection: complaints can escalate to sanctions via `complaint_id` FK.
- Support Chat → Complaints connection: chat rooms can be linked to complaints via `complaint_id`.
- Location tracking: map view placeholder requires a Google Maps/Mapbox API key for production.
- Client-side pages (`/my-complaints`, `/support`, `/new-complaint`) added as standalone routes.
- `flutter analyze` = 0 errors; `flutter test` = 517/517 passing.
- Admin dashboard quick actions and sidebar entries added for all 4 new domains.

---

## ADR-034: UI Polish — Cairo Typography, Card System & Micro-Interactions

**Date:** Sprint 55
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
The app rendered Arabic with the default Roboto typeface and used inconsistent card radii, flat image placeholders, and hardcoded category colors. The home screen needed professional delivery-app quality (Uber Eats / Talabat reference).

### Decision
1. **Typography:** Add `google_fonts` and render **Cairo** (native Arabic + Latin) by wrapping `AppTextStyles.toTextTheme()` with `GoogleFonts.cairoTextTheme()` in `AppTheme._buildTheme`; expose `AppFontFamily.cairo` token.
2. **Colors:** Centralize the home service-grid palette into 8 `service*` tokens in `AppColors` and reference them instead of inline hex.
3. **Cards:** Standardize radius (merchant 20, product 16), replace flat elevation with soft shadows + subtle borders, use gradient image placeholders, and switch badges to pills.
4. **Micro-interactions:** Add reusable `shared/widgets/pressable_scale.dart` (press-scale tactile feedback) wired into service tiles and home merchant cards.
5. **Home:** Pill-shaped search bar; promo banner radius 24 with tap-to-copy coupon (`DELWAQTY30`) + `copyCode`/`codeCopied` l10n keys.

### Rationale
- Cairo is purpose-built for Arabic UI and matches the app's bilingual scope.
- A single `google_fonts` integration avoids bundling/managing font files while keeping offline caching after first fetch.
- Centralizing category colors prevents drift between the home grid and merchant-type colors.
- Soft shadows + gradient placeholders read as modern and improve placeholder states for merchants without images.
- Press-scale feedback requires no gesture-controller boilerplate and is reusable app-wide.

### Consequences
- `google_fonts` added to `pubspec.yaml`; first frame may briefly fall back before the font asset loads (cached thereafter).
- Letter-spacing tokens tuned for Latin remain unchanged; Arabic renders acceptably with Cairo.
- `flutter analyze` = 0 errors; `flutter test` = 517/517 passing; debug APK rebuilt and installed on DNP NX9.
- **Deferred decision:** the bottom-nav tab set remains Home / Direct Delivery / Ride / Settings. Promoting Search + Profile to nav modules and adding an Orders branch is a functional routing change requiring a product decision.


---

## ADR-035: Functional Bottom-Nav Restructure — 4-Tab Layout

**Date:** Sprint 56
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
The bottom navigation was built from every `isNavModule` module, producing tabs Home / Direct Delivery / Ride / Settings. As a super-app, the primary consumer flows are discover (Home), search (Search), track purchases (Orders), and identity (Profile). Settings/Delivery/Ride are secondary actions that belong inside screens, not permanent tabs. The product decision was approved: a professional 4-tab layout Home / Search / Orders / Profile.

### Decision
1. **Tabs** are still derived from `FeatureRegistry.navModules` (sorted by `navPriority`): Home (10), Search (20), Orders (30), Profile (40) — the tab set is a module-registration concern, not hardcoded in the shell.
2. **SearchModule** promoted to nav module with branch `/search` rendering the existing commerce `SearchPage`; the home search bar now switches tabs via `context.go('/search')` instead of pushing `/market/search`.
3. **New OrdersModule** (`lib/features/orders/`) with nav branch `/orders` → existing commerce `OrdersPage`; `/orders` added to `restrictedRoutes` so guests are redirected to login; declares `dependsOn: ['commerce']`.
4. **ProfileModule** promoted to nav module with branch `/profile`; a gear action in its AppBar opens `/settings`; drawer/sidebar `/profile` targets use `go` to switch the tab.
5. **SettingsModule / DirectDeliveryModule / RideModule** demoted to non-nav. `/settings` becomes a `shellSubRoute` wrapped in `Scaffold` + `AppBar`; `/direct-delivery` and `/ride/book` become `standaloneRoutes`. RideModule was re-enabled (was commented out) so the home ride tile's `/ride/book` push resolves.
6. **AppShell** drops its global AppBar; the menu button moved into the Home header (floating sidebar still opens there). `extendBody` changed to `false` so branch pages with their own Scaffold/AppBar are never overlapped by the floating pill.
7. **DirectDeliveryPage** gained its own `AppBar` (previously relied on the shell AppBar).

### Rationale
- Keeps navigation fully module-driven: adding/removing a tab is a one-line registry change.
- Reuses existing pages (SearchPage, OrdersPage) instead of creating placeholder scaffolds — no duplicated UI.
- Secondary services stay reachable (Home grid tiles, Profile gear) without consuming permanent tab space.
- Removing the shell AppBar avoids double AppBars now that Search/Orders/Profile own their headers, and lets each tab carry its own header affordances (menu on Home, gear on Profile).
- Re-enabling RideModule restores the intended ride entry point; the previous `ModuleCapability.requiresMap`/`hasLocation` design is preserved.

### Consequences
- Guest flow: Search tab is open, Orders tab redirects to login (`restrictedRoutes`), Profile shows the existing guest CTA.
- `module_registry.dart` now registers `OrdersModule` and `RideModule`; `/market/search` and `/market/orders` remain registered (deep-link/legacy pushes), `/orders` and `/search` are the tab roots.
- Home header gained a menu button; the global notifications button is unchanged (Home header badge).
- `flutter analyze` = 0 errors; `flutter test` = 517/517; debug APK built, installed, and 4 tabs smoke-tested on DNP NX9 with no crashes.


---

## ADR-036: Location Reliability — Stale-Proof but Real-Fix-Aware Acquisition Gate

**Date:** Sprint 57
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
Session 21d fixed a real bug: Android's FusedLocationProvider replayed a 9-day-old cached location with a fresh `getTime()`, so the app reverse-geocoded a stale place (`شاليهات مارفيل`) that was not where the user was. The fix required `satellitesUsedInFix > 0` (GNSS-only) plus ≤ 2 min freshness for every accepted fix. On the target device this over-corrected: network/fused fixes always carry `satellitesUsedInFix = 0`, and the last real GPS fix was ~35 min old — so the app showed `الموقع غير متاح` forever even though real fresh fixes existed. `dumpsys location` re-analysis proved `et=` is elapsed-since-boot, not fix age: the network/fused last-fixes were ~1 min old.

### Decision
1. Keep the 2 min freshness window for live stream fixes (`_maxFixAge`) — the anti-replay shield for anything the platform re-attributes.
2. Add a **10 min last-known cap** (`_maxLastKnownAge`): any last-known older than 10 min (e.g. the 9-day cache) is still refused.
3. **`_isUsableLastKnown`**: ≤ 10 min old; GNSS-verified positions always usable; non-GNSS (network/fused) usable only when `0 ≤ accuracy ≤ 500 m`. The fresh 100 m fused/network fix is now usable; the old 500 m cap replaces the impossible GNSS-only requirement.
4. **`_acquirePreciseFix`**: fresh stream samples no longer require GNSS verification to accumulate as `best`; GNSS verification is required only for the ≤ target-meter (1 m) early-lock shortcut. `waitSeconds` = 45 only when deep AND no usable last-known, else 12, so the deep lock no longer hangs.
5. `_bestAvailablePosition`: fresh GNSS ≤ 1 m last-known returns immediately; quick mode returns a usable last-known without opening a stream; otherwise stream acquisition with usable-last-known fallback.

### Rationale
- The anti-stale property the user actually needs is "never show a location older than a bounded window", not "only show GNSS positions". The 10 min / 500 m bounds preserve that property while admitting the device's real fresh fixes.
- GNSS verification remains the gate for the 1 m precision lock (a 1 m claim genuinely requires live GNSS), but must not block the app from showing the user's actual area.
- Degrades gracefully: no live GNSS → best fresh stream sample or usable last-known, instead of `الموقع غير متاح`.

### Consequences
- Home header resolves the user's real address (~100 m fused fix) instead of `الموقع غير متاح`.
- The 9-day replay protection remains: anything > 10 min old is still refused.
- 1 m lock still requires open sky (live GNSS); indoors it now fills best-effort with a snackbar instead of nothing.
- `location_provider_test.dart` grew 10 → 14 tests covering the new tiers; suite 531/531; `flutter analyze` 0 errors; debug APK rebuilt, installed, and both Home header and deep-lock (`حدد موقعي`) verified on DNP NX9 showing `شاليهات مارفيل، بلو باي اسيا، السويس، مصر`.

---

## ADR-037: Functional Instant Push Notifications — Realtime Broadcast + Fixed Token Pipeline

**Date:** Sprint 57
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
The admin push-notification page rendered but the system was non-functional end-to-end:
1. **Schema mismatch:** `notification_tokens` (migration 002) only had `created_at`, but the service and the admin dashboard already persisted/read `updated_at`. Every query against the deployed table threw, so `_saveToken` silently failed (tokens never stored) and the dashboard's "connected devices" card showed a generic error.
2. **RLS:** `notification_tokens` policy only allowed `auth.uid() = user_id`, so admins could never list devices. Additionally, the legacy `notifications` "Service role can insert" policy was `WITH CHECK (true)` with no role restriction — any authenticated user could insert a notification for any user.
3. **No send path:** the admin page could only copy an FCM payload for manual pasting into the Firebase console. Real FCM HTTP v1 sending needs a service-account credential (external, not available at the time).
4. **Upsert bug:** `_saveToken` used `onConflict: 'token'`, but no unique index exists on `token` alone (the table has `UNIQUE(user_id, token)`) — so even the upsert failed.
5. `platform` was written as `defaultTargetPlatform.name`, which violates the column's `CHECK (platform IN ('android','ios'))` on desktop/fuchsia builds.

### Decision
1. **Migration `018_push_notification_platform.sql`:** add `updated_at` (with auto-update trigger) + `user_id` index to `notification_tokens`; admin SELECT-all-tokens policy (`public.is_admin()`); admin INSERT/SELECT/DELETE policies on `notifications`; restrict the legacy "Service role can insert" policy to `service_role`; add `notifications` to the `supabase_realtime` publication; add an admin-only `SECURITY DEFINER` RPC `admin_broadcast_notification(p_title, p_body, p_type, p_deep_link, p_target_role, p_target_user_id)` that inserts one `notifications` row per matching user and returns the recipient count.
2. **PushNotificationService:** fix the upsert conflict target to `user_id,token`; normalize `platform` to `android`/`ios`; set up a Supabase Realtime channel on `notifications` INSERT (RLS-scoped to the current user) that shows a local notification and invalidates `notificationsProvider`/`unreadCountProvider` — instant in-app push that works today with no external credentials. Realtime setup runs regardless of FCM permission so the in-app center/badge always receive broadcasts.
3. **Admin page:** real "send" button that calls the RPC with an audience selector (all / customer / driver / merchant / admin), a notification-type selector (`info`/`warning`/`success`/`reminder`), optional deep link, and a recipient-count result; the Firebase console copy path remains as a secondary option; connected-devices card gained a retry button and a specific failure message instead of a generic error; tokens refresh after send. Pure logic extracted into `buildBroadcastParams` for testing.

### Rationale
- The in-app `notifications` table + Realtime already delivered the whole user experience (center, unread badge, tap-to-open); wiring the admin broadcast into that path makes instant notifications work end-to-end without waiting on FCM service-account credentials, which remain an external blocker.
- The schema/RLS/upsert fixes remove every verified failure point in the token pipeline so the connected-devices list becomes real data.
- FCM background/terminated push stays available: the copied payload targets `all` or `role_<role>` topics and becomes active once a service account is configured.

### Consequences
- Admin can broadcast instantly; every logged-in device receives the notification in realtime (local banner + notification-center row + unread badge increment).
- Migration `018` must be applied to the Supabase project (SQL editor or Management API) for the send path and connected-devices list to work; until then the UI degrades gracefully with clear error messages.
- `flutter analyze` 0 errors; suite grew 531 → 535 (new `buildBroadcastParams` tests); debug APK rebuilt, installed, and the rewritten admin page verified on DNP NX9 (renders send form, audience/type selectors, retry, no crashes).

---

## ADR-038: Device-Status Counters + Notification Management (admin broadcast UX + delete)

**Date:** Sprint 57
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
After ADR-037 verified the broadcast path, the admin dashboard still listed individual masked tokens, had no online/offline visibility, no "how many devices received" metric, and left the Firebase copy card under the send button. The notification center also lacked deletion (only mark-all-read) even though `deleteNotification(id)`/`clearAll()` already existed in the data layer.

### Decision
1. **Migration `019_push_broadcast_device_count.sql`:** replace `admin_broadcast_notification` so it returns the **device count** — the number of `notification_tokens` rows belonging to the matched recipients — instead of the recipient-user count. It still inserts one `notifications` row per matching user (realtime delivery unchanged).
2. **Admin page: counters + received button + remove Firebase card.** Connected devices render as compact stat tiles — `متصل` (online) / `غير متصل` (offline) counters plus an `الأجهزة المستلمة` (devices received) button showing the last broadcast's device count (updates after every send). The Firebase Console copy card (and its now-dead `_copyPayload`/`_openConsoleGuide` code) is removed entirely; the broadcast RPC is the single send path. Online/offline classification extracted to a testable `computeDeviceStats(tokens, now)` (15-minute window).
3. **Notification center: deletion.** `حذف الجميع` (delete-all) action with a confirmation dialog calls `clearAll()`; every notification card gains a per-item delete button calling `deleteNotification(id)`. Both invalidate `notificationsProvider`/`unreadCountProvider`.
4. **Token heartbeat.** `PushNotificationService` re-upserts the FCM token every 5 minutes while the app is alive so `updated_at` becomes a real liveness signal — making the online/offline counters meaningful (a device with the app closed drops to offline after 15 min).

### Rationale
- A "devices received" number is only honest if it counts devices; counting `notification_tokens` of the recipients is the closest true metric available without per-device delivery receipts, and matches the realtime delivery model (each token receives the row).
- Hiding the Firebase card removes a dead/manual path now that the RPC send works; keeping it would only confuse admins.
- The heartbeat turns static `updated_at` timestamps into a live presence signal so the counters reflect reality rather than "app launched sometime this week".

### Consequences
- The admin page shows compact, actionable numbers (online / offline / last-broadcast received devices) with no token-list noise and no Firebase copy path.
- RPC return semantics changed from recipient-user count to device count; the snackbar and received button now say "جهاز" (device). `flutter analyze` 0 errors; suite grew 535 → 542 (4 `computeDeviceStats` tests + 3 notification-center widget tests).
- Verified live on DNP NX9: stats card shows `1 متصل / 0 غير متصل`; a test broadcast returned 1 device and the received button updated to 1; per-item delete removed a row (DB confirmed) and delete-all emptied the table (0 rows); empty state renders. Migration `019` applied to `bttnlkmwhorjamzemwda`.

---

## ADR-039: Account Verification / Approval Workflow (Providers + Delivery)

**Date:** Sprint 60
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context
Any sign-up could immediately use the platform regardless of who they claimed to be. Drivers/merchants previously existed only through dedicated onboarding flows (driver platform, merchant registration), but the generic `users.role` column still only allowed `customer/merchant/driver/admin`, and there was no way for an admin to review and approve an identity before granting platform access. The product required a simple two-tier gate: **customers are approved instantly; providers and delivery users must be verified by an admin** using uploaded identity documents.

### Decision
1. **Two new domain enums** — `UserType` (`customer`/`provider`/`delivery`, `requiresVerification`) and `VerificationStatus` (`pending`/`approved`/`rejected`) — living in a new `lib/domain/enums/`, so the concept is shared by auth, admin, and future modules without feature-to-feature imports.
2. **Persist on the `users` row** — new columns `user_type`, `verification_status`, `id_card_url`, `profile_photo_url`; the existing `role` CHECK is extended to include `provider`, `delivery`, and `owner`. A provider/delivery sign-up writes `verification_status = 'pending'`; customers are `'approved'`. This keeps verification at the profile row rather than a parallel table, so `UserModel.fromSupabase` needs no join.
3. **Gate at the auth state, not the screen** — `AuthStateNotifier._resolveAuthenticated` maps a non-approved provider/delivery user to `AuthState.pendingVerification`; the router redirect forces `/pending-verification` for every location except auth routes. The gate cannot be bypassed by navigation.
4. **Document upload at registration** — the register flow gains an account-type step; providers/delivery must attach an ID card + profile photo (gallery/camera via `image_picker`), uploaded to the public `profiles` bucket under `id_cards/` and `profile_photos/` before the profile upsert.
5. **Admin review page** — `AdminVerificationsPage` at `/admin/verifications` (dashboard quick action) lists pending requests with name/email/phone/user type and zoomable document previews, with approve/reject actions (confirm dialog, per-row processing state) backed by `getVerificationRequests` / `approveVerification` / `rejectVerification`.
6. **Migration `020_user_verification.sql`** — adds the four columns (+ CHECK constraints, defaults `customer`/`approved` so existing rows never appear in the pending list), extends `users_role_check`, grants admins SELECT/UPDATE on `users` via `is_admin()`, and guarantees the public `profiles` bucket + authenticated upload policy.

### Rationale
- Gating at the auth-state level makes the rule apply everywhere (splash, deep links, guest flows) instead of per-screen checks.
- Storing `user_type`/`verification_status` on the existing `users` row (with safe defaults) avoids a migration of historical rows and keeps the domain model flat.
- Admin RLS via the existing `is_admin()` helper follows the ADR-026 role-based policy pattern (no `USING(true)`).
- The migration is idempotent and guarded (`ADD COLUMN IF NOT EXISTS`, drop/recreate constraint checks) because the live schema has drifted from the migration files.

### Consequences
- Customers are unaffected: their rows default to `customer`/`approved` and they never see the verification gate.
- Providers/delivery sign-ups are blocked from the main app until an admin approves them; rejection keeps them on the pending page until they sign out.
- `flutter analyze` 0 errors; suite grew 542 → **556/556** (new enum/model/auth-provider/usecase tests); debug APK not yet rebuilt this session.
- **External blockers:** `020_user_verification.sql` must be applied to `bttnlkmwhorjamzemwda` (user PAT / SQL Editor); until then provider/delivery upserts fail on missing columns. On-device E2E (register → pending → admin approve → home) and the Sprint 60 commit/push remain.

---

## ADR-040: Signup Trigger Sources Identity from Metadata + Email-Confirmation Deep-Link Config

**Date:** Sprint 60 (live-DB session)
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context

With email confirmation already enabled live (`mailer_autoconfirm: false`), a sign-up that selects `provider` or `delivery` would **not** receive the client-side profile upsert: GoTrue strips the session until the email is confirmed, so `AuthRepositoryImpl._persistSignUpProfile` never runs and the trigger `handle_new_user()` ran instead — but it hardcoded `role='customer'` and did `ON CONFLICT (id) DO NOTHING`. Result: provider/delivery sign-ups silently collapsed into customer rows, defeating the ADR-039 verification gate. Additionally, the confirmation email pointed at `http://localhost:3000`, so even when the app did complete the flow the link never returned to the phone.

### Decision

1. **Migration `021_signup_type_flow.sql`** rewrites `handle_new_user()` to read `user_type`, `verification_status`, and `full_name` from `NEW.raw_user_meta_data` (defaults: customer/approved; provider or delivery → pending). It also backfills orphaned `auth.users` rows that never got a `public.users` row, reconciles previously-broken provider/delivery rows, and preserves the owner account. The DB trigger — not the client — is now authoritative for identity at signup.
2. **Auth config (Management API `PATCH .../config/auth`):** `site_url` and `uri_allow_list` set to `io.delwaqty://login-callback` (the Android deep link already declared in the manifest). Confirmation links therefore open the app; supabase_flutter's default PKCE flow exchanges the code and completes the session.
3. **No custom SMTP:** the Supabase built-in mailer remains (functional, rate-limited). Free-tier `rate_limit_email_sent=2`/hour was observed (429s beyond that).

### Rationale

- The trigger is the only code guaranteed to run on every signup regardless of email-confirmation state, so identity derivation must live there, not in a client callback.
- Reading role/user_type/verification_status from `raw_user_meta_data` is the GoTrue-idiomatic way to pass signup-form data into the database without a second RPC.
- Setting `site_url` to the deep link makes the entire confirm → app-open → session → router gate chain automatic; no custom deep-link handling code needed (PKCE handled by the SDK).
- `uri_allow_list` is a **comma-separated string** in the Management API (an array body returns HTTP 400) — recorded here so future redirect/allow-list edits don't repeat the dead-end.

### Consequences

- Migrations 020 + 021 are **applied live**; verified rows: `cyfyfuf@gmail.com` → role/provider, user_type/provider, verification_status/pending; customers stay customer/approved; owner preserved with role='owner'.
- Registration now completes end-to-end at the DB level: signup → email confirm link opens the app → session → auth gate routes provider/delivery to `/pending-verification`.
- The rate limit constrains bulk testing; 2 signups/hour. A custom SMTP provider is the eventual production fix.
- Remaining manual verification: tap a real confirmation link on DNP NX9 and walk register → pending → admin approve → home.

---

## ADR-041: Fingerprint Login, Saved Accounts, and Social-Login Removal (Login UX)

**Date:** Session 21q (Sprint 60 follow-up)
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context

The login screen carried three legacy problems. First, the "fingerprint" (البصمة) button never worked on-device: it stored email/password in **plaintext SharedPreferences** under `biometricEnabled/biometricEmail/biometricPassword`, required a one-off password re-entry bypass, and the `AndroidManifest.xml` was **missing `USE_BIOMETRIC`/`USE_FINGERPRINT`** so `LocalAuthentication` could never succeed. Second, the Google/Apple/Facebook buttons were non-functional decoration (no OAuth providers configured). Third, the "save account" (حفظ) checkbox did nothing persistent, and there was no way to see or quickly re-sign-in with previously saved accounts.

### Decision

1. **New secure store — `SavedAccountsStore`** (`lib/data/datasources/local/saved_accounts_store.dart`): the account list lives in SharedPreferences (`StorageKeys.savedAccounts`) as a JSON list of `SavedAccount` (email/displayName/hasBiometric), while the biometric **password is written only to Keystore/Keychain via `flutter_secure_storage`** under `biometric_password_<email>`. Emails are normalized (`trim().toLowerCase()`) at the store boundary; the old plaintext `biometricPassword` key is deleted from `StorageKeys`.
2. **`SavedAccount` Freezed model** (`lib/features/auth/domain/saved_account.dart`) with a `key` getter (normalized email) used for identity across the store and the login page.
3. **Login page rewrite** (`login_page.dart`): social buttons removed; "حفظ الحساب" (save account) + "تفعيل البصمة" (enable fingerprint) checkboxes gate post-login persistence (`_handlePostLoginSave` runs off the `authenticated` listener); a horizontal **Saved Accounts** section lists chips (avatar initial, fingerprint badge when enabled, remove × with confirm dialog) — tapping a chip fills the email field, selects the text, and focuses the password field; the fingerprint button authenticates via `LocalAuthentication` (`biometricOnly` + `stickyAuth`) then reads the secure password and calls `signIn`. Fingerprint UI appears only when `hasBiometric` for the filled email **and** `canCheckBiometrics`.
4. **`flutter_secure_storage` pinned to `^11.0.0`** and **`compileSdk` bumped 36 → 37**: v11 is the only line whose Windows package uses `win32 ^6` (matching `geolocator ^14`); v11's AAR requires Android API 37. Platform package registrants regenerated for linux/macos/windows.
5. **Social methods removed from `AuthStateNotifier`** (`signInWithGoogle/Apple/Facebook` getters + methods). `signOut` no longer wipes any biometric/saved-account storage — accounts survive logout by design.

### Rationale

- Passwords must never touch SharedPreferences (Constitution §10 / secure-storage discipline); the secure storage holds only the password, the prefs list holds only metadata.
- Keystore-backed biometric auth is the correct primitive; the previous flow conflated "remember the password" with "authenticate by fingerprint" and had no biometric-only enforcement.
- Removing dead social buttons eliminates misleading UI until real OAuth providers exist; phone/password + guest remain the supported entries.
- Accounts surviving sign-out is what makes the saved-account section useful (fast re-login), so `signOut` intentionally no longer clears storage.

### Consequences

- Existing plaintext `biometric_*` prefs from older builds are simply never read again; the secure store starts empty and repopulates via the save-account flow.
- `flutter analyze` 0 errors/warnings from touched files; suite grew to **567/567** (new `SavedAccount` + `SavedAccountsStore` tests; store tests exposed and fixed a real unmodifiable-list bug and email-normalization bug).
- Debug APK built (`compileSdk 37`) + installed on DNP NX9; app launches clean (no FATAL, no ConfigValidator crash).
- Leftover pre-existing lints in untouched modules are unchanged and out of scope for this session.

---


## ADR-042: Treat Missing Location Accuracy (0.0) as Unknown, Never "0 m"

**Date:** Session 21r (Sprint 61)
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context

The app claimed the user's location was accurate to **0 meters** when it was actually off by hundreds of meters. Root cause: `geolocator` (Android) reports `accuracy = 0.0` when the platform provides **no accuracy estimate** (`hasAccuracy == false`, typical of network/fused cell-tower fixes). The location engine's gates treated `0` as a perfect sub-metre fix:

- `_isFreshAndPrecise` accepted `accuracy >= 0 && accuracy <= 1` ? a fresh-but-unmeasured fix short-circuited the whole acquisition as "= 1 m".
- `_isUsableLastKnown` accepted `accuracy >= 0 && accuracy <= 500` ? quick mode used unmeasured fixes as usable.
- `refreshDeepLocked()`'s early-return treated `accuracy <= precisionTargetMeters` as success ? returned "0 m" instantly.
- `UserLocation.accuracyMeters` surfaced the raw `0.0`, so callers never warned (their guard was `accuracy > 1 m`).

`dumpsys location` on DNP NX9 confirmed the real-world case: the last fused/network fix was `hAcc=100.0` (�2 days old) while GNSS was ~8 m; an unmeasured fix with no accuracy would have been reported as "0 m".

### Decision

1. **`accuracy <= 0` is invalid everywhere.** `_isFreshAndPrecise` requires `accuracy > 0 && accuracy <= 1`; `_isUsableLastKnown` requires `accuracy > 0 && accuracy <= 500` (GNSS-verified last-known still passes on satellite count alone).
2. **`UserLocation.accuracyMeters` becomes `null` when unknown** (`position.accuracy > 0 ? position.accuracy : null`), so no caller can display or rely on a fabricated "0 m".
3. **`refreshDeepLocked()` best-fix tracking now prefers known accuracy**: an unknown-accuracy fix is kept only as a last-resort fallback and can never displace a known-accuracy fix, and never triggers the sub-metre early return.
4. **`_acquirePreciseFix()`** similarly only replaces `best` with a strictly-known-accuracy sample and only early-completes on a live-GNSS fix with `accuracy > 0 && <= targetMeters`.
5. **Google Geocoding now sends `X-Android-Package: com.delwaqty.app` and `X-Android-Cert: 5337185A52F0B615A3388ECC03B6576D61F34EEF`** (debug SHA-1, colons removed) � the standard mechanism that makes an Android-app-restricted Maps key authorize raw HTTP Geocoding calls (the Maps SDK does this automatically; the raw `http.get` did not, which is why geocoding returned `REQUEST_DENIED`).

### Rationale

- geolocator documents `accuracy == 0` as "accuracy not available"; interpreting it as "perfect" inverted a genuinely dangerous case (false confidence) into the UI's best case.
- Nullable `accuracyMeters` moves the ambiguity to the type system: consumers must decide how to handle "unknown" instead of trusting a fake `0`.
- Best-fix tracking should always prefer a measured fix; an unmeasured sample is only a coordinates fallback.
- The header pair is the only way a console-restricted Android key can authorize direct REST geocoding; without it the key is unusable from raw HTTP regardless of enablement.

### Consequences

- Unknown-accuracy fixes now flow as `accuracyMeters == null`; delivery/ride flows fill best-effort coordinates but no longer claim sub-metre precision and never show "0 m".
- Quick mode refuses fresh unmeasured network last-knowns and falls through to a stream acquisition; deep lock keeps hunting for a measured/GNSS fix.
- Geocoding from the app is now eligible to work with the existing key **if** the Geocoding API is enabled in Google Cloud Console (still an external action the user must take) � until then the Photon/Nominatim fallback chain remains.
- 3 new unit tests pin the regression; suite grew to **570/570**; `flutter analyze` adds **no new issues**; debug APK built + installed on DNP NX9.

---

## ADR-043: Locale-Aware Precise Reverse Geocoding + Fingerprint Auto-Login

**Date:** Session 21s (Sprint 61)
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context

Two user-reported bugs remained after ADR-042. (1) The home-location header showed a **generic** address that never changed when the UI language changed: `_cleanArabicAddress` stripped **all digits** (destroying street numbers), the Google/Photon/Nominatim calls were issued without a language, and the geocode cache was language-agnostic, so switching Arabic → English kept rendering the Arabic string. (2) The fingerprint button on login required the user to first tap the saved-account chip: `_authenticateWithBiometric` demanded a non-empty email and otherwise showed "enter your email first". The product expectation was that tapping the fingerprint button alone auto-detects the account that has biometric enabled (from the store) and signs in with its stored password.

### Decision

1. **Locale-aware reverse geocoding** (`location_provider.dart`): a new `_appLanguage()` reads `localeProvider`. Google Geocoding sends `language=$language`, Photon `lang=$language`, Nominatim `accept-language=$language`. Street precision preserved: Google now parses `street_number` + `route` and builds a `"number route"` street part; `_cleanAddress(input, language)` no longer strips digits and only normalizes separators (`،` for `ar`, `,` for `en`).
2. **Language-scoped geocode cache**: the cache key becomes `lat,lng@language` (store `location_geocode_cache_v2`, TTL 24 h, cap 200) so each language resolves independently and instantly.
3. **Reactive re-geocode on language switch**: `UserLocationNotifier.build()` now `ref.watch(localeProvider)`, so toggling the app language re-runs position + reverse geocoding in the new language immediately (previously the provider state was frozen forever).
4. **Fingerprint auto-login** (`SavedAccountsStore` + `login_page.dart`): new `biometricAccount()` returns the first saved account with `hasBiometric == true`. `_authenticateWithBiometric` now, when no email is selected, loads `biometricAccount()`; if found it authenticates and signs in with that account's Keystore password automatically. Falls back to the enable-dialog only when the account has no stored password. Two new l10n keys (`noBiometricAccountSaved`, `biometricNotEnrolled`) in en + ar.

### Rationale

- Passing `language`/`accept-language`/`lang` is the provider-documented way to localize results; stripping digits was the direct cause of the "generic" street addresses the user complained about.
- `ref.watch(localeProvider)` makes the provider state a function of the locale, the correct Riverpod reactive pattern — a language change must be observable by the location engine, not require a manual refresh.
- Auto-detecting the biometric account from the store matches the user's stated expectation ("the app should understand the saved biometric account and its password and log in automatically") and removes a pointless manual step.
- Reading `ref.read(localeProvider)` inside `_appLanguage()` with an `ar` fallback keeps the engine resilient before the locale provider is ready.

### Consequences

- Home header on DNP NX9 (Arabic) now shows `Zafarana offices، عتاقة، محافظة السويس، مصر` (governorate added). At that in-building coordinate Google returns premise-only components, so no street number exists from any provider — a data limitation, not a code bug.
- The English regression was reproduced (Arabic string kept after switching to English) and fixed by the locale watch; the English geocode resolves independently via the `@en` cache key.
- Fingerprint button now works standalone: no saved biometric account → informative `noBiometricAccountSaved` snackbar; account found → auto sign-in; device lacking enrolled prints → `biometricNotEnrolled` message.
- `flutter analyze` 0 errors / 0 warnings from touched files; suite grew to **577/577** (3 new `biometricAccount()` store tests); debug APK rebuilt + installed on DNP NX9.
- **On-device blocker:** DNP NX9's biometric sensor reports state 4 (bad) despite 4 enrolled fingerprints, so a real scan always throws `PlatformException`; the auto-detection + password retrieval path is unit-tested, but the success gesture requires a healthy device.

---

## ADR-044: Database-Backed Biometric Login + Hierarchical Village Geocoding

**Date:** Session 22 (Sprint 61)
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context

Two gaps surfaced after ADR-043. (1) The Arabic home-location chip flattened Google/Nominatim components into a fixed column set, so a village/tourist area like Zafarana rendered without its Markaz (dministrative_area_level_2) and village locality � the user wanted the administrative **hierarchy chain** (e.g. `???? ?????? - ???? ?????????`) so the location reads naturally in Arabic. (2) The fingerprint auto-login from ADR-043 was still an "auto-detect" heuristic over SavedAccountsStore; there was no durable, per-user, database-backed biometric flag, no enrollment prompt, and no startup auto-login. The product expectation was a **real biometric system**: users.is_biometric_enabled, enable-after-password-login prompt, per-user encrypted credentials, and biometric auto-login at app start.

### Decision

1. **Hierarchy-chain geocoding** (location_provider.dart): extract static @visibleForTesting composeGoogleAddress (chain dministrative_area_level_2 ? level_3 ? sublocality_level_3 ? level_2 ? level_1 ? neighborhood, joined by ' - '; Arabic separator '? ', English ', '; dedup across and within the chain) and composeNominatimAddress (county, municipality, city, town, village, hamlet, city_district, suburb, quarter, neighbourhood, residential; named-place keys exempt when they contain digits; region = state/region; country deduped).
2. **DB-backed biometric flag**: migration  22_user_biometric_enabled.sql adds is_biometric_enabled BOOLEAN NOT NULL DEFAULT false to users; User/UserModel carry @Default(false) bool isBiometricEnabled mapped in romSupabase (missing ? false) and exported by 	oSupabaseMap/	oUpdateMap.
3. **Enable path**: AuthRepository.updateBiometricEnabled(userId, enabled) ? updateProfile ? updateBiometricEnabledUseCase ? AuthStateNotifier.updateBiometricEnabled (re-fetches the user, re-applies _resolveAuthenticated).
4. **Per-user credential store**: new BiometricAuthStore keeps BiometricCredentials{email, password} JSON in lutter_secure_storage under uth_biometric_<userId> plus an uth_biometric_active_user marker; corrupt payloads decode to null. The DB flag is informational only � credentials live exclusively in secure storage.
5. **Enrollment prompt** (login_page.dart): after a successful password login, if biometrics are available and the user has not enabled them, an AlertDialog offers enrollment (Arabic: `?? ???? ?? ????? ?????? ??????? ????? ????????`); confirm runs a local biometric prompt then persists credentials + sets the DB flag; suppressed after a biometric auto-login.
6. **Startup auto-login** (splash_page.dart): when the session is not authenticated, _tryBiometricAutoLogin() reads the active credentials, prompts for the local biometric, then signs in with email + stored password. AuthError/AuthUnauthenticated/general failures clear the active marker; PlatformException falls through to the login page.

### Rationale

- A single chained component string (rather than fixed columns) lets the same formatter render a village's full administrative lineage and collapse duplicates � closer to how Egyptians describe locations.
- A real DB column turns "biometric enabled" into user state visible server-side (and to future multi-device sync), while secure storage keeps the secret material off the DB by design.
- Persisting the password in the Keystore-backed secure storage is the only way to auto-sign-in without a second password entry; the DB flag is intentionally not the credential holder.
- Gating auto-login behind an explicit enrollment dialog matches the earlier "enable via checkbox on login" UX but is now durable and reversible per user.

### Consequences

- Arabic village addresses render with the Markaz?village chain when Google provides the components; the device test coordinate (building interior) still yields premise-only components, so the chip text there is unchanged � hierarchy output appears at open-sky village coordinates (verified by unit tests).
- Login now persists credentials only when the user opts in; the active-user marker lets startup auto-login know exactly whose credentials to use, without the ADR-043 "first account with hasBiometric" heuristic.
- Full suite grew to **599/599** (+8 store tests, +11 geocoding tests, +3 model delta); lutter analyze 0 errors / 0 warnings from touched files.
- **On-device blockers**: DNP NX9's sensor reports state 4 (bad), so the real scan path throws PlatformException (pre-scan logic unit-tested); and the release APK cannot be signed until the user provides KEYSTORE_PASSWORD (debug signing used for the tested install).

---

## ADR-045: Unify All Fingerprint Entry Points on the DB-Backed Biometric Store

**Date:** Session 23 (Sprint 61 fix)
**Status:** Accepted
**Deciders:** Lead Software Architect

### Context

ADR-044 introduced the DB-backed biometric system: `users.is_biometric_enabled`, a per-user `BiometricAuthStore` (`auth_biometric_<userId>` + `auth_biometric_active_user`), the enable-after-password-login dialog, and startup auto-login. But the migration was incomplete: the login-page fingerprint button, the saved-account chip badges, and the Settings fingerprint toggle still read the **legacy** ADR-041/043 path (`SavedAccountsStore.biometric_password_<email>` + `SavedAccount.hasBiometric`). A user who enrolled via the new dialog (which wrote only to `BiometricAuthStore`) then tapped the login fingerprint button and got `noBiometricAccountSaved` — the button never auto-logged-in. The device fingerprint sensor is healthy again (`Fps state: 0`, 4 prints, successful auth events), so the split was now the sole cause of the reported bug.

### Decision

1. **Single source of truth = `BiometricAuthStore` + `users.is_biometric_enabled`.** Every fingerprint entry point reads/writes these two; the legacy `biometric_password_<email>` secure-storage keys and `SavedAccount.hasBiometric` are removed.
2. **Login-page button** (`login_page.dart`): `_authenticateWithBiometric` reads `biometricAuthStoreProvider.activeCredentials()` (the single active user), prompts with the real sensor, fills the email/password fields, then calls `signIn`. The email-keyed password lookup and the `_promptEnableFingerprint` password re-entry dialog are deleted.
3. **Legacy UI removed**: the `_enableBiometric` checkbox and the per-chip fingerprint badge on `_SavedAccountChip` are gone — enrollment happens only through the post-login dialog, and the new store holds exactly one active user (no per-account badges). `_BiometricButton` always shows the `fingerprintLogin` label.
4. **Settings toggle** (`fingerprint_login_page.dart`): `_loadStatus` reads `user.isBiometricEnabled` (DB, the source of truth) instead of scanning accounts; toggle-on persists credentials via `saveCredentials(userId, ...)` then `updateBiometricEnabled(true)`; toggle-off runs `clearActive()` + `updateBiometricEnabled(false)`.
5. **Model + store cleanup**: `SavedAccount` loses `hasBiometric` (Freezed/json regenerated); `SavedAccountsStore` returns to a pure SharedPreferences account-prefill store (no `FlutterSecureStorage`, no `setBiometric`/`biometricPassword`/`biometricAccount`).

### Rationale

- Two parallel biometric systems holding different data is exactly why enrollment succeeded while the login button reported "no account". A single store removes the divergence class entirely.
- The new store is already keyed per-user with an active-user marker, so `activeCredentials()` answers "whose biometric session is this?" unambiguously — strictly better than the ADR-043 "first account with hasBiometric" heuristic.
- The DB flag is the authoritative "enabled" state for UI (survives reinstall, visible server-side); secure storage holds only the secret material.
- Removing the checkbox/chip badge simplifies the login surface to one enrollment prompt + one fingerprint button, matching the single-active-user model.

### Consequences

- The login-page fingerprint button now signs in the active biometric user automatically; the settings toggle and startup auto-login all read/write the same store and flag.
- Users enrolled under the legacy pre-ADR-044 path must re-enroll once via the post-login dialog (their old `biometric_password_<email>` entries are no longer read) — acceptable for the pre-release stage, no migration code added.
- `flutter analyze` 0 errors / 0 warnings (514 pre-existing info lints, baseline unchanged); full suite **594/594** (saved-account store/model tests trimmed to the non-biometric scope, settings page tests rewritten with mocked repositories); debug-verified on DNP NX9.
- Docs updated: `SESSION_STATUS.md`, this log, and handoff `22_SPRINT_61_FINGERPRINT_UNIFICATION.md`.
