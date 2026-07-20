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
            l10n.termsOfService,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tosLastUpdated,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: l10n.tosSection1Title,
            body: l10n.tosSection1Body,
          ),
          _buildSection(
            context,
            title: l10n.tosSection2Title,
            body: l10n.tosSection2Body,
          ),
          _buildSection(
            context,
            title: l10n.tosSection3Title,
            body: l10n.tosSection3Body,
          ),
          _buildSection(
            context,
            title: l10n.tosSection4Title,
            body: l10n.tosSection4Body,
          ),
          _buildSection(
            context,
            title: l10n.tosSection5Title,
            body: l10n.tosSection5Body,
          ),
          _buildSection(
            context,
            title: l10n.tosSection6Title,
            body: l10n.tosSection6Body,
          ),
          _buildSection(
            context,
            title: l10n.tosSection7Title,
            body: l10n.tosSection7Body,
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
