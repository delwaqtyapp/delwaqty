import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/gen/assets.gen.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/nav_pill_button.dart';

/// Vertical space (in logical pixels) reserved below the shell's body so pages
/// scrolled to their end never hide their last item behind the floating bottom
/// navigation pill (edge bottom margin 12 + pill vertical padding 8 + the
/// 40px NavPillButton min height + a comfortable 24px breathing gap).
/// Callers add their own system bottom inset on top.
const double kFloatingNavClearance = 84;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _handlePop(BuildContext context, WidgetRef ref) {
    if (GoRouter.of(context).canPop()) {
      GoRouter.of(context).pop();
      return;
    }
    if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(0);
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image(
                          image: Assets.egypt.delwaqtyLogoMark.provider(),
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(ctx).exitAppTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(ctx).exitAppConfirm,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(AppLocalizations.of(ctx).cancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(ctx).pop(true);
                              SystemNavigator.pop();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.error,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(AppLocalizations.of(ctx).exitAppTitle),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final registry = FeatureRegistry.instance;
    final navModules = registry.navModules;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop(context, ref);
      },
      child: Scaffold(
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: _TransparentBottomNav(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          navModules: navModules,
          colorScheme: cs,
        ),
      ),
    );
  }
}

class _TransparentBottomNav extends StatelessWidget {
  const _TransparentBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.navModules,
    required this.colorScheme,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FeatureModule> navModules;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(navModules.length, (index) {
                    final module = navModules[index];
                    final isSelected = index == selectedIndex;
                    return NavPillButton(
                      icon: module.icon!,
                      label: module.name(context),
                      isSelected: isSelected,
                      labelVisible: false,
                      onTap: () => onDestinationSelected(index),
                      colorScheme: colorScheme,
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassMenuPanel extends StatelessWidget {
  const GlassMenuPanel({
    super.key,
    required this.authState,
    required this.l10n,
    required this.themeMode,
    required this.locale,
    required this.ref,
    required this.drawerEntries,
    this.width = 264,
    this.maxHeight = 620,
    this.onRequestClose,
  });

  final AuthState authState;
  final AppLocalizations l10n;
  final ThemeMode themeMode;
  final Locale locale;
  final WidgetRef ref;
  final List drawerEntries;
  final double width;
  final double maxHeight;
  final VoidCallback? onRequestClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final user = authState is AuthAuthenticated
        ? (authState as AuthAuthenticated).user
        : null;

    final bodyEntries = drawerEntries
        .where((e) => e.position == DrawerPosition.body)
        .toList();
    final footerEntries = drawerEntries
        .where((e) => e.position == DrawerPosition.footer)
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: width,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.14),
                blurRadius: 44,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, cs, user, l10n),
                const SizedBox(height: 6),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...bodyEntries.map(
                          (entry) => GlassMenuItemTile(
                            icon: entry.icon,
                            label: entry.label(context),
                            onTap: () => _onEntryTap(context, ref, entry),
                            colorScheme: cs,
                          ),
                        ),
                const SizedBox(height: 8),
                _AnimatedDarkModeTile(
                  active: themeMode == ThemeMode.dark,
                  label: l10n.darkMode,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).toggleTheme(),
                  colorScheme: cs,
                ),
                GlassMenuItemTile(
                  icon: Icons.language_rounded,
                  label: l10n.language,
                  subtitle: locale.languageCode == 'ar' ? 'العربية' : 'English',
                  onTap: () =>
                      ref.read(localeProvider.notifier).toggleLocale(),
                  colorScheme: cs,
                ),
                if (footerEntries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...footerEntries.map(
                    (entry) => GlassMenuItemTile(
                      icon: entry.icon,
                      label: entry.label(context),
                      onTap: () => _onEntryTap(context, ref, entry),
                      colorScheme: cs,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                GlassMenuItemTile(
                  icon: Icons.logout_rounded,
                  label: l10n.logout,
                  colorScheme: cs,
                  isDestructive: true,
                  onTap: () {
                    onRequestClose?.call();
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.logout),
                        content: Text(l10n.areYouSureYouWantToLogout),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              ref
                                  .read(authStateProvider.notifier)
                                  .signOut();
                            },
                            child: Text(
                              l10n.logout,
                              style: TextStyle(color: cs.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onEntryTap(BuildContext context, WidgetRef ref, DrawerEntry entry) {
    onRequestClose?.call();
    entry.onTap(context, ref);
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    User? user,
    AppLocalizations l10n,
  ) {
    final name = (user?.fullName?.isNotEmpty ?? false)
        ? user!.fullName!
        : (user?.username?.isNotEmpty ?? false)
        ? user!.username!
        : l10n.user;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final roleLabel = user == null ? null : _roleLabel(user.role, l10n);
    final badge = user == null ? null : _verificationBadge(user, l10n, cs);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildAvatarRing(context, cs, user, initial, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user?.verificationStatus.isApproved == true) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: AppColors.brandPurple,
                          ),
                        ],
                      ],
                    ),
                    if (user?.username?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${user!.username}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandPurple,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (roleLabel != null || badge != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (roleLabel != null)
                            _buildChip(
                              cs,
                              label: roleLabel,
                              icon: _roleIcon(user!.role),
                              color: _roleColor(user.role, cs),
                            ),
                          if (badge != null)
                            _buildChip(
                              cs,
                              label: badge.$1,
                              icon: badge.$2,
                              color: badge.$3,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarRing(
    BuildContext context,
    ColorScheme cs,
    User? user,
    String initial, {
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPurple, AppColors.brandViolet],
        ),
      ),
      child: ClipOval(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: (user?.avatarUrl?.isNotEmpty ?? false)
              ? Image.network(
                  user!.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _buildAvatarFallback(context, cs, initial),
                )
              : _buildAvatarFallback(context, cs, initial),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(BuildContext context, ColorScheme cs, String initial) {
    return Container(
      color: cs.primary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChip(
    ColorScheme cs, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String? _roleLabel(String role, AppLocalizations l10n) {
    switch (role) {
      case 'admin':
        return l10n.admin;
      case 'owner':
        return l10n.owner;
      case 'merchant':
        return l10n.merchant;
      case 'provider':
        return l10n.provider;
      case 'driver':
        return l10n.driver;
      case 'delivery':
        return l10n.delivery;
      case 'customer':
        return l10n.customer;
      default:
        return null;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
      case 'owner':
        return Icons.shield_rounded;
      case 'merchant':
        return Icons.storefront_rounded;
      case 'provider':
        return Icons.handyman_rounded;
      case 'driver':
      case 'delivery':
        return Icons.delivery_dining_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Color _roleColor(String role, ColorScheme cs) {
    switch (role) {
      case 'admin':
      case 'owner':
        return AppColors.brandPurple;
      case 'merchant':
        return const Color(0xFF0D9488);
      case 'provider':
        return const Color(0xFF06B6D4);
      case 'driver':
      case 'delivery':
        return const Color(0xFFEA580C);
      default:
        return cs.onSurfaceVariant;
    }
  }

  (String, IconData, Color)? _verificationBadge(
    User user,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final status = user.verificationStatus;
    if (status.isApproved) {
      return (l10n.verified, Icons.verified_rounded, const Color(0xFF16A34A));
    }
    if (status.isRejected) {
      return (
        l10n.verificationRejectedTitle,
        Icons.error_outline_rounded,
        cs.error,
      );
    }
    if (user.userType.requiresVerification) {
      return (
        l10n.verificationPending,
        Icons.hourglass_top_rounded,
        const Color(0xFFD97706),
      );
    }
    return null;
  }
}

class GlassMenuItemTile extends StatelessWidget {
  const GlassMenuItemTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    this.subtitle,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final String? subtitle;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A modern, animated dark-mode row: the leading icon morphs (sun / moon)
/// with a rotational pop while the trailing control is a glowing, sliding
/// pill switch. The tile keeps the exact same height as a normal menu tile.
class _AnimatedDarkModeTile extends StatelessWidget {
  const _AnimatedDarkModeTile({
    required this.active,
    required this.label,
    required this.onTap,
    required this.colorScheme,
  });

  final bool active;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: active
                  ? LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.16),
                        colorScheme.tertiary.withValues(alpha: 0.10),
                      ],
                    )
                  : null,
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: anim,
                    child: ScaleTransition(
                      scale: anim.drive(
                        Tween(begin: 0.2, end: 1.0)
                            .chain(CurveTween(curve: Curves.easeOutBack)),
                      ),
                      child: child,
                    ),
                  ),
                  child: Icon(
                    active
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    key: ValueKey(active),
                    size: 22,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _AnimatedThemeSwitch(
                  active: active,
                  onChanged: (_) => onTap(),
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact glowing slide switch whose knob is a sun / moon that changes
/// color, with an animated halo when dark mode is turned on. All transitions
/// are finite, so tests using pumpAndSettle stay stable.
class _AnimatedThemeSwitch extends StatelessWidget {
  const _AnimatedThemeSwitch({
    required this.active,
    required this.onChanged,
    required this.colorScheme,
  });

  final bool active;
  final ValueChanged<bool> onChanged;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 28,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: active
                    ? const [Color(0xFF3A2E6E), Color(0xFF6D5AE0)]
                    : [
                        colorScheme.surfaceContainerHighest,
                        colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.7),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? colorScheme.primary.withValues(alpha: 0.55)
                      : Colors.transparent,
                  blurRadius: 10,
                  spreadRadius: active ? 1 : 0,
                ),
              ],
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutBack,
            alignment:
                active ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? const Color(0xFF2A214F) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                active
                    ? Icons.dark_mode_rounded
                    : Icons.wb_sunny_rounded,
                size: 14,
                color:
                    active ? const Color(0xFFFFD54F) : const Color(0xFFF6A107),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
