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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final registry = FeatureRegistry.instance;
    final navModules = registry.navModules;
    final drawerEntries = registry.allDrawerEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      drawer: _AppDrawer(
        authState: authState,
        l10n: l10n,
        themeMode: themeMode,
        locale: locale,
        ref: ref,
        drawerEntries: drawerEntries,
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: navModules.map((module) {
          return NavigationDestination(
            icon: Icon(module.icon),
            label: module.name(context),
          );
        }).toList(),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.authState,
    required this.l10n,
    required this.themeMode,
    required this.locale,
    required this.ref,
    required this.drawerEntries,
  });

  final AuthState authState;
  final AppLocalizations l10n;
  final ThemeMode themeMode;
  final Locale locale;
  final WidgetRef ref;
  final List drawerEntries;

  @override
  Widget build(BuildContext context) {
    final userName = authState is AuthAuthenticated
        ? (authState as AuthAuthenticated).user.fullName ?? 'User'
        : 'User';
    final userEmail = authState is AuthAuthenticated
        ? (authState as AuthAuthenticated).user.email
        : '';

    final bodyEntries =
        drawerEntries.where((e) => e.position == DrawerPosition.body).toList();
    final footerEntries = drawerEntries
        .where((e) => e.position == DrawerPosition.footer)
        .toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Center(
                        child: Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : 'U',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ...bodyEntries.map(
              (entry) => ListTile(
                leading: Icon(entry.icon),
                title: Text(entry.label(context)),
                onTap: () => entry.onTap(context, ref),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              title: Text(l10n.darkMode),
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggleTheme(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(l10n.language),
              subtitle:
                  Text(locale.languageCode == 'ar' ? 'العربية' : 'English'),
              onTap: () {
                ref.read(localeProvider.notifier).toggleLocale();
              },
            ),
            if (footerEntries.isNotEmpty) ...[
              const Spacer(),
              const Divider(),
              ...footerEntries.map(
                (entry) => ListTile(
                  leading: Icon(entry.icon),
                  title: Text(entry.label(context)),
                  onTap: () => entry.onTap(context, ref),
                ),
              ),
            ],
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.logout,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(context).pop();
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.logout),
                    content: Text(
                      'Are you sure you want to ${l10n.logout.toLowerCase()}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref.read(authStateProvider.notifier).signOut();
                        },
                        child: Text(
                          l10n.logout,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
