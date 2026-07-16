# PROJECT_CONSTITUTION.md — Delwaqty

> **Version 2.0 — Adopted 2026-07-16**
> **This document is the highest-level project authority.**
> **It overrides all temporary prompts.**
> **Every AI agent and contributor MUST follow these principles permanently.**

---

## 1. MISSION

Delwaqty is NOT a Flutter application.

Delwaqty is a **Global Super Platform**.

Its purpose is to become the **operating system for everyday life**.

Every architecture decision must support long-term scalability.

Never optimize for short-term speed at the expense of long-term quality.

---

## 2. PROJECT VISION

One application. Unlimited services. Everyday needs.

| Domain | Services |
|--------|----------|
| **Food** | Restaurants, Food Delivery |
| **Commerce** | Marketplace, Buy & Sell, Electronics, Fashion, Furniture, Groceries, Pharmacy |
| **Mobility** | Ride Hailing, Taxi, Courier |
| **Services** | Cleaning, Laundry, Plumbing, Electricity, Air Conditioning, Pest Control |
| **Travel** | Hotels, Travel Booking |
| **Health** | Medical Appointments, Pharmacy |
| **Finance** | Wallet, Payments, Bills, QR, Subscriptions |
| **Engagement** | Offers, Coupons |
| **Intelligence** | AI Assistant |

Everything must live inside **one ecosystem**.

---

## 3. ABSOLUTE PROJECT RULES

| Rule | Description |
|------|-------------|
| No intentional technical debt | Never introduce debt knowingly |
| No bypassing abstraction layers | Always go through the proper layers |
| No hardcoded providers | Use dependency injection |
| No hardcoded business logic | Logic belongs in domain/data layers |
| No duplicate repositories | One repository per domain entity |
| No duplicate services | One service per capability |
| No duplicate models | One model per entity |
| No duplicate widgets | Shared widgets in `lib/shared/` |
| No dead code | Delete obsolete implementations immediately |
| Measure before optimizing | Profile first, optimize second |
| Architecture > Speed | Quality has higher priority than development speed |

---

## 4. ARCHITECTURE — PLATFORM KERNEL

Delwaqty is NOT a collection of applications. Delwaqty is a **Platform**.

Every business feature must run on top of one shared **Platform Core**.

No feature may bypass the Platform Core.

Maintain these principles at all times:

- **Platform Kernel** — Logical core owning all cross-cutting capabilities
- **Engine Architecture** — Reusable engines for each domain capability
- **Plugin System** — Business features as Plugins communicating only through Platform APIs
- **Clean Architecture** — Domain / Data / Presentation layers within each Engine and Plugin
- **SOLID** — Single responsibility, open-closed, Liskov substitution, interface segregation, dependency inversion
- **Feature-first** — Code organized by feature, not by type
- **Riverpod Dependency Injection** — All dependencies injected via providers
- **Repository Pattern** — Abstract interfaces in domain, implementations in data
- **Service Layer** — Platform services behind abstract interfaces

**Architectural Rules:**

- No Plugin may bypass the Platform Kernel
- No Plugin may directly call another Plugin
- All cross-plugin communication must happen through Platform Services, Events, or Public Interfaces
- Every Engine must define: Responsibilities, Public API, Events, Dependencies, Extension Points

Every module must be independently testable.
Every module must register automatically.
Every service must register automatically.

Full architecture documentation lives in `architecture/`.

---

## 5. DOMAIN RULE

Never implement a feature before designing its domain.

Every major feature must first be documented.

The domain model is the contract.

Implementation follows the domain — not the opposite.

---

## 6. DOCUMENTATION

Documentation is mandatory. Documentation is source code. Documentation must never lag behind implementation.

Always maintain:

| Document | Location | Purpose |
|----------|----------|---------|
| PROJECT_CONSTITUTION.md | Project root | Highest-level authority (this document) |
| SESSION_STATUS.md | Project root | Live task tracker |
| AGENTS.md | Project root | AI agent rules |
| ROADMAP.md | Project root | Feature roadmap |
| architecture/ | Project root | Platform Kernel architecture docs |
| docs/DECISION_LOG.md | docs/ | Architecture Decision Records |
| docs/PROJECT_HEALTH.md | docs/ | Project health metrics |
| docs/PRODUCTION_STATUS.md | docs/ | Production readiness |
| docs/MIGRATION_REPORT.md | docs/ | Migration tracking |
| docs/HANDOFF/ | docs/ | Sprint handoff documents |

Whenever architecture changes: **update documentation first**.

---

## 7. AGENT RULES

Maintain `AGENTS.md` at the project root.

Every future AI agent must understand:

- Architecture
- Coding standards
- Workflow
- Quality requirements
- Git workflow
- Project philosophy

...without needing previous conversations.

---

## 8. QUALITY GATE

No commit is allowed until ALL of the following pass:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk
```

If an Android device is available:

```bash
flutter run
```

Every failure must be fixed before commit.

---

## 9. GIT POLICY

| Rule | Value |
|------|-------|
| GitHub Account | `https://github.com/delwaqtyapp` |
| Repository | `https://github.com/delwaqtyapp/delwaqty.git` |
| Git User | `delwaqtyapp <admin@delwaqty.com>` |
| Auth Method | Git Credential Manager (HTTPS) |
| Branch | `master` |

- Never ask which GitHub account to use.
- Never switch repository owners.
- Never change remotes.
- Never rewrite history without explicit approval.
- Commit frequently.
- Push stable milestones.

---

## 10. SECURITY POLICY

- Never expose secrets.
- Never commit API keys.
- Never commit passwords.
- Never commit service tokens.
- Use environment variables.
- Use Secret Managers where possible.

---

## 11. AI POLICY

The AI is part of the platform. The AI is not a chatbot. The AI is a platform capability.

Support future providers:

- OpenAI
- Gemini
- Claude
- Local LLM
- Future providers

Never couple business logic to one AI provider.

---

## 12. PLATFORM SERVICES

Each platform capability must remain reusable:

- Authentication
- Maps
- Payments
- Commerce
- Notifications
- Search
- Storage
- Location
- Wallet
- AI
- Logging
- Analytics
- Performance

---

## 13. OBSERVABILITY

Continue improving:

- Logging
- Analytics
- Crash Reporting
- Performance Monitoring
- Health Monitoring
- Error Tracking
- Retry Strategies

---

## 14. PRODUCTION RULE

No mock implementation may survive once the production implementation is verified.

Delete obsolete mocks immediately.

---

## 15. NEXT DEVELOPMENT ORDER

Do NOT randomly choose features. Follow this order:

1. Platform Kernel Documentation
2. Platform Engine Specifications
3. Commerce Core
4. Merchant Platform
5. Branch Management
6. Catalog Management
7. Inventory
8. Pricing Engine
9. Orders
10. Restaurant Plugin
11. Restaurant Administration
12. Customer Ordering
13. Driver Platform
14. Dispatch Platform
15. Marketplace Plugin
16. Ride Plugin
17. Home Services Plugin
18. Wallet
19. Payments
20. Subscriptions
21. AI Assistant

---

## 16. OWNER INTERACTION

When external action is required:

- Do not simply request credentials.
- Become an interactive technical guide.
- Explain step-by-step.
- Provide official links.
- Explain why.
- Explain expected results.
- Explain what you will do automatically after completion.
- Explain everything in English and Arabic.
- Guide one cloud provider at a time.

---

## 17. AUTONOMOUS MODE

Work autonomously. Only stop when:

- Business decision required
- Legal decision required
- Billing activation required
- Cloud credential required

Otherwise continue.

---

## 18. LONG TERM OBJECTIVE

The objective is NOT shipping another mobile application.

The objective is building one of the world's most scalable, maintainable and production-ready Super Platforms.

Every decision from this point forward must move Delwaqty toward that objective.

---

## 19. PLATFORM KERNEL ARCHITECTURE

The Platform Kernel is the logical core of Delwaqty. It is NOT an operating system kernel. It is the architectural foundation that every feature runs on top of.

**Core Principle:** Every business feature must run on top of one shared Platform Core. No feature may bypass the Platform Core.

Full specifications live in `architecture/`:
- `architecture/KERNEL.md` — Kernel architecture
- `architecture/ENGINES.md` — Engine catalog
- `architecture/PLUGIN_SYSTEM.md` — Plugin architecture
- `architecture/ENGINE_INTERFACES.md` — Engine public APIs
- `architecture/DEPENDENCY_RULES.md` — Dependency rules
- `architecture/EVENT_ARCHITECTURE.md` — Event system
- `architecture/PLATFORM_SERVICES.md` — Platform services

---

## 20. PLATFORM ENGINES

The Platform Kernel is organized around reusable Engines. Each Engine owns a cross-cutting domain capability.

| Engine | Responsibility |
|--------|---------------|
| Identity Engine | Authentication, Authorization, Roles, Permissions, Profiles, Devices, Sessions |
| Commerce Engine | Merchants, Branches, Catalogs, Products, Variants, Modifiers, Inventory, Pricing, Taxes, Fees, Offers, Coupons, Orders |
| Marketplace Engine | Listings, Categories, Search, Favorites, Media, Messaging |
| Mobility Engine | Ride Hailing, Drivers, Vehicles, Trips, Navigation, Tracking, Dispatch |
| Home Services Engine | Providers, Scheduling, Availability, Bookings, Technicians |
| Payments Engine | Wallet, Cards, Cash, QR, Invoices, Refunds, Installments |
| Notifications Engine | Push, SMS, Email, WhatsApp, In-App, Templates, Campaigns |
| Maps Engine | Location, Places, Routes, Navigation, Tracking, Geocoding |
| Search Engine | Nearby Search, Global Search, Recommendations, Ranking, Filtering |
| Analytics Engine | Events, Metrics, Dashboards, Funnels, Reporting |
| Logging Engine | Application Logs, Audit Logs, Security Logs, Monitoring |
| AI Engine | Recommendations, Predictions, Context Awareness, Natural Language, Provider Abstraction |
| Storage Engine | Media, Documents, Images, CDN, Caching, Synchronization |

---

## 21. PLUGIN SYSTEM

Every business capability becomes a Plugin. Plugins communicate only through Platform APIs.

**Plugin Examples:** Restaurant, Pharmacy, Grocery, Marketplace, Cars, Furniture, Electronics, Home Services, Laundry, Cleaning, Ride, Courier, Travel, Hotels, Medical, Bills, Wallet.

**Plugin Rules:**
- No Plugin may bypass the Platform Kernel
- No Plugin may directly call another Plugin
- All communication must happen through Platform Services, Events, or Public Interfaces
- Every Plugin must define: Capabilities, Required Engines, Optional Engines, Permissions, Navigation, Storage, Events, Background Tasks, Dependencies

---

## 22. IMPLEMENTATION RULE

Do NOT refactor the existing codebase immediately.

First: Design the Platform Kernel. Design every Engine. Document every responsibility. Document every public interface. Document dependencies.

Only after the documentation is approved should implementation begin.

Migration strategy: Do NOT rewrite working code. Document first. Refactor only when necessary. Keep production stable.
