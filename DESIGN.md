# Delwaqty Design System

One page of truth for how the platform looks and moves. Every screen in all four
apps (customer, merchant, driver, admin) follows this. If a screen and this
document disagree, the screen is wrong.

## Principles

1. **Arabic first.** The default reading experience is Egyptian Arabic in RTL.
   Latin is the secondary script. Typeset for Arabic; Latin inherits.
2. **Solid surfaces, real contrast.** No glassmorphism over content. Cards and
   sheets are solid; scrims are flat (`Colors.black` at 55%), never blur.
3. **Content over chrome.** No photographic heroes behind UI. Color blocks and
   photography are for content (store photos, offers), never behind text or
   navigation.
4. **Tokens or it doesn't merge.** Raw `Color(0x...)`, `fontSize: n`,
   `BorderRadius.circular(n)` and literal `EdgeInsets` numbers outside
   `lib/core/theme` and `lib/shared/widgets` fail CI (`tool/design_guard.sh`).
5. **One job per screen element.** The primary action on any screen is
   visually louder than everything else. If two elements shout, one gets
   demoted.

## Color

Source: `lib/core/theme/app_colors.dart`. Use `Theme.of(context).colorScheme`
first, `AppColors` for brand/semantic/service colors.

- Brand: `brandPurple` family for brand chrome (header, nav, primary CTAs).
- Food accent: `merchantFood` (#E65100) family for food CTAs and offer
  surfaces only. Never for errors.
- Semantic: success/warning/error/info come from the token set, never ad-hoc
  Material palette entries (`Colors.teal`, `Colors.indigo` are banned outside
  the theme).
- Order statuses use `orderPending/Confirmed/Preparing/Ready/InTransit/
  Delivered/Cancelled` everywhere an order status appears, in every app.
- Dark mode is a first-class citizen: every color choice must resolve through
  the color scheme so dark mode follows for free.

## Typography

Source: `lib/core/theme/app_text_styles.dart`. Font: Cairo (bundled 300-900).

- `letterSpacing` is **0 on every style**. Tracking is a Latin device; it
  degrades Arabic joining.
- Line-heights: display 1.2+, titles ~1.35, body 1.55, labels 1.4. Arabic
  diacritics clip below that.
- Prices and money amounts use `AppTextStyles.price` (tabular figures,
  extrabold) so columns of numbers line up.
- Minimum sizes: 12sp anywhere, 11sp only for badges/pills. Driver app:
  nothing below 12sp, primary actions >= 48dp targets.

## Spacing, radius, elevation

- 4px grid via `AppSpacing` (`d4`..`d96`, `xs`..`xl`). No literal numbers.
- Radii via `AppSpacing.borderRadius*`: cards 18-22, buttons/inputs 14-16,
  pills/chips 8-11. Nested radius = outer minus padding.
- Elevation is mostly flat: 0dp cards with hairline borders or very soft
  shadows (`shadowBrand`). Floating elements (offer sheet, popups) may use
  `shadowFloat`.

## Components

- Buttons: one filled primary per screen region; secondary = outlined;
  destructive = error-colored outlined or text. Full-width primary is 56dp.
- Cards: `PremiumCard`/themed `Card` with token radius and hairline
  `outlineVariant` border.
- Chips/badges: 10.5-11sp extrabold on a 12%-alpha token background.
- Icon-in-tinted-circle is the menu/list row pattern (34-40px circle,
  12%-alpha accent background).
- Never show a zero rating. Merchants under 10 ratings display a "جديد"
  (new) badge instead of `0.0 ★`.

## States

Every async surface has four designed states; none are optional:

1. **Loading**: `ShimmerLoading` rows shaped like the final content. Bare
   `CircularProgressIndicator` only for full-screen blocking loads.
2. **Empty**: `AppEmptyState` (variant standard or premium) with an icon, a
   human title, one line of help, and at most one action.
3. **Error**: `AppErrorState` with `onRetry` ("حاول تاني"). A bare
   `Center(Text(error))` is a bug.
4. **Offline**: same as error with the offline icon and copy.

## Motion

Source: `lib/core/theme/app_animation.dart`.

- Durations: micro 100ms, buttons 200ms, panels/cards 300ms, reveals 500ms.
  Nothing interactive exceeds 500ms; 800ms is splash-only.
- Curves: `standard` (easeOutCubic) to enter, `accelerate` to exit, `sharp`
  for emphasis. `bounce` is for delight moments only (add-to-cart, success).
- Pressed feedback: `PressableScale` on cards and tappable tiles.
- Perpetual animations (typewriter, marquee, infinite pulse) are banned on
  interactive screens. The radar pulse on the driver online screen is the one
  exception, and it must stop when an offer arrives.
- Haptics: `HapticFeedback.mediumImpact` on driver offer arrival and order
  status changes; `lightImpact` on add-to-cart; `selectionClick` on steppers
  and toggles.

## RTL

- Directional everything: `EdgeInsetsDirectional`, `AlignmentDirectional`,
  `BorderRadiusDirectional`. Zero exceptions.
- Icons that imply direction (chevrons, back/forward, progress) must flip:
  use `Icons.arrow_back_ios_new` matched to `Directionality`, or
  direction-aware icons. A hardcoded `Icons.chevron_right` is a bug.
- Numbers and prices stay LTR inside RTL text (the bidi algorithm handles
  this when you don't wrap them in direction overrides).

## Copy (ar-EG voice)

- Egyptian Arabic, short and warm: "دوّر على أكل، ماركت، صيدلية…",
  "اطلب دلوقتي", "حاول تاني", "مش متاح حالياً".
- Relative time on cards ("منذ ٣ دقائق"), machine formats
  (`yyyy-MM-dd HH:mm`) only in admin tables.
- Confirmations are specific: "قبول الرحلة · ٤٥ ج.م", not generic تأكيد/إلغاء.

## The design guard

`tool/design_guard.sh` runs in CI. Counts of raw colors, radii and font sizes
outside the theme can only go down. After a cleanup, run
`bash tool/design_guard.sh --update` to ratchet the baseline.
`--report` lists the worst files.

---
*Customer home direction (warm orange vs clean purple) pending owner choice;
this document's color section applies either way - only token assignments
change.*
