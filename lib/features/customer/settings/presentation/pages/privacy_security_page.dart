import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/change_password_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/fingerprint_login_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/two_factor_auth_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/login_activity_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/data_privacy_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/location_sharing_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/notification_preferences_page.dart';

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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(l10n.twoFactorAuth),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TwoFactorAuthPage()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.fingerprint_rounded),
              title: Text(l10n.fingerprintLogin),
              subtitle: Text(l10n.fingerprintLoginDescription),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FingerprintLoginPage(),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(l10n.loginActivity),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginActivityPage()),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, l10n.privacy, [
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: Text(l10n.dataPrivacy),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataPrivacyPage()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(l10n.locationSharing),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocationSharingPage()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.notificationPreferences),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPreferencesPage()),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
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
