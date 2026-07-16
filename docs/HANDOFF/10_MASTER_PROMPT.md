# Delwaqty - Master Prompt for OpenCode Desktop

**Use this prompt to continue development in OpenCode Desktop.**

---

You are working on **Delwaqty**, a Global Super Platform built with Flutter. This is a "Service Operating System" where every service (commerce, delivery, payments, maps, AI) is a plug-in on a shared platform kernel.

## Tech Stack

- **Flutter:** ^3.12.2, Dart ^3.12.2
- **State:** Riverpod (^2.5.1)
- **Routing:** GoRouter (^14.0.2)
- **Models:** Freezed + JSON Serializable
- **Backend:** Supabase (PostgreSQL, Auth, Storage, Realtime)
- **Notifications:** Firebase Cloud Messaging
- **Maps:** Google Maps Flutter
- **Storage:** Cloudflare R2 + CDN
- **Testing:** mocktail, 443 tests

## Architecture

Clean Architecture (Domain/Data/Presentation) with feature-first organization. SOLID principles. Arabic RTL + English localization.

## Module System

Every feature extends `FeatureModule` abstract class → registered in `FeatureRegistry` → `AppShell` builds navigation dynamically.

13 registered modules: admin, auth, categories, commerce, expenses, home, notifications, onboarding, profile, reports, settings, splash, welcome.

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point |
| `lib/module_registry.dart` | Module registration |
| `lib/app/app.dart` | MaterialApp config |
| `lib/core/router/app_router.dart` | Routes |
| `lib/config/platform_config.dart` | Service readiness |
| `supabase/migrations/001_initial_schema.sql` | Database schema |

## Database

15 tables: users, admin_users, merchants, products, categories, orders, order_items, reviews, favorites, drivers, coupons, notifications, activity_logs, platform_settings.

**STATUS: Schema defined but NOT yet deployed.** Must run SQL in Supabase Dashboard.

## Current State

- All architecture complete
- All sprints 1-11 done
- All 443 tests passing
- Mock repositories in use (need Supabase implementations)
- Admin backend connected to Supabase REST API
- Firebase, Maps, Cloudflare configured but not connected (no credentials)

## Immediate Tasks

1. Deploy database schema (run SQL migration)
2. Connect repositories to real Supabase
3. Wire authentication flow
4. Add Firebase credentials
5. Add Google Maps API key
6. Populate assets (images, fonts, icons)

## Coding Standards

- No comments unless requested
- Prefer single quotes
- Require trailing commas
- Use Freezed for immutable models
- Use Riverpod for state management
- Test everything with mocktail
- Clean Architecture: Domain layer has no framework imports
