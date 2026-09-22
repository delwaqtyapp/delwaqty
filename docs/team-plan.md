# Team Plan — Home Screen Egyptian Hero (sprint 173)

> User spec (45 points): Egyptian Futurism hero based on NEW provided background `516019.png`
> (sent in chat; NOT accessible to agents — model cannot read images, chat attachments do not
> land on disk). Asset path wired: `assets/egypt/home_egypt_hero.png` (placeholder = intro
> cinematic bg copy). When the user drops the real file at that exact name, the hero is live,
> zero code change. The image itself is NEVER modified/mirrored/cropped randomly.

## Shared foundation (done by orchestrator — green: analyze 0, tests 937/937)
- `assets/egypt/home_egypt_hero.png` — placeholder asset wired (user overwrites).
- `lib/core/theme/app_colors.dart` — added `brandBlue` 0xFF4057D8, `brandGold` 0xFFD8A84E.
- `lib/l10n/app_en.arb` + `app_ar.arb` + regenerated — new keys: `mainCategories`,
  `discoverNearby`, `nearbySubtitle`, `closest`, `topRated`, `egyptStatementTitle`,
  `egyptStatementTagline`, `greetingSubtitle`; AR `searchHint` →
  "ابحث عن مطعم، منتج، خدمة أو أي شيء..."، AR `fastestWayToOrder` → "أسرع طريقة للطلب من كل خدماتك".
- `lib/shared/widgets/design/premium_search_field.dart` — added optional `height`,
  `borderRadius`, `autofocus` (backward compatible).

## Task 1 — coder (OWNER: `lib/features/customer/home/presentation/pages/home_page.dart`)
Full hero redesign: hero bg block + overlay, top header (notification LEFT, Egypt statement
RIGHT, brand lockup CENTER using `assets/egypt/delwaqty_logo_mark.png` + "DelwaQty" with
Purple→Blue→Cyan "Qty" + "دلوقتي"), greeting (real user name), location pill (real location),
search bar (real navigation `/search`), quick-order banner (Purple→Blue, 100-110h, radius 26,
delivery icon, arrow), promo carousel (190-220h, errorBuilder kept), categories section
(mainCategories title + viewAll + 60px/18r pastel tiles), nearby section (3 REAL chips:
closest/topRated/mostRequested — NO fake 4th deals chip), merchant cards (white, radius 22-24,
image 110-120, full real data), bottom padding 90→120, subtle cinematics (fade + scale logo
0.96→1.0, fade/slide greeting/search/CTA, NO bounce/spin), RTL/LTR same background orientation.

## Task 2 — coder2 (OWNER: `app_shell.dart` + `search_page.dart`)
- Dock restyle to spec: margin h16/v bottom 12, radius 28, total height ~72-76 (+SafeArea), white
  surface, soft shadow, active pill radius capsule 999. Functionality untouched.
- Search page: pass `autofocus: true` to the PremiumSearchField → keyboard opens immediately.

## Gates (orchestrator after dispatch)
1. `flutter analyze` → 0 • 2. `flutter test` → ≥937 (fix chip/search tests if labels changed) •
3. Build debug APK → install → relaunch clean (no unbounded/RenderFlex/assertion) •
4. Commit sprint 173 + push + SESSION_STATUS + Arabic report to user (remind: place real image).

## Constraints all agents
- ADR-044/075: NO Blur/BackdropFilter in new code, gradients only, RepaintBoundary OK.
- No flat giant color blocks; hero overlay = soft lavender gradient 8-18% only for readability.
- All text maxLines + ellipsis; no overflow; single quotes; trailing commas; no comments.
- Never touch `.arb`/`app_colors`/`premium_search_field` (shared) or the other agent's files.
- NEVER mirror/flip the background; `Alignment.center` for the image in both directions.