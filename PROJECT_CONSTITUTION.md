# PROJECT_CONSTITUTION.md — Delwaqty

> **Version 1.0 — Adopted 2026-07-16**
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

## 4. ARCHITECTURE

Maintain these principles at all times:

- **Clean Architecture** — Domain / Data / Presentation layers
- **SOLID** — Single responsibility, open-closed, Liskov substitution, interface segregation, dependency inversion
- **Feature-first** — Code organized by feature, not by type
- **Plugin Architecture** — Features register via `FeatureModule`
- **Riverpod Dependency Injection** — All dependencies injected via providers
- **Reusable Components** — Shared widgets in `lib/shared/`
- **Repository Pattern** — Abstract interfaces in domain, implementations in data
- **Service Layer** — Platform services behind abstract interfaces

Every module must be independently testable.
Every module must register automatically.
Every service must register automatically.

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

1. Finalize Commerce Domain Model
2. Merchant Platform
3. Restaurant Module
4. Restaurant Admin Portal
5. Customer Ordering Flow
6. Driver Platform
7. Dispatch System
8. Admin Platform
9. Marketplace
10. Ride Hailing
11. Home Services
12. Wallet
13. Payments
14. Subscriptions
15. AI Assistant

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
