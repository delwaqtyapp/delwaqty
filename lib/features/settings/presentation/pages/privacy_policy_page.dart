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
            l10n.privacyPolicy,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.ppLastUpdated,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: l10n.ppSection1Title,
            body: l10n.ppSection1Body,
          ),
          _buildSection(
            context,
            title: l10n.ppSection2Title,
            body: l10n.ppSection2Body,
          ),
          _buildSection(
            context,
            title: l10n.ppSection3Title,
            body: l10n.ppSection3Body,
          ),
          _buildSection(
            context,
            title: l10n.ppSection4Title,
            body: l10n.ppSection4Body,
          ),
          _buildSection(
            context,
            title: l10n.ppSection5Title,
            body: l10n.ppSection5Body,
          ),
          _buildSection(
            context,
            title: l10n.ppSection6Title,
            body: l10n.ppSection6Body,
          ),
          _buildSection(
            context,
            title: l10n.ppSection7Title,
            body: l10n.ppSection7Body,
          ),
          _buildSection(
            context,
            title: l10n.ppSection8Title,
            body: l10n.ppSection8Body,
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
