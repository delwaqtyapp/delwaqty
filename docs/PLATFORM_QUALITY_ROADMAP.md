# Delwaqty Platform — Quality & Development Roadmap

> **Author:** Lead Software Architect (Round 95 / Sprint 220)
> **Scope:** Full-Platform Engineering, Architecture, UX, Security, & Testing Standards (Customer, Driver, Provider/Merchant, Admin, Web)

---

## Phase 1 — Architectural Purity & Decoupling (Zero Cross-Flavor Leaks)

1. **Decouple `features/customer/driver/` from Customer:**
   - Move `lib/features/customer/driver/` into `lib/features/driver/dispatch/` and extract shared entities (`RideOffer`, `DriverStats`, `DriverEarning`) into `lib/features/_shared/dispatch/`.
   - Goal: `features/driver/` must never depend on `features/customer/`.

2. **Decouple `features/admin/support_chat/` from Customer & Driver:**
   - Move customer/shared chat UI, call-alert service, and chat providers from `lib/features/admin/support_chat/` into `lib/features/_shared/support_chat/`.
   - Keep admin-only escalation/queue management in `lib/features/admin/`.

3. **Move `AdminComplaintsPage` out of `lib/features/_shared/`:**
   - Relocate `lib/features/_shared/complaints/presentation/pages/admin_complaints_page.dart` into `lib/features/admin/complaints/` so `_shared/` never imports `features/admin/escalation/`.

4. **Eliminate Presentation-Layer `Supabase.instance.client` Calls:**
   - Enforce a static contract test forbidding `Supabase.instance` inside any `**/presentation/**` file.
   - Route all remaining auth/export/OTP calls (`auth_provider.dart`, `whatsapp_otp_sheet.dart`, `data_privacy_page.dart`, `change_password_page.dart`) through domain repositories/usecases injected via Riverpod.

5. **Eliminate Legacy Riverpod Imports:**
   - Migrate remaining `package:flutter_riverpod/legacy.dart` (`StateProvider`, `StateNotifierProvider`) in `dispatch_providers.dart` and elsewhere to Riverpod 3 `NotifierProvider` / `AsyncNotifierProvider`.

---

## Phase 2 — Reliability, State Management & Error Resilience

1. **Replace Uncached `FutureBuilder`s with Riverpod `AsyncValue`:**
   - Convert remaining `FutureBuilder` pages (such as `merchant_detail_page.dart` and `product_detail_page.dart`) to `FutureProvider.family` / `AsyncNotifier` so state changes never re-trigger network fetches and `AsyncValue.when` uniformly handles `loading` / `error` (with retry) / `data`.

2. **Zero Silent Failures (`catch (_)`):**
   - Audit and replace all `catch (_) {}` blocks across `lib/` with structured `loggerProvider` logging and user-facing `appErrorText(context, e)` feedback where an action fails.

3. **Idempotent Financial & Booking Mutations:**
   - Ensure every wallet top-up, wallet payment, order placement, and service booking generates a single client-side `idempotencyKey` per user attempt and disables double-taps via an in-flight guard.

4. **Confirmations on All Destructive & Financial Actions:**
   - Enforce `ConfirmDialog.show` / `AlertDialog` for cart clearing, order cancellation, wallet top-up, service booking, biometric credential removal, and account deletion across all 4 flavors.

---

## Phase 3 — UI/UX, Accessibility, RTL/LTR & Performance

1. **100% Localization Parity & Sync Gate:**
   - Keep `app_en.arb` and `app_ar.arb` free of duplicate keys, synced with `app_localizations*.dart` via `flutter gen-l10n`, and enforce via `customer_app_contract_test.dart`.
   - Use locale-aware punctuation (`، ` vs `, `, `؟` vs `?`), `AlignmentDirectional`, `EdgeInsetsDirectional`, and `BackButtonIcon` across all pages.

2. **Responsive Overflow Protection:**
   - Replace wide `Row` action bars with `Wrap` or `Flexible`/`Expanded`, and test critical screens at `320px` and `1.3x` text scale.

3. **Eliminate N+1 Queries & Large-List Bottlenecks:**
   - Replace sequential `await` loops (such as favorites hydration) with `Future.wait` or single embedded PostgREST queries.
   - Add cursor/offset pagination ("Load More") to `WalletTransactionsPage`, `OrdersPage`, and `NotificationsPage`.

4. **Theme Token Discipline:**
   - Replace remaining hardcoded `Colors.white` / `Colors.black` / `Colors.red` / `Colors.grey` literals with `Theme.of(context).colorScheme` tokens so Light and Dark themes remain consistent.

---

## Phase 4 — Automated Testing & Continuous Quality Gates

1. **Expand Router & Auth Guard Tests:**
   - Add real `GoRouter` navigation & redirect tests in `test/core/router/` covering unauthenticated redirects, post-auth routing, and deep-link resolution.

2. **End-to-End Widget & Provider Coverage for Critical Customer Journeys:**
   - Add widget/provider tests for:
     - Cart & Checkout (`CartNotifier`, modifier pricing, coupon clamping, empty address guard, clear confirmation).
     - Wallet (`WalletTopUpPage` confirmation, `WalletPage` error/retry).
     - Direct Delivery & Home Services (`ServiceBookingPage` confirmation & address guard, `DeliveryTrackingPage` driver rating).
     - Settings & Privacy (`LocationSharingPage`, `FingerprintLoginPage`, `DataPrivacyPage`).

3. **Mandatory Pre-Commit Quality Gate (All 4 Flavors):**
   ```bash
   flutter gen-l10n
   flutter pub get
   flutter analyze
   flutter test
   ./build.sh
   ```
   - Never commit or push without `0` analyzer issues and `100%` passing tests.
