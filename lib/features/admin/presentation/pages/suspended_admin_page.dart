import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

/// Shown when a suspended admin signs in: their admin_management row is
/// inactive, so every backend call is denied and the normal shell would be
/// all zeros. Existing components only, no new styling.
class SuspendedAdminPage extends ConsumerWidget {
  const SuspendedAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PremiumEmptyState(
              icon: Icons.block_rounded,
              title: l10n.suspended,
              message: l10n.accountSuspendedBody,
              actionLabel: l10n.logout,
              onAction: () => ref.read(authStateProvider.notifier).signOut(),
            ),
          ),
        ),
      ),
    );
  }
}
