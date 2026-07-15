# Delwaqty Vision

## What is Delwaqty?

Delwaqty is a **Platform Operating System (POS)** for everyday life — a super app designed to become the unified digital layer for Saudi Arabia and the MENA region.

The platform kernel is the real product. Every service — commerce, delivery, payments, AI, maps, search — is a plug-in module running on the same platform core. Individual services are replaceable. The kernel is permanent.

## Core Philosophy

> **Every service is a plugin. The platform kernel is the product.**

This means:

1. **The kernel is permanent.** The module system, routing, auth, theming, DI, and shared services never go away.
2. **Services are replaceable.** Any feature module can be removed, replaced, or reimagined without touching the core.
3. **Scale through composition.** New capabilities emerge by combining existing modules, not by rewriting core infrastructure.
4. **Ship fast, iterate faster.** The plugin architecture means a new feature is one `FeatureModule` class away.

## Platform Layers

### The Kernel (Core)

The platform kernel provides:

- **Module System** — FeatureModule plugin architecture with dependency resolution, lifecycle hooks, and route generation
- **Authentication** — Supabase-backed auth with secure token management
- **Theme System** — Material 3 design tokens, light/dark mode, semantic color palette
- **Routing** — GoRouter with auth guards, shell routes, deep link support
- **State Management** — Riverpod with provider overrides at the platform level
- **Design System** — Reusable widgets, spacing tokens, color tokens
- **Error Handling** — Typed exception hierarchy with Failure mapping
- **Localization** — Arabic/English with RTL support

### The Services (Plugins)

Each service is a self-contained module:

| Service | Status | Description |
|---------|--------|-------------|
| Commerce Engine | ✅ Built | Merchant-type agnostic marketplace for food, grocery, pharmacy, electronics, furniture, fashion |
| Auth & Identity | ✅ Built | Login, registration, password recovery, session management |
| Expenses | ✅ Built | Personal expense tracking with categories |
| Notifications | ✅ Built | In-app notification center with badge aggregation |
| Home & Dashboard | ✅ Built | Main navigation hub |
| Settings | ✅ Built | Theme, language, account management |
| Profile | ✅ Built | User profile management |
| Admin Panel | ✅ Built | Super admin dashboard, user/merchant/order management, platform settings |
| AI Core | Planned | LLM integration, smart search, recommendations, voice |
| Map Engine | Planned | Location services, geocoding, routing, delivery tracking |
| Search Engine | Planned | Full-text search across all modules, filters, suggestions |
| Payment Gateway | Planned | Multi-method payment processing, wallet, payouts |
| Delivery System | Planned | Driver management, route optimization, real-time tracking |
| Chat & Messaging | Planned | In-app messaging between users, merchants, drivers |

## Target Markets

### Primary: Saudi Arabia
- Arabic-first with full RTL support
- SAR currency native
- Saudi merchant types: restaurants (Al Baik, etc.), pharmacies (Nahdi), grocery (Tamimi), electronics (Jarir), furniture (IKEA), fashion
- Local payment methods (Mada, STC Pay, Apple Pay)
- Saudi phone number format validation

### Secondary: MENA Region
- Expandable to UAE, Bahrain, Kuwait, Qatar, Oman
- Multi-currency support
- Regional merchant types and categories

## Platform Principles

### 1. Kernel Over Features
Infrastructure investment always beats feature investment. A well-built module system scales infinitely. A single feature is disposable.

### 2. Type-Agnostic Commerce
The commerce engine doesn't know or care if a merchant is a restaurant, pharmacy, or electronics store. MerchantType is a data flag, not a code branch.

### 3. Mock-First Development
Every repository has a mock implementation. The app is fully functional without a backend. This enables parallel frontend/backend development.

### 4. Provider-Level Wiring
Repository overrides happen at the ProviderScope level in `main.dart`. Switching from mock to real backend requires changing one line.

### 5. Design Tokens Over Hardcoded Values
All colors, spacing, and typography flow through design tokens. The theme system is the single source of truth for visual identity.

### 6. Module Independence
Modules declare their dependencies via `dependsOn`. The registry resolves them topologically. No circular dependencies allowed.

### 7. Accessibility by Default
RTL support, semantic labels, proper contrast ratios, and responsive layouts are built in, not bolted on.

## Success Metrics

| Metric | Target |
|--------|--------|
| App startup time | < 2 seconds |
| Module load time | < 100ms per module |
| Test coverage | > 80% |
| Lint issues | 0 errors, 0 warnings |
| Localization coverage | 100% of user-facing strings |
| Platform kernel stability | Zero breaking changes to FeatureModule contract |
