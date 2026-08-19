import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

class ServicePerformancePage extends ConsumerWidget {
  const ServicePerformancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminServicePerformance)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedFadeIn(
              child: Text(
                l10n.adminServicePerformance,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            PremiumEmptyState(
              icon: Icons.auto_graph,
              title: l10n.noDataYet,
              message: l10n.adminServicePerformancePending,
            ),
            const SizedBox(height: 24),
            _ServiceCompletionSection(l10n: l10n),
            const SizedBox(height: 24),
            _SLASection(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _ServiceCompletionSection extends StatelessWidget {
  const _ServiceCompletionSection({
    required this.l10n,
  });

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          child: Text(
            l10n.adminServiceCompletion,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        PremiumEmptyState(
          icon: Icons.check_circle_outline,
          title: l10n.noDataYet,
          message: l10n.adminServiceCompletionPending,
        ),
      ],
    );
  }
}

class _SLASection extends StatelessWidget {
  const _SLASection({
    required this.l10n,
  });

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          child: Text(
            l10n.adminSLA,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        PremiumEmptyState(
          icon: Icons.schedule,
          title: l10n.noDataYet,
          message: l10n.adminSLAPlaceholder,
        ),
      ],
    );
  }
}