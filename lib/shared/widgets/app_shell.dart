import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/data/providers.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  int get _currentIndex => navigationShell.currentIndex;

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
    final unreadAsync = ref.watch(unreadCountProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: Badge(
              label: unreadAsync.when(
                data: (count) => count > 0 ? Text('$count') : null,
                loading: () => null,
                error: (_, __) => null,
              ),
              isLabelVisible: unreadAsync.valueOrNull != null &&
                  unreadAsync.value! > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
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
        onNavigate: (index) {
          Navigator.of(context).pop();
          _onTap(index);
        },
        onProfile: () {
          Navigator.of(context).pop();
          context.push('/profile');
        },
        onNotifications: () {
          Navigator.of(context).pop();
          context.push('/notifications');
        },
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.expenses,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
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
    required this.onNavigate,
    required this.onProfile,
    required this.onNotifications,
  });

  final AuthState authState;
  final AppLocalizations l10n;
  final ThemeMode themeMode;
  final Locale locale;
  final WidgetRef ref;
  final void Function(int) onNavigate;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final userName = authState is AuthAuthenticated
        ? (authState as AuthAuthenticated).user.fullName ?? 'User'
        : 'User';
    final userEmail = authState is AuthAuthenticated
        ? (authState as AuthAuthenticated).user.email
        : '';

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
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(l10n.home),
              onTap: () => onNavigate(0),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.expenses),
              onTap: () => onNavigate(1),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(l10n.profile),
              onTap: onProfile,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.notifications),
              onTap: onNotifications,
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
