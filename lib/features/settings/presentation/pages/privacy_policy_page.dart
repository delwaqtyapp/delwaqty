import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacyPolicy),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Privacy Policy',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: January 1, 2025',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: '1. Information We Collect',
            body:
                'We collect information you provide directly, including your name, email '
                'address, phone number, payment information, and delivery addresses. We '
                'also collect device information such as your device type, operating system, '
                'and unique device identifiers. When you use our services, we automatically '
                'collect location data and usage information such as order history and '
                'preferences.',
          ),
          _buildSection(
            context,
            title: '2. How We Use Your Information',
            body:
                'We use your information to provide, maintain, and improve our services, '
                'process transactions, send order updates and notifications, personalize '
                'your experience, detect and prevent fraud, and communicate with you about '
                'promotions and updates. We may also use aggregated and anonymized data '
                'for analytics and service improvement.',
          ),
          _buildSection(
            context,
            title: '3. Location Data',
            body:
                'Delwaqty collects and uses your location data to provide delivery and '
                'ride-hailing services. We access your location in the foreground when '
                'you request a service and may collect approximate location in the '
                'background for service optimization. You can control location access '
                'through your device settings, but disabling location may limit the '
                'functionality of our services.',
          ),
          _buildSection(
            context,
            title: '4. Data Sharing',
            body:
                'We share your information with drivers and merchants only as necessary '
                'to fulfill your orders (e.g., your name and delivery address for delivery, '
                'pickup location for rides). We may share data with payment processors, '
                'cloud service providers, and analytics services. We do not sell your '
                'personal information to third parties for their marketing purposes.',
          ),
          _buildSection(
            context,
            title: '5. Data Security',
            body:
                'We implement industry-standard security measures to protect your personal '
                'information, including encryption in transit and at rest, secure servers, '
                'and regular security audits. While we strive to protect your data, no '
                'method of electronic transmission or storage is 100% secure, and we '
                'cannot guarantee absolute security.',
          ),
          _buildSection(
            context,
            title: '6. Your Rights',
            body:
                'You have the right to access, correct, or delete your personal information '
                'at any time through the app settings. You can also request a copy of your '
                'data, opt out of marketing communications, and control your privacy '
                'preferences. To exercise these rights, contact us at support@delwaqty.com.',
          ),
          _buildSection(
            context,
            title: "7. Children's Privacy",
            body:
                'Delwaqty services are not intended for individuals under the age of 18. '
                'We do not knowingly collect personal information from children. If we '
                'become aware that a child has provided us with personal information, we '
                'will take steps to delete such information promptly.',
          ),
          _buildSection(
            context,
            title: '8. Changes to Policy',
            body:
                'We may update this Privacy Policy from time to time to reflect changes '
                'in our practices or legal requirements. We will notify you of any '
                'material changes by posting the updated policy in the app and via email '
                'or push notification. Your continued use of the service after changes '
                'constitutes acceptance of the updated policy.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
