import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.termsOfService),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Terms of Service',
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
            title: '1. Acceptance of Terms',
            body:
                'By accessing or using the Delwaqty application and services, you agree '
                'to be bound by these Terms of Service. If you do not agree to these terms, '
                'please do not use our services. We reserve the right to modify these '
                'terms at any time, and continued use of the service constitutes acceptance '
                'of any changes.',
          ),
          _buildSection(
            context,
            title: '2. Service Description',
            body:
                'Delwaqty provides an on-demand platform connecting users with local '
                'restaurants, stores, and drivers for food delivery, package delivery, '
                'and ride-hailing services. We act as an intermediary between customers '
                'and service providers and do not directly provide delivery or transportation '
                'services ourselves.',
          ),
          _buildSection(
            context,
            title: '3. User Accounts',
            body:
                'You must create an account to use Delwaqty services. You are responsible '
                'for maintaining the confidentiality of your account credentials and for '
                'all activities that occur under your account. You agree to provide accurate '
                'and complete information during registration and to keep your account '
                'information up to date. You must be at least 18 years old to create an account.',
          ),
          _buildSection(
            context,
            title: '4. Orders & Payments',
            body:
                'When you place an order through Delwaqty, you agree to pay the total amount '
                'shown at checkout, including the item price, delivery fee, service fee, and '
                'any applicable taxes. Payments can be made via cash, credit/debit card, or '
                'your Delwaqty wallet. Prices may vary based on location, demand, and '
                'promotional offers. Refunds are subject to our refund policy.',
          ),
          _buildSection(
            context,
            title: '5. Ride & Delivery',
            body:
                'Ride and delivery services are provided by independent drivers and merchants. '
                'Delwaqty facilitates the connection but is not responsible for the quality, '
                'safety, or legality of the services provided. Estimated delivery and arrival '
                'times are approximate and not guaranteed. Users must provide accurate pickup '
                'and drop-off locations.',
          ),
          _buildSection(
            context,
            title: '6. Privacy',
            body:
                'Your use of Delwaqty is also governed by our Privacy Policy. By using our '
                'services, you consent to the collection and use of your personal information '
                'as described in the Privacy Policy. We collect data necessary to provide and '
                'improve our services, including location data for delivery and ride services.',
          ),
          _buildSection(
            context,
            title: '7. Limitation of Liability',
            body:
                'To the maximum extent permitted by law, Delwaqty shall not be liable for any '
                'indirect, incidental, special, or consequential damages arising out of or '
                'in connection with your use of our services. Our total liability shall not '
                'exceed the amount you paid for the specific service giving rise to the claim. '
                'We are not liable for delays, cancellations, or quality issues caused by '
                'third-party providers.',
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
