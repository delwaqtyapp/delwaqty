import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.helpCenter),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _buildSection(context, l10n, [
            _buildFaq(
              context,
              question: 'How to place an order?',
              answer:
                  'Simply browse restaurants or stores near you, add items to your cart, '
                  'confirm your delivery address, and tap Place Order. You can pay with '
                  'cash, wallet, or card depending on availability.',
            ),
            _buildFaq(
              context,
              question: 'How to track my order?',
              answer:
                  'Once your order is confirmed, you can track it in real-time from the '
                  'Orders tab. You will see the driver location, estimated arrival time, '
                  'and status updates at each step of the delivery.',
            ),
            _buildFaq(
              context,
              question: 'How to become a driver?',
              answer:
                  'Tap on the Driver option in the app and complete the registration form. '
                  'You will need to provide your ID, vehicle information, and driving license. '
                  'After verification, you can start accepting ride and delivery requests.',
            ),
            _buildFaq(
              context,
              question: 'How to add money to wallet?',
              answer:
                  'Go to the Wallet section from the sidebar menu and tap Top Up. '
                  'Choose your preferred payment method and enter the amount. '
                  'Your balance will be updated instantly after successful payment.',
            ),
            _buildFaq(
              context,
              question: 'How to contact support?',
              answer:
                  'You can reach our support team by emailing support@delwaqty.com or '
                  'through the Contact Us section in the app. Our team is available '
                  '24/7 to assist you with any issues or questions.',
            ),
            _buildFaq(
              context,
              question: 'How to report a problem?',
              answer:
                  'Go to your order history, select the relevant order, and tap '
                  'Report Problem. Choose the issue category, add a description, '
                  'and our team will review and respond as quickly as possible.',
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    AppLocalizations l10n,
    List<Widget> children,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildFaq(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const Border(),
      title: Text(
        question,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Text(
          answer,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
