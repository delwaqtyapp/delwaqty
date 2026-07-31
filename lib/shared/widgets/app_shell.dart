import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/floating_sidebar/floating_sidebar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
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
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => FloatingSidebarController.open(context, ref),
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
            color: colorScheme.onSurface.withValues(alpha: isDark ? 0.4 : 0.08),
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
                  ? colorScheme.surface.withValues(alpha: 0.1)
                  : colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? colorScheme.onSurface.withValues(alpha: 0.1)
                    : colorScheme.onSurface.withValues(alpha: 0.06),
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
                style: AppTextStyles.titleSmall.copyWith(fontSize: 13, color: colorScheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
