import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/theme/app_icons.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/glass_notifications_menu.dart';
import 'package:delwaqty/shared/widgets/glass_side_menu.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';

/// Reusable circular frosted-glass button for floating top-bar actions.
///
/// Set [overDarkHero] to `true` when placed over a dark/colored hero banner
/// (e.g. Customer home), or `false` (default) for standard light/dark surfaces.
class FloatingGlassCircleButton extends StatelessWidget {
  const FloatingGlassCircleButton({
    super.key,
    required this.child,
    this.overDarkHero = false,
    this.size = 42,
    this.iconSize = 20,
    this.onTap,
    this.tooltip,
  });

  final bool overDarkHero;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final String? tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = overDarkHero
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    final Widget circle;
    if (overDarkHero) {
      circle = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: foregroundColor, size: iconSize),
          child: Center(child: child),
        ),
      );
    } else {
      circle = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.32)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.78),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: foregroundColor, size: iconSize),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip ?? '',
        child: PressableScale(onTap: onTap ?? () {}, child: circle),
      ),
    );
  }
}

/// Floating glass circle menu button that opens [GlassSideMenuController]
/// anchored to this button's screen bounds.
class FloatingMenuCircleButton extends ConsumerStatefulWidget {
  const FloatingMenuCircleButton({
    super.key,
    this.overDarkHero = false,
    this.size = 42,
    this.iconSize = 20,
    this.drawerEntries,
  });

  final bool overDarkHero;
  final double size;
  final double iconSize;
  final List<DrawerEntry>? drawerEntries;

  @override
  ConsumerState<FloatingMenuCircleButton> createState() =>
      _FloatingMenuCircleButtonState();
}

class _FloatingMenuCircleButtonState
    extends ConsumerState<FloatingMenuCircleButton> {
  final GlobalKey _key = GlobalKey();

  void _openMenu() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    final anchor = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    GlassSideMenuController.open(
      context,
      ref,
      anchor: anchor,
      drawerEntries: widget.drawerEntries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FloatingGlassCircleButton(
      key: _key,
      overDarkHero: widget.overDarkHero,
      size: widget.size,
      iconSize: widget.iconSize,
      tooltip: l10n.openMenuTooltip,
      onTap: _openMenu,
      child: Icon(AppIcons.navDrawer, size: widget.iconSize),
    );
  }
}

/// Floating glass circle notification button with live unread count badge.
///
/// Opens [GlassNotificationsMenuController] as a floating transparent glass
/// bubble anchored to the bell button (matching [FloatingMenuCircleButton]).
class FloatingNotificationCircleButton extends ConsumerStatefulWidget {
  const FloatingNotificationCircleButton({
    super.key,
    this.overDarkHero = false,
    this.size = 42,
    this.iconSize = 20,
    this.onTap,
  });

  final bool overDarkHero;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  ConsumerState<FloatingNotificationCircleButton> createState() =>
      _FloatingNotificationCircleButtonState();
}

class _FloatingNotificationCircleButtonState
    extends ConsumerState<FloatingNotificationCircleButton> {
  final GlobalKey _key = GlobalKey();

  void _openNotifications() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    final anchor = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    GlassNotificationsMenuController.open(context, ref, anchor: anchor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final isGuest = authState is AuthGuest;
    final unreadCount = isGuest
        ? 0
        : ref.watch(unreadCountStreamProvider).value ??
              ref.watch(unreadCountProvider).value ??
              0;

    return FloatingGlassCircleButton(
      key: _key,
      overDarkHero: widget.overDarkHero,
      size: widget.size,
      iconSize: widget.iconSize,
      tooltip: l10n.notificationsTooltip,
      onTap:
          widget.onTap ??
          (isGuest ? () => context.push('/login') : _openNotifications),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(Icons.notifications_outlined, size: widget.iconSize),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: unreadCount > 0
                  ? Container(
                      key: ValueKey<int>(unreadCount > 99 ? 100 : unreadCount),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.error,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                        border: Border.all(
                          color: context.colorScheme.surfaceContainerLowest,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
