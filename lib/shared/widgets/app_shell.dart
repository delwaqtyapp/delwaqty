import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _openDrawer(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.read(authStateProvider);
    final themeMode = ref.read(themeModeProvider);
    final locale = ref.read(localeProvider);
    final registry = FeatureRegistry.instance;
    final drawerEntries = registry.allDrawerEntries;

    final RenderBox? appBarBox =
        context.findRenderObject() as RenderBox?;
    final Offset buttonPosition =
        appBarBox != null ? appBarBox.localToGlobal(Offset.zero) : Offset.zero;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = kToolbarHeight;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'drawer',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutQuint,
          reverseCurve: Curves.easeInQuint,
        );
        return FadeTransition(
          opacity: curved,
          child: child,
        );
      },
      pageBuilder: (ctx, anim, secondaryAnim) {
        final topOffset = statusBarHeight + appBarHeight + 4;
        return _DrawerPanel(
          authState: authState,
          l10n: l10n,
          themeMode: themeMode,
          locale: locale,
          ref: ref,
          drawerEntries: drawerEntries,
          topOffset: topOffset,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final registry = FeatureRegistry.instance;
    final navModules = registry.navModules;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _openDrawer(context, ref),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: _TransparentBottomNav(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        navModules: navModules,
        colorScheme: cs,
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
          child: Container(
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
                    return _NavIconButton(
                      icon: module.icon!,
                      label: module.name(context),
                      isSelected: isSelected,
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

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerPanel extends StatelessWidget {
  const _DrawerPanel({
    required this.authState,
    required this.l10n,
    required this.themeMode,
    required this.locale,
    required this.ref,
    required this.drawerEntries,
    required this.topOffset,
  });

  final AuthState authState;
  final AppLocalizations l10n;
  final ThemeMode themeMode;
  final Locale locale;
  final WidgetRef ref;
  final List drawerEntries;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final userName = authState is AuthAuthenticated
        ? (authState as AuthAuthenticated).user.fullName ?? 'User'
        : 'User';
    final isAdmin = authState is AuthAuthenticated &&
        (authState as AuthAuthenticated).user.role == 'admin' ||
        (authState is AuthAuthenticated && (authState as AuthAuthenticated).user.role == 'owner');
    final displayRole = isAdmin ? 'SuperAdmin' : null;

    final bodyEntries = drawerEntries
        .where((e) => e.position == DrawerPosition.body)
        .toList();
    final footerEntries = drawerEntries
        .where((e) => e.position == DrawerPosition.footer)
        .toList();

    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.translucent,
          child: Container(color: Colors.transparent),
        ),
        Positioned(
          top: topOffset,
          left: 12,
          right: 12,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutQuint,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -8 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                        blurRadius: 48,
                        spreadRadius: -4,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(context, cs, userName, displayRole),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: cs.outline.withValues(alpha: 0.12),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...bodyEntries.map(
                                  (entry) => _DrawerTile(
                                    icon: entry.icon,
                                    label: entry.label(context),
                                    onTap: () => entry.onTap(context, ref),
                                    colorScheme: cs,
                                    isDark: isDark,
                                  ),
                                ),
                                if (isAdmin) ...[
                                  _DrawerTile(
                                    icon: Icons.admin_panel_settings_rounded,
                                    label: l10n.adminDashboard,
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      context.push('/admin');
                                    },
                                    colorScheme: cs,
                                    isDark: isDark,
                                  ),
                                ],
                                const SizedBox(height: 2),
                                _DrawerTile(
                                  icon: themeMode == ThemeMode.dark
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  label: l10n.darkMode,
                                  onTap: () =>
                                      ref.read(themeModeProvider.notifier).toggleTheme(),
                                  colorScheme: cs,
                                  isDark: isDark,
                                  trailing: Switch(
                                    value: themeMode == ThemeMode.dark,
                                    onChanged: (_) => ref
                                        .read(themeModeProvider.notifier)
                                        .toggleTheme(),
                                  ),
                                ),
                                _DrawerTile(
                                  icon: Icons.language_rounded,
                                  label: l10n.language,
                                  subtitle: locale.languageCode == 'ar'
                                      ? 'العربية'
                                      : 'English',
                                  onTap: () =>
                                      ref.read(localeProvider.notifier).toggleLocale(),
                                  colorScheme: cs,
                                  isDark: isDark,
                                ),
                                if (footerEntries.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  ...footerEntries.map(
                                    (entry) => _DrawerTile(
                                      icon: entry.icon,
                                      label: entry.label(context),
                                      onTap: () => entry.onTap(context, ref),
                                      colorScheme: cs,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                                _DrawerTile(
                                  icon: Icons.logout_rounded,
                                  label: l10n.logout,
                                  colorScheme: cs,
                                  isDark: isDark,
                                  isDestructive: true,
                                  onTap: () {
                                    Navigator.of(context).pop();
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    String userName,
    String? displayRole,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (displayRole != null) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      displayRole,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    required this.isDark,
    this.subtitle,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isDark;
  final String? subtitle;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.5,
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
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
