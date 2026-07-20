import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class PrivacySecurityPage extends StatelessWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacySecurity),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(context, l10n.security, [
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(l10n.changePassword),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showComingSoon(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(l10n.twoFactorAuth),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showComingSoon(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(l10n.loginActivity),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showComingSoon(context),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, l10n.privacy, [
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: Text(l10n.dataPrivacy),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showComingSoon(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(l10n.locationSharing),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showComingSoon(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.notificationPreferences),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showComingSoon(context),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    context.showAppSnackBar(l10n.comingSoon);
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
