# SESSION_STATUS.md

> **Last updated:** 2026-08-07 Session 21r (Location: "0 m" accuracy bug fixed — Sprint 61)

---

## Current Task — LOCATION FIX: "0 m" CLAIMED WHEN ACCURACY WAS UNKNOWN (Session 21r)

User request (Arabic): "اصلح اللوكيشن في التطبيق بمقدار 0 متر" — fix the app showing the location as 0 meters. Root cause found, fixed, tested, built, and installed on DNP NX9. The remaining piece — Google Geocoding API activation — is an external Google Cloud Console action the user must take (detailed below).

| Area | Change |
|------|--------|
| **Root cause — the "0 m" bug** | `geolocator` reports `accuracy = 0.0` when the platform provides **no accuracy estimate** (`hasAccuracy == false`, typical of network/fused cell fixes). The engine treated `0` as a perfect sub-metre fix: `_isFreshAndPrecise` accepted `>= 0 && <= 1` (short-circuited acquisition as "≤ 1 m"), `_isUsableLastKnown` accepted `>= 0 && <= 500`, `refreshDeepLocked()` early-returned on `accuracy <= 1`, and `UserLocation.accuracyMeters` surfaced raw `0.0` — so an unmeasured fix was delivered as "0 m" with no warning while being potentially hundreds of meters off |
| **Fix — accuracy must be > 0** | `_isFreshAndPrecise` → `accuracy > 0 && <= 1`; `_isUsableLastKnown` → `accuracy > 0 && <= 500` (GNSS-verified last-known still passes on satellite count); `_acquirePreciseFix` best/early-complete now require `accuracy > 0` + live GNSS for the sub-metre shortcut |
| **Fix — null = unknown** | `UserLocation.accuracyMeters` is now `position.accuracy > 0 ? position.accuracy : null` — unknown accuracy is typed as `null`, so callers (delivery `_useCurrentLocation`, ride booking) can never display or trust a fabricated "0 m" |
| **Fix — deep-lock best tracking** | `refreshDeepLocked()` now prefers known-accuracy fixes across attempts; an unknown-accuracy fix is kept only as last-resort fallback and never triggers the ≤ 1 m early return |
| **Fix — geocoding key headers** | Google Geocoding HTTP call now sends `X-Android-Package: com.delwaqty.app` + `X-Android-Cert: 5337185A52F0B615A3388ECC03B6576D61F34EEF` (debug SHA-1, colons removed) — the standard way an Android-app-restricted Maps key authorizes raw REST geocoding (the Maps SDK sends these automatically; the raw `http.get` did not → `REQUEST_DENIED`) |
| **Tests** | 3 new regression tests in `location_provider_test.dart`: quick mode rejects a fresh non-GNSS last-known with unknown (0.0) accuracy; deep mode reports `null` (not 0 m) for a GNSS last-known with unknown accuracy; deep mode reports `null` for a 0.0-accuracy stream sample. Suite **570/570 passing** (was 567) |
| **Quality gates** | `flutter analyze` 0 errors, **0 new issues** from touched files (repo-wide info lints pre-existing) · `flutter test` 570/570 · debug APK built (`--dart-define-from-file=.env.dev`) + installed on DNP NX9 · app launches clean (Map SurfaceView active, no crash) |

> **REMAINING — ACTION REQUIRED FROM USER (external blocker):** enable the **Geocoding API** in Google Cloud Console for the API key's project (APIs & Services → Library → Geocoding API → Enable; billing active). The key is currently restricted to the Android app, so also confirm Application restrictions include package `com.delwaqty.app` + debug SHA-1 `53:37:18:5A:52:F0:B6:15:A3:38:8E:CC:03:B6:57:6D:61:F3:4E:EF` (colon format for the Console UI; the app sends it colons-removed). Until then the Photon/Nominatim fallback keeps producing Arabic addresses, but without Google-level POI depth. On-device E2E of the fixed accuracy flow needs a login + delivery-flow walk; fingerprint is enrolled from 21q.

---

## Previous Task — FINGERPRINT LOGIN + SAVED ACCOUNTS + SOCIAL LOGIN REMOVAL (Session 21q)

User request (Arabic): "في تسجيل الدخول فعل زر البصمة بشكل صحيح، وشيل التسجيل من أي منصة سوشيال في الوقت الحالي، وزر حفظ تسجيل الحساب شغّله بشكل صحيح، ويبقى فيه خانة للحسابات المحفوظة في تسجيل الدخول" — make the fingerprint button actually work, remove social login for now, make save-account work correctly, and add a saved-accounts section on the login page. This session shipped all four on top of the Sprint 60 verification milestone (commit `87aadc3`).

| Area | Change |
|------|--------|
| **Root cause — fingerprint** | Old flow stored email/password in **plaintext SharedPreferences** (`biometricEnabled/biometricEmail/biometricPassword`), required a password re-entry bypass, and `AndroidManifest.xml` was **missing `USE_BIOMETRIC`/`USE_FINGERPRINT`** so `LocalAuthentication` could never succeed. Added both permissions |
| **Secure store** | New `lib/data/datasources/local/saved_accounts_store.dart`: account list (email/displayName/hasBiometric) in SharedPreferences JSON under `StorageKeys.savedAccounts`; **biometric password only in Keystore/Keychain** via `flutter_secure_storage` (`biometric_password_<email>`); emails normalized at the boundary. Old plaintext keys deleted from `StorageKeys` |
| **Model** | New Freezed `SavedAccount` (`lib/features/auth/domain/saved_account.dart`) with normalized `key` getter; generated files gitignored (build artifacts) |
| **Login page** | `login_page.dart` rewritten: social buttons (Google/Apple/Facebook) removed; "حفظ الحساب" checkbox persists the account on successful login (`_handlePostLoginSave` off the `authenticated` listener) with optional "تفعيل البصمة"; horizontal **Saved Accounts** chip row — tap fills email + selects text + focuses password, fingerprint badge = one-tap biometric sign-in, × = remove with confirm dialog; fingerprint button (biometricOnly + stickyAuth) reads the secure password then calls `signIn`; shown only when `hasBiometric` for the filled email AND `canCheckBiometrics` |
| **Auth provider** | `signInWithGoogle/Apple/Facebook` getters + methods removed from `AuthStateNotifier`; `signOut` no longer wipes biometric/saved-account storage (accounts survive logout by design). Phone/password + guest remain |
| **Dependencies** | `flutter_secure_storage` pinned **`^11.0.0`** (only line using `win32 ^6`, compatible with `geolocator ^14`); **`compileSdk` 36 → 37** (v11 AAR requires API 37); plugin registrants regenerated for linux/macos/windows |
| **l10n** | New keys en+ar: `saveAccount`, `savedAccounts`, `savedAccountsHint`, `removeAccount`, `removeSavedAccountConfirm`, `accountSaved`, `accountRemoved`; regenerated |
| **Quality gates** | `flutter analyze` **0 errors / 0 warnings from touched files** (untouched-module lints are pre-existing) · `flutter test` **567/567 passing** (was 556 → +11) · debug APK built (`compileSdk 37`) + installed on DNP NX9 · app launches clean (PID 11858, no FATAL / no ConfigValidator crash) |

> **REMAINING (not blocking):** (1) on-device E2E of the Sprint 60 register → confirm-email-link → pending → admin-approve → home walk on DNP NX9 (user must tap the confirmation link; free-tier mailer 2/hr); (2) **SECURITY:** revoke the Supabase PAT used in the Sprint 60 session. Saved-account flow verified by unit tests + clean install; full fingerprint tap needs a real fingerprint-enrolled device gesture.

---

## Previous Task — ACCOUNT VERIFICATION WORKFLOW (Session 21p)

New provider/delivery sign-ups must verify their identity before using the platform: register step 1 selects an account type, providers/delivery users upload an ID card + profile photo, then an admin approves or rejects them from a new dashboard page. Customers skip verification entirely. Code was already written (uncommitted); this session finished it: lint cleanup, the missing Supabase migration, live-DB application, email-confirmation activation, and docs.

| Area | Change |
|------|--------|
| **Domain enums** | `lib/domain/enums/user_type.dart` (`customer` / `provider` / `delivery`, `requiresVerification`) + `lib/domain/enums/verification_status.dart` (`pending` / `approved` / `rejected`) — new `lib/domain/enums/` + `test/domain/enums/auth_enums_test.dart` |
| **User model** | `UserModel`/`User` gain `userType`, `verificationStatus`, `idCardUrl`, `profilePhotoUrl`; `fromSupabase` falls back: missing `user_type`/`verification_status` → treated as customer/approved |
| **Registration** | `register_page.dart` → 4-step flow: (0) account type picker, (1) info, (2) preferences, (3) confirmation. Role + documents required for provider/delivery (`selectAccountType`, `documentsRequired`). `image_picker` bottom sheet (gallery/camera), uploads via `AuthRepositoryImpl._persistSignUpProfile` |
| **Auth state** | New `AuthState.pendingVerification`; `_resolveAuthenticated` routes non-approved provider/delivery users there; router forces `/pending-verification` (unless on an auth route); `PendingVerificationPage` shows hourglass + sign-out |
| **Admin** | `AdminVerificationsPage` at `/admin/verifications` (dashboard quick action): pending requests, ID card + profile photo preview (`InteractiveViewer` zoom), approve/reject with confirm dialog; `admin_service`/`admin_repository` `getVerificationRequests` / `approveVerification` / `rejectVerification`; `verificationRequestsProvider` |
| **Storage/permissions** | AndroidManifest + Info.plist: CAMERA + media permissions with usage descriptions; uploads to the public `profiles` bucket under `id_cards/` and `profile_photos/` |
| **Home grid** | Ride tile removed from Home grid (indexes re-mapped); Home Services now index 3 |
| **Migration `020_user_verification.sql`** | Adds `user_type`, `verification_status`, `id_card_url`, `profile_photo_url` to `users` (+ CHECKs); extends `users_role_check` with `provider`/`delivery`/`owner`; admin SELECT/UPDATE policies via `is_admin()`; ensures public `profiles` bucket + upload policy. **APPLIED live** to `bttnlkmwhorjamzemwda` |
| **Migration `021_signup_type_flow.sql`** | Rewrites `handle_new_user()` so role/user_type/verification_status come from `raw_user_meta_data` (defaults: customer/approved, provider|delivery/pending) instead of hardcoding customer — otherwise email confirmation strips the session before the client-side upsert and every sign-up collapses into a customer row; backfills orphaned auth users + reconciles previously-broken provider/delivery rows; preserves owner role. **APPLIED live** |
| **Email confirmation** | Live GoTrue already `mailer_autoconfirm: false` (verified); `site_url` + `uri_allow_list` set to `io.delwaqty://login-callback` so confirmation links open the app (PKCE flow completes the session via deep link) |
| **Quality gates** | `flutter analyze` **0 errors / 0 warnings** · `flutter test` **556/556 passing** (was 542 → +14) · debug APK built + installed on DNP NX9 |

> **REMAINING (not blocking the milestone):** (1) on-device E2E of register→confirm-email-link→pending→admin-approve→home on DNP NX9 — needs the user to tap the confirmation link (Supabase built-in mailer; free-tier `rate_limit_email_sent=2`/hr); (2) commit + push the Sprint 60 milestone. **SECURITY:** the Supabase Personal Access Token used in this session must be revoked after use.

---

## Previous Task — HOME PAGE LOGO + INTRO WORDMARK FLASH FIX (Session 21o)

User reported two issues after 21n: (1) the home page header still showed the gradient square with the Arabic "دلوقتي" text instead of the actual app logo next to the sidebar button, and (2) a visible "crash"/flash during the intro while the English "Delwaqty" wordmark animates. Both fixed, verified programmatically on device (I cannot view images — verified via per-frame luma analysis + logcat).

| Area | Change |
|------|--------|
| **Root cause — wordmark flash** | Logcat proved NO Dart exception (process stays alive through the whole splash); the visible flash is a rendering artifact. The `_AmbientPainter` recreated **3 radial gradient shaders on every frame** (`ui.Gradient.radial`) inside a `RepaintBoundary`; on Impeller/Vulkan this shader churn during the wordmark phase produced a frame where the background dropped out. Confirmed by `[ERROR platform_configuration.cc(448)] Reported frame time is older than the last one; clamping` during the wordmark window (1.5–2.5 s) |
| **Fix — painter split** | `_AmbientPainter` split into two: **`_GlowPainter`** (const, paints the 3 static radial-gradient glows ONCE — `shouldRepaint => false`, raster-cached, never repaints) and **`_ParticlePainter(progress)`** (animated, draws only 30 tiny white circles — no shaders at all, still in its own `RepaintBoundary`). Per-frame work is now 30 cheap circles; zero per-frame shader creation |
| **Fix — home logo** | `_LogoMark` in `home_page.dart` now renders the official `assets/logo app/logo.png` (white 46×46 tile, radius 14, purple shadow, `ClipRRect`, `DecoratedBox` gradient "دلوقتي" fallback via `errorBuilder`) next to the `_GlassCircleButton` in the header Row |
| **Verification — wordmark flash** | Installed build → screenrecord + ffmpeg `signalstats` luma per frame: **splash window (frames 70–320) max frame-to-frame luma diff < 1.0** — the background never disappears during the wordmark. The only dips (frames 28–68, luma →17.6) are the native Android 12+ launch crossfade BEFORE Flutter's first frame — normal cold-start, not the wordmark. Splash→login transition = the single 72-luma jump at frame 323 |
| **Verification — home logo** | Asset bundled in APK (`assets/flutter_assets/assets/logo%20app/logo.png`, 1.27 MB); identical asset path already renders on splash/login; logcat has **no** `Unable to load asset` |
| **Quality gates** | `flutter analyze` 0 errors (my files contribute no new lints) · `flutter test` 542/542 passing · debug APK built + installed on DNP NX9 |

---

## Previous Task — SPLASH INTRO CRASH FIX + LOGIN LOGO (Session 21n)

Fixed the hidden "brown flash" crash during the intro wordmark animation, restored the natural splash design, made the Arabic tagline "دلوقتي" colorful like the English wordmark, and enlarged the login page logo.

| Area | Change |
|------|--------|
| **Root cause — brown flash** | `_ambientController.repeat()` (3000ms) wrapped the entire `CustomPaint` in an `AnimatedBuilder`, forcing full-widget rebuilds every frame AND recreating `RadialGradient.createShader()` on every paint. When `_wordController` started simultaneously, the combined rebuilds caused a single-frame artifact where the gradient briefly disappeared (looked like a brown/dark flash). The `Scaffold.backgroundColor` (light theme surface) showed through momentarily |
| **Fix — ambient animation** | Replaced `AnimationController.repeat()` with a raw `Ticker` feeding a `ValueNotifier<double>` (`_ambientTick`). The `CustomPaint` is now wrapped in `RepaintBoundary` + `ValueListenableBuilder` — it repaints in isolation without rebuilding the Stack/wordmark |
| **Fix — painter cost** | `_AmbientPainter` now uses `ui.Gradient.radial` (const-created) instead of `RadialGradient().createShader()` per frame; particles cached once as static `_ParticleData`; `shouldRepaint` only returns `true` when `progress` actually changed (was always `true`) |
| **Arabic tagline fix** | Split-letter `Row` (letters were disconnected/choppy in RTL) replaced with a single `RichText` + `TextSpan` — natural flowing word, each letter colored: د/ل/و white, ق purple `#7A5CFF`, ت blue `#4E8DFF`, ي teal `#2DD4BF`, fontSize 24 |
| **Login page logo** | `_buildLogo()` enlarged from 80×80 → **120×120**, border radius 22→28, stronger purple shadow (`spreadRadius 4`, blur 30) — the actual `assets/logo app/logo.png` renders prominently above "مرحبا" |
| **Verification** | `flutter analyze` 0 errors · `flutter test` 542/542 passing · debug APK built + installed on DNP NX9 · logcat **clean** (no `I/flutter` errors, no `FATAL`, no `AndroidRuntime`) · app restarts cleanly (PID 22497→23202) · splash → login flow reaches login page |

---

## Previous Task — CINEMATIC INTRO + PREMIUM AUTH (Session 21m)

Built a world-class cinematic brand introduction and redesigned the entire authentication flow. The experience follows the reference design with 10 animated scenes, premium login, and 3-step registration.

| Area | Change |
|------|--------|
| **Logo asset** | Created `assets/logo app/logo.png` from user's icon logo. Registered in `pubspec.yaml` |
| **Brand colors** | Added `brandCyan` (#06B6D4) and `brandTeal` (#14B8A6) to `AppColors` |
| **Cinematic Intro** (`cinematic_intro_page.dart`) | 10-scene experience: (1) Black intro with haptic, (2) Purple+cyan light beams, (3) Energy ring build-up, (4) Logo reveal with elastic scale+opacity, (5) Motion lines (purple→blue→cyan), (6) Wordmark "Delwa" (white) + "Qty" (gradient), (7) Arabic tagline with decorative lines, (8) 8 service icons with glass morphism, (9) Brand message "كل احتياجاتك... دلوقتي", (10) Smooth fade transition to login. Custom particle painter, light streaks, all at 60fps |
| **Premium Login** (`login_page.dart`) | Complete rewrite: deep gradient background, logo reveal animation, glass-morphism text fields (radius 18), gradient primary button (purple→blue→cyan, radius 22), social login (Google/Apple/Facebook), "Remember Me" checkbox, "Forgot Password" link, guest mode, shake animation on validation. No `GradientBackground` — custom dark luxury background |
| **Step Registration** (`register_page.dart`) | 3-step flow with animated progress bar: Step 1 (name, email, phone, password, confirm), Step 2 (language selector, notifications toggle, location toggle), Step 3 (success animation with checkmark + welcome). Glass text fields, gradient button, step transitions |
| **Navigation** | Splash → `/intro` (cinematic) → `/login` → `/register` → `/home`. Router updated to allow `/intro` route. Added `/intro` route in `splash_module.dart` |
| **l10n additions** | New keys (en+ar): `signIn`, `emailOrPhone`, `rememberMe`, `or`, `createAccount`, `location` |
| **Quality gates** | `flutter analyze` **0 errors** · `flutter test` **542/542 passing** · APK built + installed on DNP NX9 ✅ |

---

## Current Task — APP ICON + DYNAMIC APP NAME (Session 21l)

Replaced the app's launcher icon with the user's new design and set up locale-based dynamic app name so it shows "دلوقتي" on Arabic devices and "Delwaqty" on English devices.

| Area | Change |
|------|--------|
| **New launcher icon** | User-provided icon (`icon logo.png`, 1254x1254) resized to all Android density buckets: mdpi (48), hdpi (72), xhdpi (96), xxhdpi (144), xxxhdpi (192). Both `ic_launcher.png` and `ic_launcher_round.png` created in all mipmap directories |
| **Adaptive icon** | Created `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml` with foreground drawable + dark purple background (`#1A0536`). Android 8.0+ devices get the adaptive icon |
| **Dynamic app name** | Created `values/strings.xml` (`app_name` = "Delwaqty") and `values-ar/strings.xml` (`app_name` = "دلوقتي"). AndroidManifest.xml updated from hardcoded `"delwaqty"` to `@string/app_name`. System automatically picks the correct name based on device locale |
| **Web icons** | favicon.png, Icon-192.png, Icon-512.png, Icon-maskable-192.png, Icon-maskable-512.png all updated |
| **iOS icon** | Icon-App-1024x1024@1x.png updated |
| **Windows icon** | app_icon.ico updated |
| **Device verification** | APK built + installed on DNP NX9. Device locale is `en-EG` → app shows "Delwaqty" on home screen. Switching device to Arabic locale → shows "دلوقتي" |
| **Quality gates** | `flutter analyze` **0 errors** · `flutter test` **542/542 passing** · APK built + installed ✅ |

---

## Current Task — MOST REQUESTED + LANGUAGE FIX + CART ICON + ADMIN/DELIVERY V2 THEME (Session 21k)

Five changes in one session: animated Most Requested carousel on the commerce discovery page, broken Arabic language fix on the favorites page, cart icon in the sidebar, and Premium V2 theme upgrade for the admin panel and delivery list.

| Area | Change |
|------|--------|
| **Favorites language bug** | `app_ar.arb`: `"favoriteMerchants": "الmerchantات"` → `"المتاجر"`; `"noFavoritesMessage"` — replaced untranslated "merchant" with "متجر". Re-generated l10n |
| **Most Requested section** | New animated `PageView` carousel in `commerce_discovery_page.dart` between Featured and All Merchants — shows top 10 merchants sorted by rating in `_MostRequestedCard` (gradient accent, star rating, type badge, auto-scroll every 4s with dot indicators). New l10n key `mostRequested` (en: "Most Requested", ar: "الأكثر طلباً") |
| **Cart icon in sidebar** | New `SidebarItem` with `Icons.shopping_cart_outlined` under Favorites in `floating_sidebar_overlay.dart`, navigating to `/market/cart` |
| **Admin panel V2 theme** | `admin_dashboard_page.dart`: replaced all `GlassCard` → `PremiumCard` (radius `AppSpacing.radiusCard`); renamed `_StatGlassCard` → `_StatPremiumCard`; stat cards, quick actions, activity tiles all use `PremiumCard` |
| **Delivery list V2 theme** | `admin_deliveries_page.dart`: replaced `GlassCard` → `PremiumCard`; service filter chips now use `AppColors.brandPurple` gradient when selected (animated `Container`); delivery tiles use `PremiumCard` with proper radius |
| **Quality gates** | `flutter analyze` **0 errors** · `flutter test` **542/542 passing** · APK built + installed on DNP NX9 ✅ |

---

## Current Task — OFFER BANNER FIX + MERCHANT OFFERS MANAGEMENT (Session 21j)

Follow-up to the Redesign V2 milestone. Fixed the home page offer banner overflow and built a full merchant-side offers management page so merchants can create, edit, delete, and toggle offers from the dashboard.

| Area | Change |
|------|--------|
| **Offer banner overflow** | `_PromoCarousel` container height increased from 120 → 140px to accommodate padding + title + subtitle + coupon chip without bottom overflow (was overflowing 13px) |
| **Merchant Offers Page** | New `merchant_offers_page.dart` — full CRUD: list all offers with search, edit/delete/toggle-active per card, `FloatingActionButton` for creating new offers, form sheet with title, description, discount type (percentage/fixed), discount value, minimum order, max discount, start/end dates, active toggle |
| **Dashboard wiring** | "Create Offer" `ListTile` in `merchant_dashboard_page.dart` now navigates to `/merchant-dashboard/offers` (was a dead SnackBar placeholder) |
| **Route registration** | `/merchant-dashboard/offers` route registered in `merchant_module.dart` |
| **l10n additions** | 30 new keys (en+ar): `manageOffers`, `yourOffers`, `addOffer`, `editOffer`, `deleteOffer`, `offerTitle`, `enterOfferTitle`, `offerDescription`, `enterOfferDescription`, `discountType`, `percentage`, `fixedAmount`, `discountValue`, `enterDiscountValue`, `minimumOrder`, `enterMinimumOrder`, `maximumDiscount`, `enterMaximumDiscount`, `startDate`, `endDate`, `activateOffer`, `deactivateOffer`, `confirmDeleteOffer`, `offerCreated`, `offerUpdated`, `offerDeleted`, `noOffersYet`, `noOffersMessage`, `searchOffers` |
| **Quality gates** | `flutter analyze` **0 errors** · `flutter test` **542/542 passing** · APK built + installed on DNP NX9 ✅ |

---

## Current Task — REDESIGN V2: SEARCH / ORDERS / PROFILE PAGES (Session 21i)

Part of the platform-wide Premium V2 redesign (Apple/Airbnb/Stripe aesthetic, deep-purple brand). This session redesigned the remaining three bottom-nav tabs to match the Session 21h Home redesign — reusing the same V2 tokens and shared design widgets. All business logic and routes are unchanged; only presentation was upgraded.

| Area | Change |
|------|--------|
| **Search page** (`search_page.dart`) | Replaced `AppSearchBar` with the shared `PremiumSearchField` (22px frosted-glass capsule, animated focus). Filter chips + sort `ChoiceChip`s → custom `_PremiumPill` (brand gradient when selected with `shadowGlow`, glass pill when unselected; compact variant for sort bar). Grid cards → premium `_SearchMerchantCard` (24px `PremiumCard`, gradient/emoji header with image fallback, Open/Closed `_OpenBadge`, persisted `FavoriteButton`, type-color category chip, rating + count, delivery time + fee with `currencySymbol`). `EmptyState` → `PremiumEmptyState` (no-results + error with retry). Loading → shimmer `ShimmerLoading` grid. Debounce/search/sort logic untouched |
| **Orders page** (`orders_page.dart`) | Cards → 24px `PremiumCard` with colored `_StatusTile` (gradient icon per status), status `_StatusChip` with dot, items count via `l10n.itemCount(count)`, total with `currencySymbol`, schedule icon + formatted date, **Track Order** affordance (`l10n.trackYourOrder` + chevron) when trackable. Empty + error → `PremiumEmptyState` (error has retry). Loading → `_OrderSkeletonCard` shimmer. Business logic (`_ordersFutureProvider`, statuses, routes) untouched |
| **Profile page** (`profile_page.dart`) | Authed: gradient-ring avatar (`_GradientAvatarRing`) + gradient camera button, role `_RoleChip` (admin/driver/merchant/owner), `PremiumCard` header. Settings + Orders/Invoices → `_SectionCard` (title + premium card with tinted `_IconTile` leading icons, dividers). Role portals → gradient `_PortalTile` rows. Guest profile → `_GuestAvatar` gradient circle + full-width premium buttons. Logout + edit dialogs radius 26 (`radiusDialog`). Locale/theme/sign-out/edit-photo logic untouched |
| **Page backdrop** | `GradientBackground` brand wash behind all three tab bodies for a cohesive premium feel (dark-aware) |
| **l10n additions** | New keys (en+ar): `merchant`, `owner`, `rolePortals`; `gen-l10n` re-run; orders page now uses existing `itemCount`/`trackYourOrder` instead of inline strings |
| **Code deletion classification** | `AppSearchBar` + `EmptyState` widgets remain — still used by favorites/cart/restaurant-tracking pages and their tests (not deleted) |
| **Quality gates** | `flutter analyze` **0 errors** (issue count dropped 481 → 474, all pre-existing info lints) · `flutter test` **542/542 passing** · `flutter build apk --debug --dart-define-from-file=.env.dev` ✅ · APK installed on DNP NX9 ✅ |

> **Remaining (next in V2 plan):** commit/push the full Redesign V2 milestone (Sessions 21g–21i: tokens, theme, shell, Home, Search, Orders, Profile) + sprint report in `docs/HANDOFF/`, then run the device check across all four tabs.

---

## Previous Task — ADMIN PUSH UX + NOTIFICATION DELETION (Session 21g)

Follow-up to 21f. User asked for: connected devices as pure counters, an offline counter, a button showing how many devices received a broadcast, hiding the Firebase/database card, a delete-all button, and per-notification delete.

| Area | Change |
|------|--------|
| **Migration `019_push_broadcast_device_count.sql`** | Replaces `admin_broadcast_notification` to return the **device count** (number of `notification_tokens` belonging to the matched recipients) instead of the recipient-user count. Still inserts one `notifications` row per matching user. **Applied + verified live** via Management API (pg_proc shows the new body with `matched_ids uuid[]` + `device_count`) |
| **Admin page — counters** | Connected-devices card → compact stat tiles: **متصل (online)** and **غير متصل (offline)** counters (15-min window), plus an **الأجهزة المستلمة (devices received)** button showing the last broadcast's device count (updates after each send). Token list removed. Classification extracted to testable `computeDeviceStats(tokens, now)` |
| **Admin page — Firebase card removed** | The Firebase Console copy card + dead `_copyPayload`/`_openConsoleGuide`/`_buildPayload` code deleted; the RPC send is the single path |
| **Notification center — delete** | **حذف الجميع** (delete all) action with confirmation dialog (`clearAll()`); every card gains a per-item **حذف الإشعار** delete button (`deleteNotification(id)`); both invalidate `notificationsProvider`/`unreadCountProvider` |
| **Token heartbeat** | `PushNotificationService` re-upserts the token every **5 min** while the app is alive → `updated_at` is a real liveness signal, so online/offline counters are meaningful |
| **Tests** | 4 new `computeDeviceStats` tests + 3 notification-center widget tests (per-item delete, delete-all with cancel/confirm, empty state). Suite **535 → 542** · `flutter analyze` 0 errors |
| **Verify on device (DNP NX9)** | Stats card renders `1 متصل / 0 غير متصل / الأجهزة المستلمة: 0`; a test broadcast returned **1 device** and the received button updated to **1** (DB row created, RPC live); Firebase card gone (page ends at send button); notification center shows delete-all + per-item buttons; per-item delete removed the `تست/تست١` row (DB confirmed), delete-all emptied the table (**0 rows**), empty state renders. Test notification data cleaned up in the process |

> **Remaining:** background/terminated FCM push still requires a Firebase service account (external). In-app realtime broadcast + admin counters/deletion are verified working live.

---

## Previous Task — PUSH NOTIFICATION SYSTEM FIXED + VERIFIED LIVE (Session 21f)

| Area | Change |
|------|--------|
| **Root cause #1 — schema mismatch** | `notification_tokens` (migration 002) has only `created_at`, but the service + dashboard persist/read `updated_at` → every token query threw → `_saveToken` silently failed (no tokens ever stored) and the admin "connected devices" card showed the generic `خطأ` |
| **Root cause #2 — broken upsert** | `_saveToken` used `onConflict: 'token'` but no unique index exists on `token` alone (table has `UNIQUE(user_id, token)`) → the upsert itself failed |
| **Root cause #3 — RLS** | `notification_tokens` policy (`auth.uid() = user_id`) blocked admins from listing devices; the legacy `notifications` "Service role can insert" policy was `WITH CHECK (true)` with **no role restriction** — any user could insert a notification for any user |
| **Root cause #4 — no send path** | Admin page only copied an FCM payload for manual pasting into Firebase console. Real FCM v1 needs a service-account credential (external blocker). Meanwhile the app already had a full in-app notification center (`notifications` table) that was not wired to realtime |
| **Fix — migration `018_push_notification_platform.sql`** | Adds `updated_at` + auto-update trigger + `user_id` index to `notification_tokens`; admin SELECT-all-tokens policy; admin INSERT/SELECT/DELETE on `notifications`; restricts the legacy insert policy to `service_role`; adds `notifications` to `supabase_realtime`; adds admin-only `SECURITY DEFINER` RPC `admin_broadcast_notification(p_title, p_body, p_type, p_deep_link, p_target_role, p_target_user_id)` → inserts one row per matching user, returns recipient count |
| **Fix — `push_notification_service.dart`** | Upsert conflict → `user_id,token`; `platform` normalized to `android`/`ios` (CHECK constraint); **Supabase Realtime subscription** on `notifications` INSERT (RLS-scoped) → shows local notification + invalidates `notificationsProvider`/`unreadCountProvider` → instant in-app push with **no external credentials**; runs regardless of FCM permission |
| **Fix — admin page** | Real **إرسال الإشعار (Send)** button calling the RPC; audience selector (all / customer / driver / merchant / admin); type selector (`info`/`warning`/`success`/`reminder`); optional deep link; recipient-count snackbar; tokens refresh after send; connected-devices card has retry + specific failure message; Firebase console copy remains as secondary; logic extracted to testable `buildBroadcastParams` |
| **Tests** | New `admin_push_notifications_page_test.dart` (4 tests: default all-audience params, role mapping, deep-link trim, blank-link). Full suite **535/535** · `flutter analyze` 0 errors |
| **Migration 018 APPLIED to live Supabase** | Applied via Management API (`database/query`) to `bttnlkmwhorjamzemwda` with the user's Personal Access Token. Verified: `notification_tokens.updated_at` column + `notification_tokens_set_updated_at` trigger present; `admin_broadcast_notification` RPC present (pg_proc shows the 7-arg signature); `public.notifications` listed in `supabase_realtime` publication |
| **Verify — token pipeline (device)** | After app relaunch the token row appeared in `notification_tokens`: `user=8a23b719-a923-4a18-bd6e-04972097fb4b`, platform `android`, `updated_at` correctly stamped (trigger works). The admin **الأجهزة المتصلة (Connected Devices)** card now shows **1 device** + the masked token `fyx7-ITi...Kk41me9g` + relative time — the old `خطأ` state is gone |
| **Verify — admin send (device)** | On the rewritten page, filled title `Hello from admin` / body `Test Broadcast`, tapped **إرسال الإشعار**. RPC fired → 3 rows inserted into `public.notifications` (title/body/type=info/is_read=false, timestamps 03:49 UTC). Snackbar + button spinner confirmed no crash |
| **Verify — realtime delivery (device)** | Notification center (`الإشعارات`) shows the 3 `Hello from admin / Test Broadcast` rows at "2m ago"; Home header **unread badge = 3**; the old `تست / تست١` artifact row also listed. Sending from admin → row appears in the receiver's center with no manual refresh → in-app realtime broadcast loop proven end-to-end |

> **Remaining:** background/terminated FCM push still requires a Firebase **service account** credential (external). In-app realtime broadcast — the working path — needs nothing extra. Test rows (`Hello from admin` ×3 + old `تست/تست١`) were left in the DB as visible proof; clear them via `تعيين الكل كمقروء` / delete from the center, or delete the rows directly.

---

## Previous Task — "الموقع غير متاح" BUG FIXED (Over-Strict Gate Was Rejecting Real Fixes)

User reported the app **always** showed `الموقع غير متاح` on the Home header even though the phone has real, fresh location fixes. Root cause was the previous session's anti-stale fix being **over-corrected**. Fixed, tested, and proven on device.

| Area | Change |
|------|--------|
| **Root cause** | Session 21d required `satellitesUsedInFix > 0` (GNSS-only) + ≤ 2 min freshness for EVERY accepted fix. On this device that is impossible indoors: network/fused fixes always carry `satellitesUsedInFix = 0`, and the last real GPS fix was 35 min old (`hAcc=40.2`, `satellites=6`). `dumpsys location` re-analysis proved `et=` is **elapsed-time-since-boot**, not fix age — the network/fused last-fixes were actually **~1 min old (FRESH)**, rejected purely because they had no satellite count. Result: eternal `الموقع غير متاح` |
| Fix — freshness tiers | `_maxFixAge` = 2 min (stream fix freshness), new `_maxLastKnownAge` = **10 min** (last-known usability). The 9-day replay protection is preserved: anything > 10 min old is still refused |
| Fix — `_isUsableLastKnown` | New: accepts last-known ≤ 10 min old (−30 s skew). GNSS-verified positions always pass; **non-GNSS (network/fused) pass only if `accuracy >= 0 && accuracy <= 500 m`** → the fresh 100 m fused/network fix is now used instead of `الموقع غير متاح` |
| Fix — `_acquirePreciseFix` | No longer rejects satellite-less stream samples — any fresh sample accumulates as `best` and is returned. GNSS verification is now required ONLY for the ≤ 1 m early-lock shortcut (real 1 m still needs open sky). `waitSeconds` = 45 only when deep AND no usable last-known, else 12 → deep lock no longer hangs |
| `_bestAvailablePosition` | Returns fresh GNSS ≤ 1 m last-known immediately; quick mode returns a usable last-known without waiting; otherwise acquires a stream fix; falls back to usable last-known |
| Unit tests | `location_provider_test.dart` now **14 tests** (+4): satellite-less network/fused stream sample accepted as fallback; fresh non-GNSS last-known accepted in quick mode; poor-accuracy (> 500 m) non-GNSS last-known rejected; GNSS last-known up to 10 min old accepted; non-GNSS last-known older than 10 min rejected. Full suite **531/531** |
| Verify on device | `flutter analyze` 0 errors · `flutter test` 531/531 · debug APK rebuilt + installed · **Home header now shows `شاليهات مارفيل، بلو باي اسيا، السويس، مصر` (NOT `الموقع غير متاح`)** · deep-lock (`حدد موقعي` on Direct Delivery) filled the deliver-to field with the same resolved address · Termux terminal overlay briefly covered the app — brought back with `am start`, state confirmed |
| **Bundled sprint 57 features verified on device (DNP NX9)** | **Floating sidebar** opens via header menu (RTL → button is top-right): user card (`U` / `User` / `said.3pkarino@gmail.com` / `مدير عام` badge) + all sections incl. لوحة الإدارة, الشكاوى, العقوبات, تتبع مباشر · **Notifications page** renders (`الإشعارات` title, `تعيين الكل كمقروء`, empty state `لا توجد إشعارات`); unread badge is hidden by design at `unreadCount=0` · **Profile tab** + **Edit Profile dialog** show the new `اسم المستخدم` field · **Admin Dashboard → Push Notifications page** renders; `الأجهزة المتصلة` shows a graceful `خطأ` state (no FCM tokens exist yet); message field + `نسخ أمر FCM` + Firebase console link present · **logcat clean** — no `FATAL` / `AndroidRuntime` / `E/flutter` during the whole session |

> **Remaining reality check:** the ≤ 1 m deep-lock still requires a live GNSS fix (indoor `avgBasebandCn0=18.7 dB-Hz`, no fresh fix). It now degrades gracefully: if no GNSS fix arrives it uses the best fresh stream sample or a usable ≤ 10 min / ≤ 500 m last-known instead of returning nothing.

---

## Previous Task — STALE-LOCATION BUG FIXED (App No Longer Guesses)

User reported the app showed a **wrong place** (`شاليهات مارفيل، بلو باي اسيا`) that was NOT where they physically are. Root cause found, fixed, and proven on device.

| Area | Change |
|------|--------|
| **Root cause** | Android's FusedLocationProvider delivered the **9-day-old cached location** as the first stream event, **re-attributed with a fresh `getTime()`** → the app treated it as current and reverse-geocoded it. `dumpsys location` proved ALL system fixes were `et=+9d16h` (fused/network/gps) |
| Fix #1 (time filter) | `_isFreshTimestamp` — a fix is fresh only if ≤ 2 min old (30 s future tolerance). Alone this was **insufficient**: the platform re-attributes fresh timestamps to replayed caches |
| Fix #2 (GNSS verification) | `_hasLiveGnss(position)` — on Android, a position is accepted only if `AndroidPosition.satellitesUsedInFix > 0` (live GNSS session). `geolocator_android`'s `NmeaClient.enrichExtrasWithNmea` stamps the satellite count on every delivered fix; a **replayed cache carries 0** → rejected. Non-Android (tests/iOS) pass by freshness only |
| Stale fallback removed | `_bestAvailablePosition` no longer falls back to a stale `lastKnown`; it returns it only if `_isFreshAndVerified` (fresh + GNSS-verified). Null → UI honestly shows `الموقع غير متاح` instead of guessing |
| Stream onDone | `_acquirePreciseFix` now completes the completer when the stream ends (`onDone`) instead of only the timer → no 45 s hang when the provider yields nothing |
| Unit tests | `location_provider_test.dart` now **10 tests** (+5 new): rejects 9-day-old last-known when no fresh fix; ignores stale stream samples; prefers fresh stream fix over stale last-known; rejects satellite-less (`satellitesUsedInFix: 0`) Android sample; accepts GNSS-verified (`satellitesUsedInFix: 4`) sample. Note: `AndroidPosition` ctor params are untyped → must pass `0.0`/doubles (int literals throw at runtime). Full suite **527/527** |
| Verify on device | Rebuilt + installed. Home header now shows **`الموقع غير متاح`** (NOT the stale Marvel address) — the app refuses to guess. Re-verified this session: app restart → still `الموقع غير متاح`; deep-lock (`حدد موقعي`) ran a full HIGH_ACCURACY window → GPS provider still reports **no fresh fix in 9 days** (`et=+9d17h…`, `hAcc=40.2`, `satellites=6`); GNSS receiver alive (9 satellites, 301k sv-status msgs) but `avgBasebandCn0=18.7 dB-Hz` = indoor, no fix computed. All network/fused/gps last-fixes remain 9 days stale. Location mode 3, permissions granted, no mock source. **Fix is proven: the app refuses stale/replayed positions and shows `الموقع غير متاح`** |

> **Reality check:** 1 m precision is physically impossible indoors (last GPS fix `satellites=6, meanCn0=12`, 9 days stale). The `refreshDeepLocked()` 1 m lock is intact, GNSS-verified and tested. To verify a real 1 m fix end-to-end the user must step outside under open sky, then pull-to-refresh Home or place an order (order flows call `refreshDeepLocked()`).

---

## Previous Task — ACTUAL PLACE NAME + PRODUCTION-GRADE LOCATION ENGINE

Delivered the **actual place name** (like Uber) using **Photon (Komoot)** — a free, no-key OSM geocoder — and removed every non-production artifact from the engine.

| Area | Change |
|------|--------|
| Photon source | New `_photonStructuredAddress` in the 4-way geocode chain (Google → Photon → Nominatim → Overpass-nearest). Returns locality/street/state/country → on device now resolves the user's real location to **`شاليهات مارفيل، بلو باي اسيا، السويس، مصر`** (Marvel Chalets, Blue Bay Asia, Suez, Egypt) |
| Photon 403 fix | `photon.komoot.io` returned **403** to Dart's http client (same as Overpass) → added `User-Agent: Delwaqty/1.0` → 200 JSON |
| Nearest-place | `_nearestNamedPlace` radius 2000→**4000 m**, now **prioritizes POIs** (amenity/shop/leisure/tourism/building/office/place/landuse/resort/camp_site) **over highways**; found "Zafarana offices" instead of the road name |
| Production cleanup | **Removed ALL debug tracing** (`loc_debug.txt` writes, `_appendDebug`, `geo:/pos:/addr:` logs). Replaced hardcoded `dart:io` file cache with **SharedPreferences** cache (`location_geocode_cache_v1`) with **24 h TTL** + 200-entry cap. `dart:io` import removed |
| Precision lock | `refreshDeepLocked()` — 3 attempts, locks on `accuracy ≤ 1.0 m`; deep window back to **45 s** per attempt for GPS cold-start convergence |
| Verify | `flutter analyze` 0 errors · `flutter test` 522/522 · debug APK built + installed · **UI verified on device**: Home header shows `شاليهات مارفيل، بلو باي اسيا، السويس، مصر` · `files/` clean (no debug/cache artifacts) |

> Remaining external blocker for Uber-grade POI quality: Google Geocoding + Places APIs still `REQUEST_DENIED` (key not authorized in Google Cloud Console). Current depth comes from OSM (Photon/Nominatim/Overpass). 1 m fix physically requires open sky (device GNSS is dual-frequency capable).

---

## Previous Task — 1 m PRECISION LOCK (STRICT) — Google Key is the Only External Block

User demanded: **"عايز الدقه 1 متر وليس اى دقه عشوائيه"** (1 m precision, NOT random accuracy) — like Uber. Implemented a **strict 1 m lock** so order flows refuse insufficient fixes and guide the user, instead of silently accepting weak readings.

| Area | Change |
|------|--------|
| Strict lock | `refreshDeepLocked()` — up to **3 attempts** of the deep acquisition; returns as soon as `accuracy ≤ 1.0 m` (`precisionTargetMeters`); after all attempts returns best + caller shows Arabic guidance. Used by Direct Delivery `_useCurrentLocation` and Ride Booking `_useCurrentLocation` |
| Deep window | `_acquirePreciseFix(deepPrecision: true)`: `LocationAccuracy.bestForNavigation`, 30 s per attempt, early-complete at `≤ 1 m` |
| UI guidance | New l10n keys (both ARB): `accuracyInsufficient` (Arabic: "الدقة الحالية غير كافية (مطلوب دقة 1 متر)…"), `improvingAccuracy`, `retryLocation`; order flows show a snackbar when accuracy > 1 m but still fill best-effort address |
| Unit tests | New `test/features/location/presentation/providers/location_provider_test.dart` — 5 tests via `MockPlatformInterfaceMixin` mock of `GeolocatorPlatform`: service off → null, denied → null, deniedForever → null, sub-metre last-known lock, sub-metre stream lock. Suite now **522 passing** |
| Google key | **Confirmed blocked**: Geocoding + Places both return `REQUEST_DENIED: "This IP, site or mobile application is not authorized"` (tested from dev machine AND from the device). Root cause = key restrictions/API enablement in Google Cloud Console. Debug SHA-1 `53:37:18:5A:52:F0:B6:15:A3:38:8E:CC:03:B6:57:6D:61:F3:4E:EF`, package `com.delwaqty.app` |
| OSM reality | Around the user's point (tourist-village area, Zafarana/Sokhna road) the nearest named OSM POIs are 2.2–2.6 km away (Bassem Market, Mountain View Sokhna, La Regina Resort). OSM data is sparse; **Google Places is required for true Uber-style place names** |
| Verify | `flutter analyze` 0 errors · `flutter test` 522/522 · debug APK built + installed · Home shows `طريق العين السخنه، الزعفرانه، السويس، مصر` |

> **ACTION REQUIRED FROM USER (external blocker):** In Google Cloud Console → enable **Geocoding API** + **Places API**, fix the key's Application restrictions (Android key → add package `com.delwaqty.app` + SHA-1 above; or remove restriction for testing), and ensure billing is active. Until then, POI depth = OSM only.

---

## Previous Task — DEEP LOCATION PRECISION (1 m) + FULL ARABIC ADDRESS

Deepened the location engine to genuinely pursue a **1 m GPS fix** and render a **full Arabic street-level address with no digits/units in the UI** (per user's earlier "no accuracy numbers" decision; user now explicitly wants 1 m precision).

| Area | Change |
|------|--------|
| Deep engine | `_acquirePreciseFix(deepPrecision: true)` uses `LocationAccuracy.bestForNavigation`, **45 s** convergence window, completes immediately when `accuracy ≤ 1 m`, otherwise returns best sample; two precession tiers added |
| Quick path | `refreshQuick()` = `LocationAccuracy.best`, 12 s, `≤ 10 m` target — used by Home header so the passive display never blocks 45 s |
| Deep path | `refreshDeep()` — used by **order-time** capture (Direct Delivery `_useCurrentLocation`, Ride Booking `_useCurrentLocation`) so the real fix is as deep as possible at order time |
| Overpass fix | Root cause found: `overpass-api.de` returned **406** because the request lacked an explicit `User-Agent` (Dart's default rejected). Added `User-Agent: Delwaqty/1.0` → **200 + JSON**. Mirrors: overpass-api.de, overpass.kumi.systems, overpass.private.coffee (15 s per mirror, UA header on all) |
| Geocode cache | New file cache `loc_geocode_cache.json` keyed on `lat,lng` rounded to 4 decimals (~40 m grid) → second launch resolves the address **instantly** with zero Overpass/Nominatim calls (verified: no `geo:` line on 2nd run) |
| Address depth | Result on device: `طريق العين السخنه، الزعفرانه، السويس، مصر` (road → area → governorate → country, Arabic, no digits) |
| On-device accuracy | Indoors ~**7.5 m** with `bestForNavigation` (was ~25 m default); device GNSS is multi-constellation (GPS+GLONASS+BeiDou+Galileo); **1 m requires open sky** (indoor meanCn0=7, 6 sats) |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · debug APK built + installed on DNP NX9 · address renders in Home header, cache persists |

> Known limits: Google Geocoding still `REQUEST_DENIED` (unauthorized key) so POI depth comes from Nominatim + Overpass only. Exact named building needs open sky + authorized Google key (or user-entered free text).

---

## Previous Task — FUNCTIONAL BOTTOM-NAV RESTRUCTURE (Session 20)

Redesigned the bottom navigation from the module-driven Home / Direct Delivery / Ride / Settings tab set into a professional 4-tab layout: **Home / Search / Orders / Profile** — the product decision deferred in Session 19.

| Area | Change |
|------|--------|
| Nav tabs | New order by `navPriority`: **Home (10) → Search (20) → Orders (30) → Profile (40)**; the shell builds branches from `FeatureRegistry.navModules` so tabs stay module-driven |
| SearchModule | Promoted to nav module: branch `/search` → existing commerce `SearchPage`; home search bar now `context.go('/search')` (switches tab instead of pushing a duplicate) |
| OrdersModule (new) | `lib/features/orders/orders_module.dart` — nav branch `/orders` → existing commerce `OrdersPage`; `/orders` added to `restrictedRoutes` (guests → login); depends on `commerce` |
| ProfileModule | Promoted to nav module: branch `/profile` → `ProfilePage`; drawer/sidebar `/profile` uses `go` (tab switch); **gear icon** added to Profile AppBar → `push('/settings')` |
| SettingsModule | Demoted to non-nav; `/settings` kept as `shellSubRoute` wrapped in a `Scaffold` + `AppBar` (page itself remains a bare `ListView`) |
| DirectDeliveryModule | Demoted to non-nav; `/direct-delivery` kept as a `standaloneRoute`; page gained its own `AppBar` (title + back) since it is no longer rendered under the shell AppBar |
| RideModule | Re-enabled (was commented out in `module_registry.dart`); demoted to non-nav with `/ride/book` as a `standaloneRoute` (RideBookingPage has its own back button); home ride tile's `/ride/book` push now resolves; delivery tile fixed to push `/direct-delivery` |
| AppShell | Global AppBar removed (menu + notifications moved into Home header); **menu button** added to Home header (opens floating sidebar); `extendBody: true` → `false` so branch pages with their own Scaffolds are not overlapped by the floating pill; Home bottom spacer 100 → 24 |
| Routes | `app_router.dart` restricted list now includes `/orders`; `module_registry.dart` registers `OrdersModule` and re-registers `RideModule` |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · debug APK built + installed on DNP NX9 · all 4 tabs tapped on device with no crashes |

> The old tab set (Direct Delivery, Ride, Settings) remains reachable: Delivery via Home grid tile, Ride via Home grid tile (`/ride/book`), Settings via Home "More" tile + Profile gear.

---

## Current Task — MIGRATIONS EXECUTED ON SUPABASE (015 + 016)

Both migrations were executed directly against `bttnlkmwhorjamzemwda` via the Supabase Management API (`database/query` endpoint) using the user's Personal Access Token.

**Important finding:** before execution, all 5 tables returned **404 via REST** — 015 had NOT been applied (despite the report). Executed 015 then 016.

| Verification | Result |
|--------------|--------|
| `pg_tables` (public schema) | ✅ 5/5 tables exist (`complaints`, `sanctions`, `location_updates`, `chat_rooms`, `chat_messages`) |
| `relrowsecurity` | ✅ RLS enabled on 5/5 |
| `pg_policies` | ✅ 31 policies (admin SELECT/INSERT/UPDATE/DELETE + user policies per table) |
| Helper functions | ✅ `is_admin`, `add_admin_note`, `add_complaint_admin_note` |
| Realtime publication | ✅ 5/5 tables added to `supabase_realtime` |
| Storage buckets | ✅ `complaints` + `chat_attachments` |
| Grants to `authenticated` | ✅ SELECT/INSERT/UPDATE/DELETE on 5/5 |
| REST end-to-end | ✅ Table reachable (200, RLS returns filtered rows); temporary `anon` grant was revoked after the test |
| PostgREST reload | ✅ `NOTIFY pgrst, 'reload schema'` triggered |
| `flutter analyze` / `test` | ✅ 0 errors / 517 passing (unchanged) |

> **Note:** The Personal Access Token was used in the session only (never saved to files or committed). User should revoke/rotate it in Supabase → Account → Access Tokens.

---

## Current Task — RLS POLICY REBUILD (migration 016)

After 015 was applied, features still misbehaved due to RLS policies: policies from 007/014/015 overlapped or were incomplete for admin + participant flows. Fixed with a deterministic rebuild.

| Fix | Details |
|-----|---------|
| New migration `016_fix_rls_policies.sql` | Drops ALL known policy names on the 5 tables (from 007/014/015), re-enables RLS, and recreates explicit SELECT/INSERT/UPDATE/DELETE policies for admin + users |
| `is_admin()` helper | `SECURITY DEFINER` SQL function checking `users.role IN ('admin','owner')` (matches app logic; `admin_users.id` is a separate UUID and is intentionally not used) |
| `add_admin_note()` + `add_complaint_admin_note()` | Admin-only note functions; legacy RPC name preserved for the app |
| Admin full control | SELECT/INSERT/UPDATE/DELETE on complaints, sanctions, location_updates, chat_rooms, chat_messages |
| User policies | Own complaints (+legacy reporter), own sanctions, own locations, rooms they participate in, messages in their rooms (with `sender_id = auth.uid()` on insert) |
| Grants | `GRANT SELECT,INSERT,UPDATE,DELETE ... TO authenticated` on all 5 tables |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 |

> **ACTION REQUIRED:** Run `016_fix_rls_policies.sql` in the Supabase SQL Editor (instructions in session report).

---

## Current Task — MANAGEMENT TABLES DB FIX (Root Cause: migration 014)

The new features (complaints, sanctions, live tracking, support chat) failed with `Could not find the table`. Root cause found and fixed.

**Root cause:** `supabase/migrations/014_management_platform.sql` used `CREATE TYPE IF NOT EXISTS`, which **PostgreSQL does not support** (syntax error) → the migration aborted mid-way → `sanctions`, `location_updates`, `chat_rooms`, `chat_messages` were never created, and `complaints` kept the legacy 007 ride schema (missing management columns).

| Fix | Details |
|-----|---------|
| New migration `015_create_management_tables.sql` | Creates all 5 tables (merged `complaints` schema + `sanctions` + `location_updates` + `chat_rooms` + `chat_messages`) with TEXT+CHECK instead of enums; RLS policies (participant OR admin); 2 storage buckets; `add_complaint_admin_note` RPC; adds tables to `supabase_realtime` publication |
| 014 bug fixed | Replaced `CREATE TYPE IF NOT EXISTS` with guarded `DO` blocks |
| `complaints` conflict resolved | Old 007 ride table auto-detected + replaced with merged schema so ride module (`reportIssue`) keeps working |
| Dart fixes | `createComplaint`/`createRoom`/`sendMessage`/`createSanction` no longer send `id: ''` into UUID columns; use `.select().single()` to return real rows; `Complaint.fromJson` tolerates legacy ride rows |
| `supabase_service.dart` | **No change needed** — it only exposes the Supabase client; table names live in each data source |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · APK built + installed on DNP NX9 |

> **ACTION REQUIRED:** Run `015_create_management_tables.sql` (and re-run `014` for the type fix) in the Supabase SQL Editor — see instructions below.

---

## Current Task — ADMIN PANEL WIRING (Post-Sprint 51)

Made the Sprint 40 management features (complaints, sanctions, live tracking, support chat) reachable from the UI and removed all legacy ride-page references from the admin panel.

| Change | Details |
|--------|---------|
| Deleted `admin_rides_page.dart` | Old transport/ride page removed |
| Removed `/admin/rides` route | Removed from `admin_module.dart` |
| Dashboard quick actions updated | Removed `rideHistory`; added **Complaints**, **Sanctions**, **Live Tracking**, **Support Chat** (4 new actions) |
| Floating sidebar | New admin-only **Admin Panel** section (idx 8–12: admin panel, complaints, sanctions, live tracking, support chat); support section reindexed 13–18 |
| l10n cleanup | Removed 4 unused ride keys (`rideMonitoring`, `noRidesFound`, `noRidesCreated`, `noRidesSelectedStatus`) + `gen-l10n` |
| Analyzer cleanup | Removed unused imports in `floating_sidebar_overlay.dart`, `floating_sidebar_controller.dart`, `app_shell.dart` |
| Build + install | `flutter build apk --debug --dart-define-from-file=.env.dev` ✅ installed on DNP NX9 ✅ |

---

## Completed Milestones

| Milestone | Sprint | Description | Status |
|-----------|--------|-------------|--------|
| M1-M11 | 28-39 | Previous milestones (localization, transportation, booking, dispatch, search, driver platform, delivery, safety, theme, errors, empty states) | ✅ |
| M12 | 40 | Management Platform — Complaints, Sanctions, Live Tracking, Support Chat | ✅ |
| M13 | 51+ | Admin Panel Wiring — features exposed in dashboard + sidebar; legacy rides page removed | ✅ |
| M13b | 53 | Management Tables DB Fix — migration 015, 014 type bug, UUID insert + RLS fixes | ✅ |
| M13c | 54 | RLS Policy Rebuild — migration 016: is_admin helper, explicit per-command policies, grants | ✅ |
| M13d | 55 | UI Polish — Cairo typography (google_fonts), card system (radius/shadow/gradients), pill search, banner copy, micro-interactions | ✅ |
| M13e | 56 | Functional Bottom-Nav Restructure — 4-tab layout (Home/Search/Orders/Profile), Settings behind Profile gear, Delivery/Ride into Home grid | ✅ |
| M13f | 57 | Location Reliability — real place names via Photon/Nominatim/Overpass, 1 m deep lock, stale/9-day replay rejected, then over-strict gate relaxed so real fresh fixes (network/fused 100 m) are used again | ✅ |
| M13g | 57 | Push Notifications — token pipeline fixed (updated_at, upsert, platform CHECK), migration 018 applied live, admin broadcast via SECURITY DEFINER RPC, realtime in-app delivery verified end-to-end on device | ✅ |
| M13h | 57 | Admin Push UX — device counters (online/offline/received), migration 019 (RPC returns device count), Firebase card removed, notification-center delete-all + per-item delete, token heartbeat | ✅ |
| M13i | 58 | Redesign V2 — Premium UI (Apple/Airbnb/Stripe aesthetic, deep-purple brand): design tokens (colors/spacing/elevation/theme), floating glass bottom nav, shared design widgets (`PremiumCard`/`PremiumSearchField`/`GlassSurface`/`GradientBackground`), Home page redesign, then Search/Orders/Profile tab redesigns | ✅ (commit c7122b2) |
| M13j | 59 | Intro rendering — splash painter split into static glows + cheap particles (kills the wordmark-phase flash on Impeller); home header shows the real logo image next to the sidebar | ✅ |
| M13k | 60 | Account Verification — user type (customer/provider/delivery) + verification status on registration, document upload, pending-verification gate, admin approve/reject page, migrations 020+021 applied live, email confirmation + deep-link auth config | ✅ (device E2E tap-confirmation-link pending) |

---

## Sprint 40 Summary

### Management Platform
- **Migration `014_management_platform.sql`**: 5 tables with RLS policies, indexes, storage buckets for attachments
- **complaints/**: Full CRUD, status management (`pending`/`investigating`/`resolved`/`rejected`/`escalated`), admin notes, filters by type and status
- **sanctions/**: Warning, fine, temporary_ban, permanent_ban, suspension types; active/inactive filtering
- **location_tracking/**: Real-time location upsert, active driver query, Supabase Realtime stream, driver list view + map placeholder
- **support_chat/**: Bidirectional chat between users and admins, Supabase Realtime message streaming, room management, read receipts
- **Admin panel integration**: Dashboard quick actions sidebar entries, nested routes under `/admin`
- **Client pages**: `/my-complaints`, `/new-complaint`, `/support`, `/support/room/:roomId`

---

## Current Quality Gates

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors |
| `flutter test` | 555/555 passing |
| APK build | ✅ `app-debug.apk` rebuilt clean (single APK) + installed on DNP NX9 |
| Gradle | `kotlin.incremental=false` fix committed in `android/gradle.properties` |
| Migration 018 | ✅ Applied to `bttnlkmwhorjamzemwda` via Management API + verified (columns, trigger, RPC, realtime publication) |
| Migration 019 | ✅ Applied to `bttnlkmwhorjamzemwda` via Management API + verified (RPC body returns device count) |
| Migration 020 | ⏳ **Not applied yet** — needs user PAT / SQL Editor (external blocker) |
| Live E2E | ✅ Admin send → RPC returns 1 device → received counter updates; notification center per-item delete + delete-all verified (DB 0 rows) |
| Redesign V2 | ✅ Home (21h) + Search/Orders/Profile (21i) premium UI, 0 analyze errors, 555/555 tests, APK installed |

---

## Next Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| M14 | Payments integration | Pending |
| M15 | AI-powered features | Pending |

---

## Project Environment

| Tool | Value |
|------|-------|
| Flutter SDK | `E:\app\flutter` (3.44.6, Dart 3.12.2) |
| Android Device | DNP NX9 (`A3SQUT5A28003808`), Android 16 |
| Package | `com.example.delwaqty` |
| Supabase Project | `bttnlkmwhorjamzemwda` |
| Google Maps Key | `AIzaSyA9v-pk50aB3G45zIb_RQKxD5qo_CVX8GY` |
| Pub Cache | `E:\app\pub-cache` |
| Gradle Home | `E:\app\delwaqty\.gradle_home` (isolated, gitignored) |
| Git Remote | `https://github.com/delwaqtyapp/delwaqty` |

---

## Key Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Separate feature modules for each management domain | Follows existing Clean Architecture; independently testable |
| Admin pages as nested routes in AdminModule | Consistent with existing `/admin/*` pattern |
| Supabase Realtime for chat and location | No polling needed; instant updates |
| GIN index on participant_ids | Efficient `@>` containment queries for chat rooms |
| RLS per table (not blanket) | Fine-grained access control per domain |
