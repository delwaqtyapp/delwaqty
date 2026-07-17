import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isGuest = authState is AuthGuest;

    if (isGuest) {
      return _buildGuestProfile(context, ref, l10n);
    }

    final isAdmin = authState is AuthAuthenticated &&
        (authState.user.role == 'admin' || authState.user.role == 'owner');
    final isDriver = authState is AuthAuthenticated && authState.user.role == 'driver';
    final isMerchant = authState is AuthAuthenticated && authState.user.role == 'merchant';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedFadeIn(child: _buildProfileHeader(context, authState)),
          const SizedBox(height: 24),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 100),
            child: _buildSettingsSection(context, ref, l10n, themeMode, locale),
          ),
          if (isAdmin || isDriver || isMerchant) ...[
            const SizedBox(height: 16),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 150),
              child: _buildRolePortals(context, l10n, isAdmin, isDriver, isMerchant),
            ),
          ],
          const SizedBox(height: 24),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 200),
            child: _buildLogoutButton(context, ref, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestProfile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 80,
                color: context.colorScheme.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.guestMode,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.guestModeHint,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.pushNamed('login'),
                child: Text(l10n.login),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.pushNamed('register'),
                child: Text(l10n.register),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthState authState) {
    final user = authState is AuthAuthenticated ? authState.user : null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (user?.fullName?.isNotEmpty == true)
                    ? user!.fullName![0].toUpperCase()
                    : 'U',
                style: context.textTheme.headlineMedium?.copyWith(
                  color: context.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.fullName ?? 'User',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeMode themeMode,
    Locale locale,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l10n.wallet),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/wallet'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notifications),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/notifications'),
          ),
          const Divider(height: 1),
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
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.language),
            subtitle: Text(locale.languageCode == 'ar' ? 'العربية' : 'English'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePortals(
    BuildContext context,
    AppLocalizations l10n,
    bool isAdmin,
    bool isDriver,
    bool isMerchant,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAdmin) ...[
          FilledButton.tonalIcon(
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(l10n.admin),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isDriver || isAdmin) ...[
          FilledButton.tonalIcon(
            onPressed: () => context.push('/driver'),
            icon: const Icon(Icons.delivery_dining_outlined),
            label: Text(l10n.driverDashboard),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isMerchant || isAdmin) ...[
          FilledButton.tonalIcon(
            onPressed: () => context.push('/merchant-dashboard'),
            icon: const Icon(Icons.store_outlined),
            label: Text(l10n.merchantDashboard),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return OutlinedButton.icon(
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.logout),
            content: Text(
              l10n.areYouSureYouWantToLogout,
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
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ],
          ),
        );
      },
      icon: Icon(Icons.logout_rounded, color: context.colorScheme.error),
      label: Text(
        l10n.logout,
        style: TextStyle(color: context.colorScheme.error),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: context.colorScheme.error.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
