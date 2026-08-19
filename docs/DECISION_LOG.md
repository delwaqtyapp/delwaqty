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
| 067 | Escalation engine — ledger + RPCs + strict-upward routing | Accepted | `048_escalation_engine.sql`, region-aware admin tiering, owner queue |

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

---

## ADR-046: Phone always-on OpenCode infra — Termux:Boot install, APK default, Shizuku probe

**Date:** Session 33 (2026-08-13)
**Status:** Accepted
**Deciders:** Lead Architect (remote, via OpenCode on device)

### Context
Three phone-side infrastructure failures blocked a reboot-proof workflow:
1. OpenCode never auto-started after reboot — `com.termux.boot` was never installed,
   so `~/.termux/boot/opencode-boot.sh` was never executed; the user re-ran the manual
   `proot-distro login ubuntu … opencode serve` command after every boot.
2. Tapping an `.apk` opened Termux instead of the Android Package Installer — a stored
   Preferred Activity with `mAlways=true` bound `application/vnd.android.package-archive`
   to `com.termux/.app.api.file.FileViewReceiverActivity`, so Android never showed a chooser.
3. `shizuku-init.sh` pointed `/usr/local/bin/rish` at the **host** Termux where it does not
   exist (rish lives inside the Ubuntu proot), so its boot probe always failed.

### Decision
- Install **Termux:Boot v0.8.1** and **Termux:API v0.53.0** via `pm install` (shell uid 2000
  through Shizuku `rish`), then launch `com.termux.boot/.BootActivity` once so Android marks
  it `stopped=false` (a freshly installed, never-launched app never receives `BOOT_COMPLETED`).
- Remove the stale default: `cmd package clear-package-preferred-activities com.termux`.
- Rewrite `shizuku-init.sh` to probe via `proot-distro login ubuntu -- /usr/local/bin/rish -c id`,
  degrade to a WARN when Shizuku is down, and never block the OpenCode boot chain.
- Harden `opencode-boot.sh` (explicit `TERMUX_HOME`, exec checks) and `opencode-ctl`
  (HOME fallback); keep canonical copies in `tool/opencode/`.

### Rationale
- Android deliberately never delivers `BOOT_COMPLETED` to apps in the `stopped` state; the
  first Activity launch is the documented "activation" step. All other layers (tmux + `setsid`
  + `wake-lock`) were already correct — only Termux:Boot was missing.
- The `mAlways=true` preference overrode the chooser entirely; clearing preferred activities for
  `com.termux` restores normal resolution (real installers win for real `content://` URIs).
- Termux:Boot executes boot scripts on the **host**, so any path to rish must be reachable
  from the host — entering the proot is the only correct route.

### Consequences
- After the next reboot the server should come up via Termux:Boot → tmux → proot → opencode on
  `127.0.0.1:4096` with no manual command; the user must still run the one-time battery
  **Unrestricted** whitelist for Termux on Honor.
- APK taps now resolve to the real installer/chooser; Termux still declares a `application/*`
  wildcard so it *can* appear in a chooser for scheme-less VIEW intents, but it no longer
  auto-opens for APK installs.
- Shizuku remains optional for the server: its probe is best-effort and non-blocking.
- Requires one real reboot to fully prove the Termux:Boot chain (pending user).

---

## ADR-047: Password change invalidates stored biometric credentials

**Date:** Session 40 (2026-08-14)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
Biometric login stores encrypted email+password in `flutter_secure_storage` (keyed per user)
so the user can sign in with a fingerprint without re-typing the password. The settings page
allowed changing the account password without touching that store. After a password change the
device kept a stale encrypted secret: biometric login would fail (wrong password) while the old
credential lingered on-device for no reason. The DB flag `users.is_biometric_enabled` also
stayed `true`, promising a capability that no longer worked.

### Decision
After a successful `auth.updateUser(password:)` in `ChangePasswordPage`, call
`_invalidateBiometricLogin()`:
- `BiometricAuthStore.clearForUser(user.id)` — wipe the encrypted credential immediately,
  not just on a failed auth attempt.
- `updateBiometricEnabled(enabled: false)` — reset `users.is_biometric_enabled` in the DB.

Effect: the user must re-enroll (fingerprint + password confirmation) after changing the
password. No stale secret survives and the DB flag always reflects reality.

### Rationale
- Security: never leave an obsolete password stored on-device; invalidate on the only
  password-mutation surface the app exposes.
- Consistency: the on-device flag and the DB flag move together, matching the already-handled
  toggle flow (disable = clearForUser + DB false).
- Least surprise: login with a wrong stored password and silently clearing on splash is replaced
  by a deterministic ownership of the lifecycle at the point the secret changes.

### Consequences
- Users who change their password must enable biometric login again (documented in the page's
  success snackbar flow; enrollment is a one-time dialog).
- No new tables or migrations; relies on existing `BiometricAuthStore` and
  `updateBiometricEnabledUseCase`.
- Covered by existing biometric store + fingerprint page tests; full gate passes (594/594).

## ADR-048: Centralized event-driven biometric credential invalidation

**Date:** Session 42 (2026-08-15)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
Biometric login stores encrypted email+password per user in `flutter_secure_storage`. Two gaps
remained after ADR-047:
1. A stale credential (password changed elsewhere, revoked account, deleted account) was only
   cleared by the splash's `clearForUser` in one path; the login-page biometric button kept failing
   and kept retrying with the stale secret. Invalidation was scattered and inconsistent.
2. Account deletion did not remove local biometric credentials, so a deleted account could still
   power a biometric auto-login attempt.
3. Local flag refresh: the login-page `_biometricAvailable` was computed once in `initState` and
   could be stale after an auth-state change.

### Decision
1. **Centralized method:** `AuthStateNotifier.invalidateBiometricCredentials(userId)` is the single
   invalidation entry point. It clears the encrypted credential + active-user key via
   `BiometricAuthStore.clearForUser`, and — only when still authenticated as that user — resets
   `users.is_biometric_enabled = false` through the existing `updateBiometricEnabled` flow.
   All callers route through it: login-page stale failure, splash auto-login failure,
   password change (ADR-047), fingerprint settings toggle, and account deletion.
2. **Event-driven, not timer-based:** invalidation fires only when `signInWithEmail` with the
   stored credentials is rejected by Supabase (`AuthState.error` / `AuthUnauthenticated` right
   after a biometric unlock). There is no periodic validation sweep.
3. **Account deletion cleanup:** `AuthStateNotifier.deleteAccount()` captures the current user id
   before clearing state and calls `clearForUser` after a successful deletion.
4. **Logout preserves enrollment by design:** `signOut()` never touches biometric credentials —
   the enrollment is meant to survive logout so the next login can use biometrics. Verified by test.
5. **Server-flag best-effort in the unauthenticated stale case:** after a failed biometric sign-in
   there is no session, so `is_biometric_enabled` cannot be reset remotely; local credential
   deletion is what actually gates biometric login, and the flag is reset on the next authenticated
   invalidation path (e.g. password change). This limitation is intentional and documented.

### Rationale
- Single ownership: every invalidation path shares identical semantics (local wipe, active-user
  clear, flag reset, UI refresh) instead of duplicating store calls.
- Security: a stale or orphaned secret never survives a rejection, and never survives account
  deletion.
- Least surprise: users are told (`biometricStaleCredentials`, EN+AR) that the saved login was
  reset and to sign in manually, and re-enrollment is offered again afterward.

### Consequences
- All invalidation flows now delegate to one method; future flows must do the same.
- Users with stale credentials re-enter their password once and can re-enroll; no data loss beyond
  the intentionally-invalidated secret.
- No schema/migration changes; relies on existing `BiometricAuthStore` +
  `updateBiometricEnabledUseCase`.
- Covered by 9 new tests; full gate passes (603/603, analyzer 0 errors / 543 baseline unchanged).

## ADR-049: Canonical admin identity is the 016 model; admin_users is legacy metadata

**Date:** Session 43 (2026-08-15)
**Status:** Accepted
**Deciders:** Lead Architect + user approval

### Context
Two admin authorities existed: (a) `users.role IN ('admin','owner')` via `public.is_admin()` (016) —
already used by chat/complaints/notifications RLS, the router, and providers; and (b) `admin_users`
(002), whose `id` is a separate UUID not linked to `users.id`, with no seed rows and RLS that compares
`admin_users.id = auth.uid()` (structurally impossible), making it inaccessible to real users and to the
anon-key admin_web.

### Decision
Adopt the 016 model as the SINGLE canonical authorization authority. Preserve `admin_users` as
dormant/legacy metadata (AGENTS.md §12.1) — do not delete. In Phase 2.2, *link* legacy `admin_users`
rows to canonical identities via an additive `user_id` FK and build the admin hierarchy on the canonical
identity model. Never create a third admin system.

### Rationale
Zero rewiring (all consumers already use the 016 model); eliminates the duplicate authority; the
dead-in-practice `admin_users` adds no authorization value but is safe to keep as metadata.

### Consequences
All sensitive authorization stays server-side via `public.is_admin()` (SECURITY DEFINER, 016 pattern).
New region write policies reuse `public.is_admin()`.

## ADR-050: Canonical Egypt region model — recursive regions + per-user preference state

**Date:** Session 43 (2026-08-15)
**Status:** Accepted
**Deciders:** Lead Architect + user approval

### Context
No region tables existed; geocoding produced only free-string city/district fields. Phase 2 requires a
canonical region hierarchy (Egypt → governorate → city/district → area) with stable IDs, RLS, and
per-user state distinguishing detected/manual/verified.

### Decision
New `regions` self-referencing table (`parent_region_id`, `code` stable/unique using ISO 3166-2:EG,
`type` country/governorate/city/district/area, `name_ar`/`name_en`, `is_active`, `metadata`, timestamps)
plus `user_region_preferences` (user_id PK, region_id, `source` detected/manual/verified). Seed: country
Egypt + all 27 governorates from the authoritative ISO 3166-2:EG/official list. City/district/area data
is NOT fabricated and is deferred to a verified source. RLS: regions SELECT public / write admin-only;
preferences owner rw / admin select. Detection pipeline never creates duplicate regions; state
preservation policy prevents silent overwrite of verified/manual.

### Rationale
Recursive parent keeps all depth lookups generic; separate preference table cleanly separates shared
catalog from per-user state; stable deterministic UUIDs + ISO codes give immutable references for
routing/assignment.

### Consequences
New migration 030. Flutter gains a `regions` feature module (entity, resolver, repository, data source,
providers, selection page). Admin mutation of regions is RLS-restricted to `public.is_admin()`.

## ADR-051: Extend chat_rooms/chat_messages — no parallel conversation system

**Date:** Session 43 (2026-08-15)
**Status:** Accepted
**Deciders:** Lead Architect + user approval

### Context
`chat_rooms` already models support conversations (`room_type='support'`, `participant_ids`), is RLS
deterministic (016), and has a full Flutter stack. Phase 2 needs priority, region routing, assignment,
status, escalation, audit reference.

### Decision
Keep `chat_rooms`/`chat_messages` as the single conversation source of truth and extend `chat_rooms`
with additive columns in 2.3: `priority` (normal/high/urgent/emergency), `region_id` FK, `assigned_admin_id`,
`status`, escalation fields, `closed_at`, `audit_reference`. No `support_conversations` table.

### Rationale
Additive extension preserves identity/RLS/UX and avoids fragmenting conversations across two stores.

### Consequences
2.3 adds an ALTER TABLE migration + scoped RLS; assignment/escalation writes go through SECURITY
DEFINER RPCs (016 pattern).

## ADR-052: Emergency chat is conversation-level priority, not a second engine

**Date:** Session 43 (2026-08-15)
**Status:** Accepted
**Deciders:** Lead Architect + user approval

### Context
No emergency concept exists on chat; `complaints.priority` and ride-bound `sos_alerts` are unrelated.

### Decision
Emergency is `chat_rooms.priority = 'emergency'` (with normal/high/urgent). It affects routing
(highest-available admin / escalation to parent/global), notification urgency (dedicated high-priority
channel via existing FCM/realtime infra), and admin visibility (filter). No separate message transport.

### Rationale
One chat engine; escalation semantics reuse the D3 extension; notifications reuse 026/018 infra.

### Consequences
Implementations land in 2.3 (schema), 2.4 (urgency/deep-links), 2.5 (escalation engine). No standalone
emergency system.

---

## ADR-053: Add Kilo AI Gateway as an independent anonymous free OpenCode provider

**Date:** Session 44 (2026-08-15)
**Status:** Accepted
**Deciders:** Lead Architect (additive integration; existing providers untouched)

### Context
Need additional free model capacity for OpenCode without any new account/API key. Kilo AI Gateway
(`https://api.kilo.ai/api/gateway`) is an OpenAI-compatible gateway that officially allows
**unauthenticated access to free models** (models tagged `:free` or flagged `isFree=true`), rate
limited to **200 requests/hour per IP**.

### Decision
Register a new `kilo` provider in `/root/.config/opencode/opencode.jsonc` using the standard
`@ai-sdk/openai-compatible` package with `baseURL: https://api.kilo.ai/api/gateway` and a
non-sensitive dummy `apiKey`. Add **9 verified free models** that passed the full qualification
matrix (basic completion, streaming SSE, tool calling, agent-loop roundtrip): `kilo-auto/free`,
`poolside/laguna-s-2.1:free`, `poolside/laguna-xs-2.1:free`, `cohere/north-mini-code:free`,
`nvidia/nemotron-3-ultra-550b-a55b:free`, `nvidia/nemotron-3-super-120b-a12b:free`,
`nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free`, `tencent/hy3:free`,
`dots-studio/dots-3-note-preview:free`.

### Rationale
- Strictly additive: a new provider block only; the 8 OmniRoute models, Google/Groq/OpenRouter
  providers, lifecycle, and Delwaqty repo are untouched (config backed up before edit).
- Anonymous access officially documented (Authentication page); no credentials exposed.
- Tool calling + streaming verified for all added models → agent-capable.

### Consequences
- All 9 models consume the shared 200 req/h anonymous budget per IP (documented rate limit, not
  bypassed).
- Excluded: `nvidia/nemotron-3.5-content-safety:free` (guardrail, not a coding model),
  `liquid/lfm-2.5-2.6b:free` (too slow, 44 s coding latency), `openrouter/free` (redundant with
  existing OpenRouter provider), `stepfun/step-3.7-flash:free` (already reached via `kilo-auto/free`).
- Test harnesses kept at `/tmp/opencode/kilo_*.sh`; catalog snapshot at
  `/tmp/opencode/kilo_models_live.json`.
- If Kilo ever requires auth for free models, the block is simply disabled with no production impact.

---

## ADR-054: Add LLM7 Gateway as an independent anonymous free OpenCode provider

**Date:** Session 44 (2026-08-15)
**Status:** Accepted
**Deciders:** Lead Architect (additive integration; existing providers untouched)

### Context
After GitHub deep search (free-coding-models, mnfst/awesome-free-llm-apis, FreeLLMAPI, models.dev
registry), only two providers allow **fully anonymous, keyless** free inference: LLM7.io
(`https://api.llm7.io/v1`) and OVHcloud AI Endpoints. OVH's permanent **2 RPM/IP/model** cap makes it
unusable for interactive agent loops (alternates 429/200 even when spaced). LLM7 is anonymous,
OpenAI-compatible, and verifiably free.

### Decision
Register a new `llm7` provider in `/root/.config/opencode/opencode.jsonc` using
`@ai-sdk/openai-compatible` with `baseURL: https://api.llm7.io/v1` and **NO `apiKey` option**
(LLM7 returns 401 for any non-empty `Authorization` header — verified; empty/no header → 200).
Add **6 verified free anonymous models**: `default` (auto→Codestral), `gpt-oss:20b`,
`DeepSeek-V4-Flash-0731`, `gemini-3.1-flash-lite`, `codestral-latest`, `minimax-m2.7`.

### Rationale
- Strictly additive: new provider block only; OmniRoute (8), Kilo (9), Google/Groq/OpenRouter,
  lifecycle, and Delwaqty repo untouched (config backed up to `/root/.opencode_llm7_backup_2026-08-15.jsonc`).
- **Independence score 5**: LLM7 is a completely new upstream (Azure/Cloudflare/DeepSeek/Mistral
  hosted gateway), NOT an alias of OmniRoute or Kilo.
- Full qualification matrix passed for added models: basic (200), coding (Dart addTwo + Flutter
  AGP/compileSdk diagnostics accurate), streaming SSE (`[DONE]`), tool calling
  (`finish_reason: tool_calls`), agent-loop roundtrip (Class A for gpt-oss:20b,
  DeepSeek-V4-Flash-0731, gemini-3.1-flash-lite, minimax-m2.7; Class B for codestral).
- Verified end-to-end through `@ai-sdk/openai-compatible` v3 (`chatModel`), no auth header sent.

### Consequences
- Anonymous burst limit ~5-6 req then transient 429, recovers in ~15 s; docs claim 30 RPM anon.
  All 6 models share this anonymous IP budget.
- Excluded: `mistral-Nemo-Instruct-2407` (no tool support), `pro`/premium aliases (402 paid),
  `claude-*`/`gpt-5.x`/`kimi-*`/`gemini-3-flash` etc. (401 — require key).
- Excluded: OVHcloud AI Endpoints (2 RPM/IP permanent — impractical for agent use despite being free).
- Test harnesses: `/tmp/opencode/llm7_*.sh`, `/tmp/opencode/llm7_probe.py`, `/tmp/opencode/llm7_tool.py`,
  `/tmp/opencode/llm7_coding2.py`, `/tmp/opencode/llm7sdk/` (SDK verification).

---

## Verification Record (non-ADR): Phase 2.1 live apply + default-privilege security hardening

**Date:** Session 45 (2026-08-15)
**Status:** Applied, verified live, closed. Not a new decision — records the verification and
implementation-level fix for accepted **ADR-050 / D1–D4**.

### Context
Migration 030 (implementing ADR-050) was applied to the live project `bttnlkmwhorjamzemwda` via the
Supabase Management API and verified end-to-end.

### Finding (discovered during the live gate)
Supabase's platform `ALTER DEFAULT PRIVILEGES` auto-grants **ALL** privileges (including
`TRUNCATE`/`TRIGGER`/`REFERENCES`) on new tables to `anon`, `authenticated`, and `service_role`.
Migration 030's `GRANT`s were purely additive, so on first live apply `anon` held full DML +
`TRUNCATE` on `regions` and `user_region_preferences` — exceeding the approved grant model
(regions: anon SELECT-only; preferences: no anon access) and leaving a DB-level write path
(`TRUNCATE`) that RLS does not cover.

### Fix
Enforced the approved model with revoke-before-grant inside **migration 030** (no new migration,
no previously-applied migration touched):

```sql
REVOKE ALL ON public.regions FROM anon, authenticated;
REVOKE ALL ON public.user_region_preferences FROM anon, authenticated;
GRANT SELECT ON public.regions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.regions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_region_preferences TO authenticated;
```

### Verified final ACL state (live)
- `regions`: anon = **SELECT only**; authenticated = SELECT/INSERT/UPDATE/DELETE (admin writes
  gated by `is_admin()` RLS); no TRUNCATE/TRIGGER/REFERENCES for either.
- `user_region_preferences`: anon = **no access**; authenticated = SELECT/INSERT/UPDATE/DELETE
  (owner-only writes via `auth.uid() = user_id` RLS).

### Consequences
- RLS remains authoritative; the revoked surface additionally closes non-RLS paths (`TRUNCATE`).
- Live data verified: 28 regions (1 Egypt root + 27/27 governorates), 0 duplicates, 0 orphans;
  idempotent re-run confirmed.
- Functional RLS tests passed: anon INSERT → 42501; anon UPDATE/DELETE → no-op (data intact);
  non-admin authenticated region INSERT → 42501; owner can write regions + own preference but not
  another user's preference.
- Full details: `docs/HANDOFF/27_SPRINT_76_PHASE2_REGIONS.md` §8.

---

## ADR-055: Admin hierarchy model for Phase 2.2 (two-tier owner > admin + region scoping)

**Date:** Session 46 (2026-08-15)
**Status:** Accepted (design gate)
**Deciders:** Lead Architect (evidence-first; live audit §2 of
`docs/HANDOFF/28_SPRINT_76_PHASE_2_2_ADMIN_HIERARCHY_AUDIT.md`)

### Context
D1 (canonical admin identity) was already resolved — ADR-049 chose the 016 model
(`users.role IN ('admin','owner')` + `public.is_admin()`) over `admin_users`. The Phase 2.2 design
gate had to define the *hierarchy itself* on top of that identity. Live evidence: 5 `users` (3
customer, 1 provider, 1 owner, 0 admin), `admin_users` 0 rows, `is_admin()` already gate ~28
policies across 13 tables.

### Decision
1. **Hierarchy is derived from `users.role`, no new identity table:** two tiers — `owner` (rank 100)
   > `admin` (rank 90). No `users` schema change, no new role values.
2. **Region scope via one new table `admin_region_assignments`** (admin_id FK users, region_id FK
   regions, scope `self|descendants`): an `admin` with no rows = global scope; with rows = scoped to
   the assigned regions **and their descendants** (reuses the 030 hierarchy). Owner = implicit global.
3. **`admin_profiles` DEFERRED (YAGNI):** with 0 admins live and two tiers, a per-admin profile table
   adds no capability; the Dart `AdminPermission`/`PermissionLevel` enums remain aspirational. Revisit
   at 2.5 if granular permission levels become real.
4. **`admin_users` stays dormant legacy metadata** (rule 12.1 keep): add a `user_id` FK link column
   (connect, not fork) in migration 031; never a gate.
5. **2.2 permission parity:** `is_admin()` surface unchanged (admin == owner); the only
   differentiation is region scope via new SECURITY DEFINER helper `public.is_admin_for_region()`.

### Rationale
- Evidence shows zero live admins and a working `is_admin()` surface — building a parallel identity
  hierarchy would duplicate authority for no current benefit.
- Region scoping is the concrete 2.3/2.5 need (routing + escalation parent walk) and reuses the
  shipped 030 region tree.
- Escalation parent walk contract: scoped admin → regional parent → ancestor → global/owner; global
  cannot escalate above itself.

### Consequences
- Migration `031_admin_hierarchy_region_assignments.sql`: link column on `admin_users` + new
  `admin_region_assignments` table + `is_admin_for_region()` helper (016 pattern), RLS via
  `is_admin()`, revoke-before-grant (030 lesson).
- Flutter: shared `isAdminUser` helper replacing 6 literal gates; admin_web auth gate; region-scope
  UI (2.3-ready). `AdminRole` Dart enum vs SQL CHECK misalignment is a user decision (Gate Q1).
- No commit/push this gate; implementation follows user approval.

---

## ADR-056: Standardize admin RLS on `public.is_admin()` and eliminate literal-role drift

**Date:** Session 46 (2026-08-15)
**Status:** Accepted (design gate)
**Deciders:** Lead Architect (audit finding F1/F2 — live-qualified)

### Context
Full live policy-surface capture exposed two identity drifts that break the single-authority model
(ADR-049/055):

- **F1 — literal `users.role = 'admin'` (excludes `owner`)** on 6 policies: `activity_logs` SELECT
  ("viewable by admins only"), `platform_settings` UPDATE ("Settings updatable by admins"),
  `categories` ALL ("Admins can manage categories"), `admin_users` SELECT ("viewable by admins
  only"), `notification_tokens` SELECT ("Admins read all tokens"). The owner — the only admin-tier
  account live — is silently locked out of all of these today.
- **F2 — third identity source:** `service_audio_logs` "admin all logs r" reads
  `auth.users.raw_user_meta_data->>'role'` instead of `public.users.role`/`is_admin()`.
- **F3 (debt):** duplicate/redundant policies on `notifications` (2× SELECT, 3× INSERT, 2× UPDATE,
  2× DELETE) and `notification_tokens` (2× SELECT, 2× user ALL) — additive, not security holes.

### Decision
Migration 031 will (a) rewrite all six F1/F2 policies to `USING public.is_admin()` (+ matching WITH
CHECK where applicable), and (b) drop the redundant duplicate policies, keeping the `is_admin()`
variants. Single server-side authority: `public.is_admin()`; `is_admin_for_region()` for scope.

### Rationale
- Restores the approved single-authority model (ADR-049) and fixes an active live defect (owner
  currently excluded).
- Removing duplicates is safe: they are same-table overlaps (OR-satisfiable); coverage is never
  reduced below today's `is_admin()` surface.
- `raw_user_meta_data` is not maintained by the app's role flows and can silently desync from
  `users.role`.

### Consequences
- Owner regains admin surface on the 6 tables immediately after 031 applies.
- Verified in the 2.2 implementation gate by live RLS probes (owner/global-admin/scoped-admin/anon
  matrix, §7 of doc 28).
- No behavioral change for non-admin roles; no data changes; additive coverage only for owner.

---

## ADR-057: Egypt complete geographic coverage — layered model, hybrid geocoder, extended region taxonomy

**Date:** Session 48 (2026-08-15)
**Status:** Accepted (Phase 2.1B approved implementation)
**Deciders:** Lead Architect (D1/D2/D3 user gate approved; audit
`docs/HANDOFF/30_EGYPT_COMPLETE_GEOGRAPHIC_COVERAGE_AUDIT.md` §0.1)

### Context
Phase 2.1 shipped the canonical 27-governorate hierarchy (ADR-050, migration 030). Phase 2.1B must
extend geographic coverage to the full Egyptian admin hierarchy (markaz / aqsam / cities / villages /
new cities) and add a tourism/POI layer for GPS resolution, region selection, and admin scoping —
without fabricating data, without breaking `is_admin_for_region()` (ADR-055/056, migration 031), and
without turning the geo layer into a business directory. Three decisions were gated to the user:
authoritative dataset (D1), geocoder stack (D2), and `regions.type` taxonomy (D3).

### Decision
- **D1 — layered authoritative-data strategy.** Load dataset = OCHA HDX COD-AB Egypt (CC BY-IGO;
  admin levels 0–3 with Arabic/English names and stable pcodes). New cities = Wikipedia/NUCA roster
  (52, SECONDARY VERIFIED; New Galala flagged not-NUCA). Places = GeoNames (CC BY 4.0) +
  Wikipedia + OSM Nominatim for verified coordinates. Gaps are reported, never guessed.
- **D2 — hybrid geocoder.** Server-side 016-pattern proxy (`geo_region_for_point`) using PostGIS
  point-in-polygon over `geo_admin_boundaries` (ADM1+ADM2), nearest-boundary snapping within
  tolerance, nearest-governorate-centroid fallback (LOW). Photon/OSM + GeoNames are storable;
  Google is online-only and never persisted (ToS). Provider disagreement feeds confidence, never
  fabrication.
- **D3 — additive `regions.type` CHECK.** Extended to
  `country / governorate / markaz / district / city / village / new_city / area`. Urban aqsam are
  stored as `district` (no `qism` overload). Hotels/resorts/tourist villages/compounds/airports/
  ports/universities/landmarks/POIs live in `geo_places`, never in `regions`.
- **Migration 032** (two files): `032_egypt_geographic_schema.sql` (schema + RLS + grants +
  `CREATE EXTENSION IF NOT EXISTS postgis` + `pg_trgm` + SECURITY DEFINER
  `geo_region_for_point(lat, lon, max_depth DEFAULT 2, tolerance_m DEFAULT 25000)` with
  `SET search_path = public, pg_temp`; EXECUTE granted to authenticated only) and
  `032_egypt_geographic_seed.sql` (idempotent deterministic seed: 6,129 new region rows,
  64 `geo_places`, 6,879 `geo_aliases`, 374 admin-boundary polygons). 030/031 untouched; the 28
  canonical IDs remain immutable.
- **Provenance contract.** Every canonical record carries `source`, `source_ref`, `source_date`,
  `source_type` (OFFICIAL VERIFIED / SECONDARY VERIFIED / PROVIDER-DERIVED / UNVERIFIED-MISSING),
  `confidence` (HIGH / MEDIUM / LOW / UNVERIFIED), and `provenance`.
- **Confidence gates.** HIGH may persist a detected region; MEDIUM only if policy allows; LOW never
  auto-persists; detection never overwrites manual/verified preferences.
- **Deterministic IDs.** Governorates immutable; new admin rows are UUID v5 in namespace
  `6f8f4a72-4a3b-4e2a-9d11-9a2c5e6f7a01` keyed on source pcode/id; `geo_places` v5 from
  `source+source_ref`; never random.

### Rationale
- OCHA COD-AB is the only open, machine-readable, licensed dataset with full Arabic names and stable
  pcodes for levels 0–3 (audit §3–§7, §24); CAPMAS/MLD licensing is uncleared so they stay as
  cross-checks only.
- PostGIS point-in-polygon (option B) + string candidate input (option D) + nearest-centroid
  fallback (option E) is the audited recommended spatial design (§17); it keeps GPS resolution
  server-side, deterministic, and RLS-safe with no heavy Flutter spatial.
- Additive CHECK + single canonical admin tree keeps `is_admin_for_region()` parent-walks valid and
  the selection/routing UI unchanged in shape (audit §21).
- Deterministic UUIDs + `ON CONFLICT DO NOTHING` make re-imports idempotent and auditable (R9).

### Consequences
- Live DB now holds 6,157 regions (28 canonical + 6,129 new), 64 `geo_places`, 6,879
  `geo_aliases`, 374 `geo_admin_boundaries`; verified RLS (anon SELECT-only, admin write),
  zero orphans/duplicates/cycles, connected acyclic tree depth 4.
- `geo_region_for_point` resolves GPS fixes to governorate/markaz/district and (max_depth ≥ 3)
  village/area/new_city with HIGH/MEDIUM/LOW confidence — the client pipeline consumes it via the
  extended resolver and confidence policy.
- Flutter `regions` module extends `RegionType` and adds `GeoPlace`/`GeoAlias` entities, an extended
  resolver, a confidence model, and a server-side GPS resolution provider.
- `geo_admin_boundaries` polygons are rounded to 4 decimals (~11 m) — precision reduction of the
  authoritative boundary for payload size, preserving containment semantics.
- Future Phase 2.3 (chat routing) and admin scoping reuse the deeper hierarchy unchanged.

**Amendment (Session 48, post-gate independent review 2.1B — all applied + live re-verified):**
- **A1 — EXECUTE lockdown (finding 2.1B-F2).** Supabase `ALTER DEFAULT PRIVILEGES` auto-grants
  EXECUTE to `anon`/`authenticated`/`service_role` at function creation, so `REVOKE ... FROM PUBLIC`
  alone left `anon` holding EXECUTE on `geo_region_for_point`, `is_admin()`, legacy `is_admin(uid)`
  and `is_admin_for_region()`. Migration 032 now ends with explicit
  `REVOKE ALL ON FUNCTION ... FROM anon` (plus `FROM PUBLIC` for legacy `is_admin(uid)`), so the
  documented "authenticated-only EXECUTE" actually holds live (verified via
  `has_function_privilege('anon', ..., 'EXECUTE') = false`). Functions were read-only/RLS-safe
  regardless; this closes the privilege-vs-documentation gap and applies least privilege.
- **A2 — boundary validity (finding 2.1B-F1).** 4-decimal rounding produced ring
  self-intersections in all 27 ADM1 governorate polygons (`ST_IsValid=false`). The seed generator now
  emits `ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_SetSRID(ST_GeomFromGeoJSON(...),4326)),3))`
  and upserts `geometry, license` on conflict. Live re-apply: 374/374 valid MultiPolygons (0 invalid),
  all GPS probes re-verified identical (Pyramids → EG-ADM2-2106 HIGH; Dikirnis → EG-ADM3-120903 HIGH;
  Hurghada → EG-ADM2-3101 HIGH; New Capital → EG-NC-NEWADMINISTRATIVECAP HIGH).
- **A3 — license metadata accuracy (finding 2.1B-F3).** `regions.metadata.license` now matches each
  source (OCHA `CC BY-IGO`, Wikipedia `CC BY-SA 4.0`, GeoNames `CC BY 4.0`); `geo_places.license`
  populated per source (GeoNames `CC BY 4.0`, Wikipedia `CC BY-SA 4.0`, OSM `ODbL`). Validated in the
  generator (build fails on mismatch).
- **A4 — self-healing seed.** Boundary/region/place upserts now `DO UPDATE` (metadata/license/
  geometry) so re-running the seed repairs previously-applied environments; still deterministic and
  idempotent. `geo_aliases` remains `DO NOTHING`.

---

## ADR-058: Phase 2.3 — Member management, support routing, emergency & admin delegation architecture

**Date:** Session 49 (2026-08-16)
**Status:** Accepted (architecture audit approved for design; implementation gated per phase)
**Deciders:** Lead Architect — audited per directive; owner gate questions listed in
`docs/HANDOFF/PHASE_2_3_MEMBER_MANAGEMENT_SUPPORT_ARCHITECTURE_AUDIT.md` §32

### Context
Phase 2.3 must deliver support chat priority/region/assignment (ADR-051/052, doc 28 §5) **plus**
member management, moderation, account deletion, emergency (incl. live-audio foundation), regional
offers, approval workflow, member timeline, birthday/anniversary engines — over the existing
backend (016/031 admin identity, 030/032 regions/geo, realtime, notifications). Directive forbids
duplicate architecture/security systems and requires hierarchical (non-flat) admin delegation with
no hardcoded level count.

### Decision
- **Hierarchy = two orthogonal axes.** Supervision tree (`admin_management.admin_id/supervisor_id`,
  owner = implicit root, depth derived, not stored) for management/delegation/approvals; existing
  `admin_region_assignments` (self/descendants) for visibility/routing. No fixed admin levels.
- **Permissions = computed defaults + explicit grants** (`admin_permission_grants`); central
  `has_permission()` (identity + role + supervisor + delegated permission + scope + target + action)
  used by RPCs and RLS. Final penalty/approval mapping stays config-driven (not hardcoded now).
- **Support chat (migration 033):** additive `chat_rooms` columns (priority incl. `emergency`,
  region_id, assigned_admin_id, assigned_at, status, escalated_at, escalated_from_admin_id,
  closed_at) + guard triggers (non-admins can't set priority/status/assignee) + routing
  (region-scoped → parent-region walk → global → owner; deterministic; live = owner fallback) +
  escalation keeps the same conversation (ledger `chat_escalations`). **Do NOT write 033 in this
  gate.**
- **Moderation:** reuse `sanctions` (additive `approving_admin_id/evidence_url/action_status`) +
  `users.account_status` (server-only writes). **Deletion is member management, not moderation**:
  soft-delete + anonymize, audit preserved.
- **Emergency:** `sos_alerts` (ride-safety) reused; emergency support = `chat_rooms.priority=
  'emergency'` (ADR-052); command center = realtime feed. **Live audio = foundation only**
  (`emergency_audio_sessions` state/audit + EMERGENCY_AUDIO grant + customer-visible state; no
  transport, no recording, no hidden mic).
- **New tables** (each justified, no reuse possible): `admin_management`, `admin_permission_grants`,
  `approval_requests` (generic Approval Center), `member_events` (customer-readable timeline vs
  admin-only `activity_logs`), `chat_escalations`, `regional_offers`+`offer_reviews` (distinct from
  merchant `offers`), `emergency_audio_sessions`, `member_rewards` (birthday/anniversary idempotency).
- **RLS fixes (live findings) in 033:** `activity_logs` INSERT `TO public` → `service_role`;
  `driver_locations` read `auth.role()='authenticated'` → ride participants + admin; add `sos_alerts`
  admin SELECT. All new RPCs 016-pattern (SECURITY DEFINER, SET search_path, revoke-before-grant,
  anon EXECUTE revoked).
- **Privacy/retention:** sensitive data permission+scope-gated; configurable retention
  (`apply_retention_policies`), no unlimited location history, no exact admin location to customers.
- **Phasing:** 033 support+RLS → 034 delegation+permissions+approvals → 035 member mgmt+timeline+
  moderation+deletion → 036 emergency center+audio foundation → 037 offers → 038 birthday/anniversary
  +retention. Each phase gates independently; 2.4 (FCM/push) stays out of scope.

### Rationale
- Reuses every existing asset (chat, notifications, realtime, sanctions, sos_alerts, regions/geo,
  activity_logs, admin hierarchy) — no duplicated engines.
- Server stays the only authorization authority; UI mirrors permissions only.
- Deterministic routing and hierarchy-derived authority make the platform auditable and scalable to
  the four-client split (customer/provider/driver/admin over one backend).

### Consequences
- Migration numbering shifts: 033 = support chat (doc 32 superseded by the master audit), 2.4 = 034,
  2.5 = 035 (renumbered in ROADMAP.md).
- Three live security gaps are on the 033 RLS-fix list (activity_logs anon INSERT, driver_locations
  wide read, sos_alerts admin access).
- Approved only at architecture level; owner decisions §32 of the audit must be confirmed before any
  migration is written. No code, no 033, no commit/push produced in this gate.

## ADR-059: Promotion/Content/Campaign platform — regional offers merge & dedicated migration range

**Date:** Session 50 (2026-08-16)
**Status:** Accepted (owner decisions O1–O6 approved; migration 039 implementation authorized, gated)
**Deciders:** Owner (O1–O6) + Lead Architect — documented per
`docs/HANDOFF/PHASE_2_PROMOTION_CONTENT_ARCHITECTURE_AUDIT.md` §40 (O1–O6)

### Context
The owner approved the promotion/content/campaign audit (40 sections + M verdict letter, 🟡 → 🟢 for
O1–O6) and authorized implementation. The audit proved the existing promotion-adjacent assets are not
campaign containers (merchant `offers` is read-only under RLS, commerce-shaped; `coupons`/`promo_codes`
are benefit references; home promo carousel is hardcoded in Dart). No campaign/banner/content tables,
no `regional_offers`, no `approval_requests` exist live. Phase 2.3 (033–038) remains unapproved and
unimplemented, so the promotion platform must own the generic approval table it depends on.

### Decision
- **REGIONAL OFFERS MERGE (O1).** Do **not** implement `regional_offers` + `offer_reviews` (ADR-058
  migration 037). They are **superseded** by the campaign platform: `campaigns` (type `offer`) +
  `campaign_reviews`. Merchant `offers` is untouched and becomes a referential benefit target. ADR-058's
  "037 offers" and its `regional_offers`+`offer_reviews` table set are **amended** accordingly; the rest
  of ADR-058 stands. No production data exists to migrate (table never created); no code references
  `regional_offers` (verified: zero matches in `lib/` and `supabase/`).
- **Migration range (O2).** 033–038 = Phase 2.3 (unchanged). **039–042 = Promotion platform:**
  - **039** `promotion_campaign_schema` — core campaign domain: `campaigns`, `campaign_banners`,
    `campaign_reviews`, `campaign_cta_routes`, `campaign_seen` + RLS/grants + validate helpers.
  - **040** `promotion_targeting_media_approval` — `campaign_targets` (multi-region junction, no
    duplicated campaigns), `campaign-media` bucket + storage policies, CTA/benefit validation, generic
    **`approval_requests`** (created here, verbatim 2.3 §19 contract — the ONE approval center) +
    campaign lifecycle/approval RPCs wired to the supervision hierarchy.
  - **041** `promotion_security_hardening` — public feed RPC `get_active_campaigns` (server-authoritative
    eligibility: published + window + audience + region + frequency + emergency lane), `get_admin_campaigns`,
    hardening indexes/RLS/function privileges, campaign engines (`run_campaign_engines`: auto-publish /
    expire — no pg_cron).
  - **042** `promotion_analytics_config` — `campaign_events` + `campaign_metrics` (batched ingestion,
    async aggregation), `track_campaign_event`, `aggregate_campaign_metrics`, `get_campaign_analytics`,
    `platform_settings.promotions` config (frequency defaults, `free_delivery_enabled`), retention wiring.
- **Approval (O3).** Campaign approvals reuse the generic `approval_requests`. Because 2.3 is
  unimplemented, **migration 040 creates `approval_requests`** (matching ADR-058/2.3 §19 DDL exactly);
  when 2.3 ships, its 034 is **amended to not recreate it** (creates only `admin_management`,
  `admin_permission_grants`, `has_permission`). Authority now = `is_admin()` + `is_admin_for_region()`
  + `admin_region_assignments` scope (owner implicit global; 0 admins live → owner routes approvals
  deterministically). Future supervision chain plugs in via `required_approver` without schema change.
  No `campaign_approval_requests`. No self-approval, no self-elevation, cross-region prohibited, reason
  mandatory on every rejection, actor+timestamp on every approval.
- **Frequency + free delivery (O4).** Frequency control is in the core schema (`campaign_seen` in 039,
  enforcement in 041 feed RPC): impression limit/cooldown/daily limit per user, optional dismissal,
  campaign-level override, global defaults in `platform_settings.promotions` (no hardcoded values;
  safe default ≤ 3 impressions/user/day for ordinary promotional banners; emergency/critical exempt).
  `free_delivery` benefit is config-flagged + explicitly approved + audited; the promotion engine only
  **describes** the benefit — the order/pricing engine remains authoritative. A banner alone never
  creates a financial entitlement.
- **Media (O5).** Dedicated `campaign-media` bucket (public read only; admin/service-role
  upload/update/delete, strict MIME png/jpeg/webp, ≤ 5 MB, no executables, no unpublished leak, orphan
  cleanup + auditability). PostgreSQL stores only storage references — never binary media.
- **Content seeds (O6).** **No automatically published seeds.** Any dev/test content is created as
  `draft`, never exposed, clearly marked test/demo. Production content is created through the admin
  workflow only. The home carousel renders only published/eligible campaigns (empty until admin content
  exists).

### Rationale
- Single promotion lifecycle (approve→publish→expire→archive) instead of two parallel machines;
  directive §1/§9 duplicate-concept prohibition.
- Campaign types distinguish commercial / content / operational / emergency (separate priority lane);
  emergency/critical content is exempt from marketing frequency limits and eligible for realtime
  broadcast via the existing `notifications` channel — never ordinary marketing behavior.
- All reads flow through a SECURITY DEFINER feed RPC with `SET search_path`; campaign tables have **no
  client SELECT** — unpublished content cannot leak even via direct table access (defense in depth).
- Reuses regions/geo, admin hierarchy, `notifications` (type `promotion`, realtime already published),
  Hive/Ttl caching — no new infra, no Redis, no second region/authz/approval system.

### Consequences
- 2.3 migration 037 is cancelled/absorbed; 2.3's 034 must not recreate `approval_requests` (documented
  in the 039 gate; owner ratification noted at 2.3 approval time).
- Migration numbering 039–042 is reserved for promotion; pre-existing 2.3(034–038) vs 2.4(034)/2.5(035)
  overlap in ROADMAP remains flagged for owner resolution.
- Hardcoded home carousel content (`DELWAQTY30`, `_PromoCarousel` slides) is removed in the Flutter
  phases (E/F); until admin content exists the carousel is empty by design (O6).
- 039 implements core schema only and gates independently; **no migration 040+ is written until the 039
  gate passes owner review** (`docs/HANDOFF/PHASE_2_PROMOTION_MIGRATION_039_GATE.md`).


## ADR-060: Promotion 040 — targeting, approval center ownership, lifecycle RPCs, campaign media

**Date:** Session 51 (2026-08-16)
**Status:** Accepted (040 gate pass, pending owner ratification)
**Deciders:** Lead Architect (implementation under owner-approved O1–O6 / ADR-059 / 040 directive)

### Context
Migration 039 (campaign core schema) passed its gate. 040 must deliver targeting, audience
wiring, the generic approval center, lifecycle RPCs, authorization and the campaign-media bucket
without touching 030/031/032/039, without duplicating regions/approval/system concepts, and
without destroying production data.

### Decision
- **Targeting = `campaign_targets`** many-to-many junction (campaign_id + nullable region_id;
  region_id NULL = national/Egypt). Multi-region = multiple rows on ONE campaign (no duplicated
  campaigns). Partial unique index `campaign_targets_national_unique` -> at most one national row.
- **Audience = existing `campaigns.target_roles`** (validated by 039's
  `campaign_validate_target_roles`); no new audience table (minimal + sufficient).
- **`approval_requests` created in 040** verbatim per 2.3 §19 contract; request_type
  `campaign_approve`; `required_approver` NULL = owner. 2.3's 034 is amended (not to recreate it).
- **Lifecycle API = 8 SECURITY DEFINER RPCs**: `campaign_submit`, `decide_approval_request`
  (2.3 §19 signature; dispatches campaign_approve only), `campaign_publish`, `campaign_pause`,
  `campaign_resume`, `campaign_archive`, `campaign_cancel`, `campaign_purge_media` + scope helpers
  `campaign_can_target_region` / `campaign_targets_authorized` + storage helpers
  `campaign_id_from_storage_path` / `campaign_published_for_storage` / `campaign_scoped_for_storage`.
- **Media metadata = `campaign_media`** (kind thumbnail/detail_image/gallery_image, image_path,
  is_active, sort_order); storage references only — no binary in PostgreSQL. `campaign_banners`
  stays the display-slot config (placement/locale/CTA).
- **Orphan cleanup = `campaign_purge_media`** (terminal states only): deletes storage objects
  (via `storage.allow_delete_query` GUC) + deactivates media/banners. No background infra.
- **No second hierarchy**: approval authority = `is_admin()` + `admin_region_assignments` scope +
  owner (global). Self-approval blocked unless requester is owner. Cross-region approval blocked
  (`campaign_targets_authorized`). National/global publish requires global authority (owner or
  admin with no region assignments). Rejection + cancellation require a reason. Every decision
  records `campaign_reviews` + updates `approval_requests` + `notifications` (idempotency key
  campaign-approve/-reject-<request_id>, type promotion, deep_link /campaign/<id>).
- **Client INSERTs always land in `draft`**: `campaigns_set_creator` forces `status := 'draft'`
  on INSERT (039's guard trigger is UPDATE-only; without this a client insert could bypass the
  approval lifecycle straight into published).
- **Storage `campaign-media` bucket**: private; published-read policy
  (`campaign_published_for_storage`) so unpublished media never leaks; admin upload/update/delete
  policies gated by `campaign_scoped_for_storage` (admin + real campaign + scope); service_role
  bypasses RLS; strict MIME png/jpeg/webp <= 5 MB.
- **Grants**: no DELETE on `campaigns` (archival only); `approval_requests` SELECT-only for
  authenticated (writes are RPC-only); anon gets nothing.

### Rationale
- Normalized targeting avoids duplicated campaigns (directive §1/§9 duplicate-concept prohibition).
- One generic approval center owned by the platform that needs it (ADR-059 O3); no
  `campaign_approval_requests`.
- RLS-scope + SECURITY DEFINER RPCs keep state transitions server-enforced; direct table DML by
  non-admins is impossible (grants + RLS), and admins cannot bypass approval preconditions.
- Storage access via helpers keeps ownership/scope validation in one place (016 pattern).

### Consequences
- Feed RPC (041) reads targeting via `campaign_targets` + audience via `target_roles` +
  published media via bucket policy; analytics (042) reuse `campaign_media`/`campaign_seen`.
- 2.3 034 must not recreate `approval_requests` (amended).
- `campaigns` UPDATE remains RLS-gated with scope; lifecycle preconditions (window, national
  global check, reasons) are enforced in the RPC layer.

## ADR-061: Phase 2.3 implementation — member rewards ledger, engines, retention & Flutter rewards layer

**Date:** Session 52 (2026-08-16)
**Status:** Accepted (033/034/035/038 applied live + probe-verified; full gate green; pending owner
ratification of the 2.3 decision-lock)
**Deciders:** Lead Architect (implementation under owner's Session-52 7-phase authorization permit)

### Context
The owner-authorized 7-phase run requires Phase 2.3 = migrations 033–038 + Flutter layer + gate.
033/034/035 shipped and verified in earlier Session 52 work. This ADR covers migration 038 (member
rewards + engines + retention), the `write_audit` service-context hardening the live probe exposed,
and the Flutter rewards presentation layer.

### Decision
- **Ledger:** `member_rewards` (reward_type `birthday|anniversary`, `period_key` idempotency token,
  `benefit` jsonb validated by `_reward_benefit_valid` incl. a `free_delivery` gate tied to
  `platform_settings.promotions.free_delivery_enabled`, `campaign_id` optional ref, `status`
  `granted|claimed|expired`, `notified_at`). RLS: own-read for the member + admin-read via
  `has_permission('MEMBER_VIEW', _member_region_id(user_id))`.
- **Engines:** single deterministic `run_member_engines(date)` (SECURITY DEFINER, `search_path`
  pinned, service_role-only EXECUTE) grants birthday + anniversary rewards; suspended members and
  `admin` role excluded; per-period idempotent via `period_key` (double-run = no-op); each grant
  writes a `member_events` row (`birthday_reward`/`anniversary_reward`) and a notification with
  idempotency key `reward-<type>-<period>-<uid>`.
- **Retention:** `retention_policies` (9 M1-default policies; disabled = keep) +
  `apply_retention_policies()` purges expired rows per policy (archive step for `activity_logs`),
  skips absent tables without error, audits every purge (`RETENTION_PURGED`), and never touches
  active sanctions or non-expired campaigns (archived/expired only).
- **`write_audit` hardening (root-cause fix):** 033's `write_audit` inserted `auth.uid()::text`
  into NOT NULL `activity_logs.user_id`, which crashed every audit call made from service context
  (no JWT → NULL). 038 `CREATE OR REPLACE`s it with `COALESCE(auth.uid()::text, 'system')`;
  signature and service_role-only ACL unchanged.
- **Flutter layer:** new `features/rewards` module (registered in `lib/module_registry.dart`,
  `/rewards` route, profile tile) with freezed `MemberReward` (`benefitKind` getter via
  `const MemberReward._()`), own-read `SupabaseRewardsDataSource` using repo-convention
  snake_case→camelCase `_fromRow` mapping (**no `@JsonKey` on factory params**), repository impl
  wrapping `ServerException`, `myRewardsProvider` (autoDispose, gated on `AuthAuthenticated.user.id`,
  empty list for guests), and an l10n-driven `RewardsPage`. `NotificationType.reward` added with
  icon/color mapping (incl. the admin push-notifications exhaustive switch).

### Rationale
- A ledger + idempotent engine keeps rewards grant-once and audit-traced; config-driven benefit
  selection avoids hardcoded benefit logic in the engine (architecture-first rule).
- Retention as configurable policies (rather than hardcoded deletes) matches the 2.3 §19 privacy
  contract and stays owner-tunable via the admin surface.
- The probe exposed a real service-context crash before it could affect production retention runs;
  the COALESCE fix keeps audit identity (JWT when present, `system` in trusted service context).
- Flutter integration mirrors proven repo patterns (service_audio_logs module shape,
  notifications `_fromRow`, profile usecase-provider wiring) so the feature is modular, registered,
  and independently tested (8 new tests).

### Consequences
- 039/040 campaign facts unchanged; `campaign_expire` whitelist in 039 remains the campaign
  lifecycle path (engine reads it, never mutates campaigns directly).
- `write_audit` now tolerates service-context callers; callers that need real actor identity must
  run under a JWT (authenticated/service_role RPC paths keep their existing `auth.uid()` guards).
- Flutter consumers map `RewardType`/`RewardStatus` by `.name` (DB vocab), keeping enum drift
  visible at parse time; `benefitKind` renders benefit labels l10n-driven.

## ADR-062: Phase 2.4 architecture — notification delivery layer (send path, token lifecycle, deep-links)

**Date:** Session 52 (2026-08-16)
**Status:** Proposed (plan `34_PHASE_2_4_IMPLEMENTATION_PLAN.md` awaiting owner approval; recorded now
because the plan locks genuinely new architectural decisions)
**Deciders:** Lead Architect (implementation under owner's Session-52 7-phase authorization permit)

### Context
Phase 2.4 must add server-side push (FCM), a device-scoped token lifecycle, realtime-first delivery,
a production Notification Center, and safe deep-links. Inspection (live project
`bttnlkmwhorjamzemwda` + repo) verified: `notifications` + `notification_tokens` are fully reusable
(no parallel system), `notifications` is already in `supabase_realtime`, `pg_net` is installed live,
`supabase/functions/` is empty, and **no FCM credentials exist anywhere** (no service-account JSON,
no server key, no secrets). No Edge Functions or FCM send path exist today. Existing writers (033
chat routing, 038 rewards, 040 campaigns, 019 broadcast) insert `notifications` rows directly and
MUST NOT be edited (applied migrations are immutable).

### Decision
- **Reuse, don't rebuild:** `notifications` + `notification_tokens` remain the single source of
  truth. Migration **041** is purely additive (columns `priority/sender_id/send_push/push_status/
  push_sent_at/push_error`; allowlist table `notification_destinations`; no policy widenings).
- **Server send path:** `AFTER INSERT` trigger on `notifications` (SECURITY DEFINER) calls
  `pg_net.net.http_post` → Edge Function **`send-push`** (new, `supabase/functions/send-push`) →
  FCM HTTP v1 (`projects/delwaqty0/messages:send`). **Credential-ready + graceful no-op:** without
  FCM secrets the function marks `push_status='unconfigured'` and returns; realtime still delivers
  in-app. Operator backstop RPC `dispatch_push` re-enqueues failed/unconfigured sends.
- **Device-scoped token lifecycle RPCs:** `register_device_token`, `deactivate_device_tokens`
  (logout = this device only, replacing the current deactivate-ALL), `refresh_token_heartbeat`,
  `cleanup_invalid_token` (FCM 404/410). All SECURITY DEFINER + pinned `search_path`; token RPCs
  `authenticated`, cleanup `service_role`.
- **Realtime-first client:** reuse existing `in-app-notifications` channel via a centralized channel
  registry; unread badge/live list driven by realtime events with periodic reconcile (replaces
  1-min polling); reconnect + duplicate guards; auth-gated subscribe/unsubscribe (fixes the
  `_initialized` re-login bug).
- **Controlled deep-links:** server `notification_destinations` allowlist + `validate_...` RPC;
  client resolver rewrites `NotificationPayload.resolveDeepLink` to only push known routes, falling
  back to `/notifications`; new read-only `/campaign/:id` landing (040's `deep_link` today hits the
  router error page).
- **Stable type vocabulary:** NO new `NotificationType` enum values (keeps 13 + exhaustive-switch
  tests intact); server strings `chat_assigned/chat_escalated→message`, `emergency→security`,
  `complaint→system`, `admin→account` mapped in the data source.
- **Notification sources:** new triggers notify chat replies (support chat), complaint status,
  SOS emergency (priority high; informational — never an authz bypass), while 019/033/038/040 rows
  gain push automatically via the same insert trigger with zero writer edits.
- **Security hardening in 041:** `get_unread_notification_count` gains `search_path` + self/admin
  authz (was any-user info leak); `deactivate_stale_tokens` gains `search_path`; a
  `guard_notifications_user_update` trigger blocks users from rewriting own-row content (read-state
  only). No FCM/PAT credentials are ever stored in code or repo.

### Rationale
- A trigger is the only non-invasive integration point that captures inserts from every existing
  writer without editing applied migrations; `pg_net` (verified live) makes it fire-and-forget.
- FCM credential absence is an operational fact; the design must ship green today and go live with
  keys later with **zero code change** (secrets only).
- Device-scoped lifecycle prevents logout on one phone killing notifications on another and matches
  the real FCM token-per-install model.
- Deep-link allowlisting closes the current arbitrary-route navigation gap while remaining additive
  and compatible with existing stored `deep_link` values.

### Consequences
- Phase 2.4 ships without a real FCM delivery proof until the owner supplies credentials; the gate
  records push to the `unconfigured` boundary and marks physical-device verification PENDING.
- 030–040 migration files are untouched; 041 is the only new migration (next number verified).
- Client Notification Center gains pagination/l10n/priority visuals without enum churn.
- Emergency notifications remain informational (rows + push); admin access stays RLS-gated; the
  Phase 2.5 command center is NOT started.

---

## ADR-063: Profile + registration completion (DOB privacy, role CHECK, language persistence)

**Date:** 2026-08-17
**Status:** Accepted
**Deciders:** Lead Architect (STEPS 9-10 directive)

### Context
Step 11 (profile + registration: customer/provider/driver) exposed three latent gaps from the
earlier split-screen signup work:
1. **users.user_type CHECK** (migration 020) only allowed `customer/provider/delivery`, but the
   register wizard and `UserType` enum register `merchant` and `driver`. Every such sign-up
   violated the CHECK on insert - registration for two advertised roles was structurally impossible.
2. **Registration language preference** was collected in the 4-step wizard (step 2: ar/en) but
   dropped: `handle_new_user()` hardcoded `language=en` and the client-side `_persistSignUpProfile`
   did the same. The whole checkout ignored the user choice.
3. **DOB privacy + editing:** `users.date_of_birth` + `update_member_dob` RPC + guard trigger
   existed (migration 035) but no Flutter code read, wrote, or showed it; the admin verification
   queue excluded `merchant`/`driver`; and a rejected user was trapped on the pending-verification
   screen with no rejected state.

### Decision
- **Migration 046** (additive/idempotent, applied live): widen `users_user_type_check` to
  `(customer,merchant,driver,provider,delivery)` and teach `handle_new_user()` to read
  `language` from `raw_user_meta_data` (default `en`). No new tables or RPCs; no ACL surface change.
- **DOB flows through the sanctioned RPC only.** The client adds `updateDateOfBirth` on the profile
  DS/repo/usecase that calls `update_member_dob(p_date_of_birth, p_member_id)`; `date_of_birth` is
  deliberately exclud from `toInsertJson`/`toUpdateJson` because the guard trigger in 035 rejects
  direct writes by `authenticated`/`anon`.
- **DOB never shown raw in rewards text.** Rewards render only a derived year (already true) and the
  profile edit dialog shows a date picker with an explicit privacy note (l10n `dateOfBirthPrivacy`).
- **Registration language end-to-end:** register page -> AuthStateNotifier.signUp(language)
  -> SignUpUseCase -> AuthRepository.signUpWithEmail -> `_auth.signUp(data.language)` + trigger path
  -> `users.language`. Client-side `_persistSignUpProfile` now uses the passed language instead of
  the hardcoded `en`.
- **Verification integration:** admin verification queue widened to include `merchant`/`driver`;
  the pending-verification page gains `_buildRejected` when `verificationStatus.isRejected`.

### Rationale
- The CHECK fix is the minimal change that makes the advertised role flows real; the trigger change
  reuses the existing metadata contract so both the email-confirmation and session paths persist the
  same preference.
- Routing DOB through the RPC preserves the single-writer invariant from 035 (no second write path,
  no RLS loosening on `users`).
- Privacy is enforced at the UI contract level (year-only in rewards) AND at the write path (RPC
  with future/range validation live-verified).
- Admin queue + rejected state make the merge of role registration and verification observable and
  actionable by admins.

### Consequences
- Merchant/driver sign-up now succeeds end-to-end; language preference survives both registration
  paths.
- DOB is stored, editable by owner, and never leaks into reward text.
- Mixed-role verification queue + explicit rejected screen reduce stuck-user UX.
- 045/046 migrations are additive; 020/035 untouched. Flutter git diff clean; `flutter test` 868/868.

---

## ADR-064: Keep Android wireless debugging alive for the whole coding session

**Date:** Session 52E (2026-08-17)
**Status:** Accepted
**Deciders:** Lead Architect (tooling/infra; no product code touched)

### Context
The DNP NX9 (HONOR, MagicOS) doubles as both the dev machine (Termux PRoot running Flutter/OpenCode)
and the target device. `flutter run`/`adb install` relies on **adb over Wi-Fi (wireless debugging)**.
During long sessions the connection silently dies: `adb devices` shows stale `offline` transports and
`flutter devices` loses the Android target, so hot reload / APK install breaks.

### Root-cause investigation (all on-device)
- **`adb_wifi_enabled=1`** — Wireless debugging toggle is ON; not a user toggle problem.
- **Dynamic port:** MagicOS/adbd picks a NEW random listening port on every "Wireless debugging"
  toggle or adbd restart (observed ports 46121/38411/62110/39531/36923/39775). The previously saved
  `adb connect IP:OLD_PORT` silently goes stale — this is the primary drop mechanism.
- **adbd never auto-registers via mDNS** in this PRoot (`adb mdns services` is empty), so the adb
  server cannot rediscover the new port by itself; it keeps stale `offline` entries for dead ports.
- **adb server self-connection:** an earlier `adb connect 127.0.0.1:5037` (the adb server port itself)
  produced a bogus `offline` entry; harmless but noise.
- **MagicOS PowerGenius / smart battery** can suspend the Wi-Fi transport when the screen is off.
  `stay_on_while_plugged_in=0` and no doze whitelist were set. `com.termux` was NOT frozen (it is in
  `mNeverOptimizeApps` + `mStandbyProtectedApps`), but the Wi-Fi-sleep/battery knobs were wrong.
- SELinux `auditd` denials for uid 10526 are the PRoot app trying to reach `adbd`/`wifi` services
  directly — NOT the cause of drops; shell access via Shizuku/rish (uid 2000) is the correct path.

### Decision
1. **New helper `tool/opencode/keep_adb_alive.sh`** — background loop (default 20s) that:
   - Re-asserts Android knobs each pass via Shizuku/rish (shell uid): `stay_on_while_plugged_in=7`,
     `wifi_sleep_policy=2`, `adb_wifi_enabled=1`, doze-whitelist + RUN_IN_BACKGROUND for `com.termux`.
   - If no healthy transport: rediscover the CURRENT wireless-debugging port by `adb connect`-scanning
     the phone IP's known ports, keep only the `device` one, prune stale `offline` transports.
   - Never `kill-server` while a healthy transport exists (protects the live connection).
2. **Auto-start hook in `opencode-omniroute-start`** — idempotent background launch of the keepalive
   whenever OpenCode boots, matching the existing non-blocking style of that helper.

### Rationale
- The root cause is infrastructural (dynamic port + no mDNS + battery policy), not a Flutter bug;
  a keepalive is the smallest, robust fix that works under the PRoot constraints.
- Re-asserting settings every pass defeats MagicOS background policies without needing root/Magisk.
- Hook placement reuses the proven idempotent/non-fatal startup chain (`opencode-launch` ->
  `opencode-omniroute-start` -> `opencode`).

### Consequences
- `flutter devices` again lists `DNP NX9 (mobile) • <ip>:<port> • android-arm64 • Android 16 (API 36)`.
- The keepalive must run for the session; it auto-starts with OpenCode and can also be run manually
  (`tool/opencode/keep_adb_alive.sh once|loop`).
- No product code, migrations, or dependencies changed; gate unaffected.

## ADR-065: Allowlisted deep-link classification layer for `io.delwaqty://`

**Date:** Session 52G (2026-08-17)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
Email-confirm / OAuth returns hit `io.delwaqty://login-callback`. supabase_flutter already owns the
PKCE auth-callback exchange (`code`/`access_token`) on its own `AppLinks` subscription, and the router
redirect already lands users on the correct page after the auth listener fires. There was no app-level
allowlisted classification of inbound URIs, so any deep link was implicitly trusted and there was no
testable hook point.

### Decision
1. **`DeepLinkResolver`** (pure) — classify `io.delwaqty://...` URIs; only `login-callback` host maps to
   `DeepLinkRoute.loginCallback`; unknown hosts / foreign schemes → `null` (allowlist, never trust).
2. **`DeepLinkService`** — wraps `app_links` 7.2.1 (now a direct dependency) exposing:
   - `routes` broadcast stream of classified inbound routes,
   - `initialRoute` (cold-start, via `getInitialLink()`),
   - injectable `overrideStream` for tests.
3. **`app.dart`** starts the service and, on `loginCallback`, triggers `checkAuthStatus()` as a cheap,
   idempotent safety net after the SDK exchange (auth listener already handles the normal path).

### Rationale
- The SDK + router ownership means a full routing table in Dart would duplicate functionality; the
  service stays a thin, allowlisted observer with an explicit in-app safety net.
- A pure resolver is trivially testable; the service stream override makes provider wiring testable.

### Consequences
- Deep links are classified by an allowlist; unknown hosts are ignored (no navigation side effects).
- `app_links` moved from transitive (under supabase_flutter) to a direct dependency in `pubspec.yaml`.
- Backend auth `site_url`/`uri_allow_list` already permit `io.delwaqty://login-callback` (ADR-040);
  `AndroidManifest.xml` intent filter unchanged (already present, lines 37–42).

## ADR-066: Rejected-verification re-apply through SECURITY DEFINER RPCs (migration 047)

**Date:** Session 52G (2026-08-17)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
Rejected members had no path back: `verification_status` was writable via raw authenticated UPDATE
(`users_update_admin` RLS / admin repo `/users.update`), `approval_requests` was not wired to
verification, `notification_destinations` lacked a verification route, and no reject reason was stored.

### Decision
Migration `047_verification_reapply.sql` (applied live):
1. **`users.rejection_reason` + `users.rejection_reason_at`** columns store the admin's reject reason.
2. **`reapply_verification(p_id_card_url, p_profile_photo_url)`** — SECURITY DEFINER; caller must own the
   row, current status must be `rejected`; sets `pending`, clears reason, writes docs, inserts a
   notification (`send_push=false`, idempotency key) and audit `VERIFICATION_REAPPLIED`.
3. **`decide_user_verification(p_user_id, p_decision, p_reason)`** — SECURITY DEFINER; `is_admin()`
   required, reject mandates a reason; sets status + reason/at, notifies (`send_push=true`,
   approve → `/profile`, reject → `/pending-verification`), audit `VERIFICATION_DECIDED`.
4. **`users_guard_account_fields` extended** — authenticated/anon direct `verification_status` writes now
   raise `'Verification status is managed by the verification RPCs'` (admin repository switched to the
   RPCs; raw `/users.update` no longer works).

### Rationale
- Centralized status transitions with guardrails (state machine, required reason, audit, notification)
  replace ad-hoc admin UPDATEs and the (unreachable-for-reapply) approval_requests path.
- SECURITY DEFINER + ownership check keeps it safe for members while admins retain `is_admin()` gating.
- Reject reason flows member-facing (re-apply page) and admin-facing (reason prompt + display).

### Consequences
- Rejected members see the admin reason and can re-apply with new documents (pending gate resumes).
- Admin approve/reject now goes through `decide_user_verification` in `admin_repository.dart`;
  `rejectVerification` requires a `reason` (UI prompts for it).
- `User`/`UserModel` gained `rejectionReason`; profile repository gained `reapplyVerification`.

---

## ADR-067: Escalation engine — ledger, strict-upward routing, marker-based server-origin guards (migration 048)

**Date:** Session 53 (2026-08-18, STEP 13 / Phase 2.5)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
Complaints had no escalation path: no ledger of escalation hops, no region-aware admin escalation
tiering, and `status` could be forced to `'escalated'` by raw UPDATEs. The routing requirement was:
scoped admin → parent/nearest ancestor region admin → global admin → owner queue, with priority/status
never decreasing and assignment fields unspoofable by clients.

### Decision
Migration `048_escalation_engine.sql` (applied live, idempotent, rerun-clean):
1. **`escalation_events` table** (entity_type/entity_id, from/to admin, actor, reason, previous/new scope)
   + index `(entity_type, entity_id)` + RLS + revokes/grants (anon/authenticated denied on read).
2. **`complaints` ALTER**: `assigned_admin_id`, `escalated_at`, `escalated_from_admin_id`.
3. **`escalate_complaint` / `assign_complaint` / `get_escalation_events`** SECURITY DEFINER RPCs
   (016 pattern, `search_path` pinned, revoke-then-grant). `escalate_complaint` routes **strictly upward**:
   unassigned → best regional admin (`resolve_support_admin(v_region, true, NULL)`), scoped → global tier
   (`resolve_support_admin(v_region, false, v_current)`), global → **owner queue** (terminal, `to_admin_id=NULL`);
   an owner-queue event short-circuits further escalations (early RETURN).
4. **Marker-based server-origin proof**: RPCs set `set_config('app.escalation_rpc', 'true', true)` /
   `app.notify_dispatch` (transaction-local). `complaints_fixup_insert` / `complaints_fixup_update` and
   `guard_notifications_user_update` trust marker → `auth.uid() IS NULL` → `is_admin()` before forcing
   safe defaults (insert) or restoring OLD values (non-admin update); admins bypass for legitimate direct
   edits except `status→'escalated'` and assignment fields, which RAISE "must be escalated via escalate_complaint()".
5. **Trigger isolation verified live** — probe suite runs with
   `ALTER TABLE public.notifications DISABLE TRIGGER notify_notification_push` + `GRANT ALL ON pg_temp`
   (SET ROLE probes cannot touch superuser temp tables otherwise).

### Rationale
- `session_user`/`current_user` **cannot** distinguish server origin under PostgREST: `session_user`
  is always `authenticator` and differs from the PostgREST-set `current_user`, so the discriminator was
  observably bypassable (a forged customer `status='escalated'` POST returned 201 before the fix).
  `set_config` with `is_local=true` is not settable by PostgREST table CRUD, so it is the unspoofable proof.
- Strict-upward routing + owner-queue terminal prevents both downgrades and the R1↔G escalation cycle
  observed in multi-hop probes, and gives the owner a deterministic final queue.
- Ledger-first design makes routing auditable (`get_escalation_events`) and is reusable for other entities
  (`entity_type`).

### Consequences
- `flutter analyze` 0 errors/warnings on touched files; escalation + complaints targeted suites green.
- Complaint escalate from the admin UI now routes through `escalate_complaint` (RPC); direct
  `updateComplaintStatus('escalated')` throws a descriptive `ServerException`.
- New `lib/features/escalation/` module (entity, repository, data source, impl, providers, admin queue page)
  registered in `module_registry.dart`; `/admin/escalations` route; l10n en+ar keys.
- Probe leave-behinds in the dev project must be cleaned by T* probe fixtures (temp admins/customers).

## ADR-068: Admin Command Center normalization & navigation rebuild (STEP 18, sprint 84)

**Date:** Session 57 (2026-08-18, STEP 18 / Phase 2.8)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
A full audit of the admin platform (STEP_18_ADMIN_COMMAND_CENTER_AUDIT.md) found 9 integration bugs:
(1) admin quick actions used `context.go(/admin/...)` so Android Back could exit the app; (2) the member
drawer read `profile[basic]`/`region.hierarchical_label`/`can_decide_verification` but `get_member_ops_profile`
(049) returns `member`/`region.label`/`can_view_*`; (3) `/admin/members/:id` was a dangling push with no
GoRoute; (4) `/admin/escalations` was registered twice; (5) the sidebar reached only 6 of 25 admin routes;
(6) a hardcoded non-localized `Members` label; (9) the notification center deep-link never passed `isAdmin`.
Live verification also exposed a runtime crash: `Member.fromJson` cast JSON `List<dynamic>` -> `List<String>`,
blanking the member list even though `member_ops_list` returns 17 rows.

### Decision
1. **Drawer normalization layer** — `normalizeMemberOpsProfile()` converts the 049 RPC shape (`member`,
   `region.label`, `can_view_location`/`can_view_chat`/`can_view_documents`/`can_moderate`) to the drawer
   vocabulary at the boundary; widgets stay untouched. The intra-module schema mismatch is resolved at the
   adapter the same way the cross-module normalization layer does elsewhere.
2. **Router fixes** — quick actions `go`->`push`; register `/admin/members/:id` -> `MemberDetailPage`;
   drop the duplicate `/admin/escalations` from `AdminModule` (EscalationModule owns it).
3. **Sidebar rebuild** — new `CollapsibleSidebarSection`; admin menu grouped into 5 localized groups
   (العمليات/الدعم/المالية/التسويق/الإدارة المتقدمة) covering all 25 routes + new `/admin/emergency`.
4. **New `/admin/emergency`** — Emergency/SOS page reading `sos_alerts` (admin select policy, migration 033)
   + critical `platform_operational_alerts`, refreshed through `RealtimeService` on `RealtimeChannels.sosAlerts`.
5. **Member list crash fix** — safe `(json[...] as List<dynamic>?)?.cast<String>()`; notifier captures
   `lastError` for a retry UI. No backend change required.

### Rationale
The failures were connector bugs (route wiring, schema adapters, JSON casts), not platform gaps; the backend
was authoritative and correct (`member_ops_list` returns all rows under owner JWT). Fixing at the UI
boundary keeps server RLS/RPCs untouched while making every existing feature reachable from one surface.

### Consequences
- `dart analyze lib/` 0 errors/0 warnings; 139 targeted tests green (incl. a dynamic-array regression test).
- Verified on device: grouped Arabic sidebar, Command Center KPIs (real zeros/matches), Back returns in-app
  from admin pages, member list renders all 17 live users, member drawer renders on a live admin.
- Explicitly tracked as partial: platform-wide live-tracking stream still needs a server RPC + RLS policy;
  chat keeps its RLS-scoped `.stream()` (RealtimeService remains canonical for new channels).

---

## ADR-069: Admin backend hardening — approvals dispatcher, commission rules, deletion confirmation, approval listing (migrations 052-054, sprint 85)

**Date:** Session 58 (2026-08-19, STEP 18 / Phase 2.9)
**Status:** Accepted
**Deciders:** Lead Architect

### Context
Sprint-84 rebuilt the admin UI but left backend gaps: (A) `decide_approval_request` (040:354) had regressed
to campaign-only, so owners could never decide admin/member/offer approvals; (B) `050` analytics hardcoded
`commission_rate = 7/3` instead of consulting `commission_rules`; (C) `get_admin_analytics` (029) was not
SECURITY DEFINER, carried no gate, yet was granted to `authenticated`; (D) the member drawer called a
nonexistent `delete_user_account` (real RPC is `delete_member_account`, 035:631) with no confirmation;
(E) there was no browsable approval queue for a future Approvals Center; (F) Admin Settings shipped a fake
"Reset All Data" Danger Zone dialog with no backing RPC or permission.

### Decision
1. **052 — Restore the full approval dispatcher.** `decide_approval_request` now applies authority guards
   and routes every type (admin_*, member_ban, member_delete, campaign_approve, reward_config_change) through
   `_approval_apply`. Owner bypass remains; non-owners are rejected.
2. **052 — Real commission management.** New `set_commission_rate` (PLATFORM_REVENUE-gated, keeps versioned
   history in `commission_rules`, writes `COMMISSION_RATE_CHANGED` audit) and `list_commission_rules`.
   `get_commission_rate` returns the effective-dated, most-specific rule. All three `050` analytics functions
   were recreated to derive buckets via service_role-only `_commission_bucket_amount`.
3. **052 — Harden `get_admin_analytics`** with SECURITY DEFINER + `is_admin()` gate + locked `search_path`.
4. **053 — Deletion confirmation.** `request_member_deletion(p_member_id, p_confirmation_email, p_reason)`
   validates the admin-typed email against the member email, computes `DELETE-<sha256>` server-side, and opens
   a `member_delete` approval that executes through `delete_member_account`.
5. **054 — Approval listing.** `list_approval_requests(p_state, p_limit)` returns `{"requests":[...]}` to
   admins, powering the new Approvals Center.
6. **AdminShell + independent admin locale.** Every `/admin` route is wrapped in `AdminShell`
   (Localizations.override + Directionality + grouped rail/drawer). `admin_locale` (default Arabic, persisted,
   live switch) decouples the admin UI language from the app language.
7. **UI: remove catastrophic surface.** Danger Zone deleted; delete flow now uses `request_member_deletion`;
   restrict/suspend use `issue_sanction`. Sidebar collapsed to a single app-level admin entry with the full
   grouped navigation inside the shell.
8. **Tooling reality.** `apply.py` auto-commits every statement; `set_config('request.jwt.claims')` is
   batch-transaction-local, so owner-simulation fixtures must share one batch with their assertions.

### Rationale
Server-side gaps (hardcoded rates, a broken decision dispatcher, an ungated admin RPC) are authoritative
bugs — a UI could not mask them. Migrations keep RLS/authorization server-authoritative while the UI only
gets data it is permitted to see.

### Consequences
- All four migrations applied live (HTTP 201) and probed: non-campaign decisions execute under owner;
  commission rates round-trip (provider 7.00/merchant 3.00/driver 7.00/customer 0.00/restaurant 3.00);
  non-admin `get_admin_analytics` -> `P0001: Not authorized`; typed-email deletion verified end-to-end with a
  fixture (deactivated + anonymized), then cleaned up.
- New pages `/admin/commissions` and `/admin/approvals`; `member_management_module_test` updated for the
  single-entry sidebar; 77/77 admin+member tests green; touched areas analyze clean (0 errors/warnings).
- Useful mental model for future migrations: no owner session persists across `apply.py` batches.
