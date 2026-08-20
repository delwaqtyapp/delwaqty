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
              question: l10n.faqQuestion1,
              answer: l10n.faqAnswer1,
            ),
            _buildFaq(
              context,
              question: l10n.faqQuestion2,
              answer: l10n.faqAnswer2,
            ),
            _buildFaq(
              context,
              question: l10n.faqQuestion3,
              answer: l10n.faqAnswer3,
            ),
            _buildFaq(
              context,
              question: l10n.faqQuestion4,
              answer: l10n.faqAnswer4,
            ),
            _buildFaq(
              context,
              question: l10n.faqQuestion5,
              answer: l10n.faqAnswer5,
            ),
            _buildFaq(
              context,
              question: l10n.faqQuestion6,
              answer: l10n.faqAnswer6,
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
