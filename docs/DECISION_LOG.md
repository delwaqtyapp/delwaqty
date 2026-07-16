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
