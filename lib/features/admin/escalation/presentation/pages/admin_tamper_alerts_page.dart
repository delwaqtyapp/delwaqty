import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/escalation/presentation/escalation_providers.dart';
import 'package:delwaqty/features/admin/escalation/domain/entities/tamper_alert.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

class AdminTamperAlertsPage extends ConsumerWidget {
  const AdminTamperAlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clientPricedAsync = ref.watch(clientPricedAlertsProvider);
    final insuranceAsync = ref.watch(insuranceMismatchesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tamperAlertsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            l10n.clientPricedSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          clientPricedAsync.when(
            loading: () => const Center(child: AppLoaderCircular()),
            error: (e, _) => PremiumEmptyState(
              icon: Icons.error_outline,
              title: l10n.error,
              message: appErrorText(context, e),
            ),
            data: (alerts) => alerts.isEmpty
                ? PremiumEmptyState(
                    icon: Icons.verified_outlined,
                    title: l10n.noTamperSignals,
                    message: '',
                  )
                : Column(
                    children: [
                      for (final alert in alerts)
                        _ClientPricedTile(alert: alert, l10n: l10n),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.insuranceMismatchSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          insuranceAsync.when(
            loading: () => const Center(child: AppLoaderCircular()),
            error: (e, _) => PremiumEmptyState(
              icon: Icons.error_outline,
              title: l10n.error,
              message: appErrorText(context, e),
            ),
            data: (mismatches) => mismatches.isEmpty
                ? PremiumEmptyState(
                    icon: Icons.verified_outlined,
                    title: l10n.noTamperSignals,
                    message: '',
                  )
                : Column(
                    children: [
                      for (final mismatch in mismatches)
                        _InsuranceMismatchTile(mismatch: mismatch, l10n: l10n),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClientPricedTile extends StatelessWidget {
  const _ClientPricedTile({required this.alert, required this.l10n});
  final ClientPricedAlert alert;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pct = (alert.clientPricedRatio * 100).toStringAsFixed(1);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.point_of_sale_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.merchantName),
                  Text(
                    // Generated signature is (lines, pct, total).
                    l10n.clientPricedRatioLabel(
                      alert.clientPricedLines,
                      pct,
                      alert.totalLines,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceMismatchTile extends StatelessWidget {
  const _InsuranceMismatchTile({required this.mismatch, required this.l10n});
  final InsuranceMismatch mismatch;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.health_and_safety_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mismatch.merchantName),
                  Text(
                    l10n.claimedVsServer(
                      mismatch.claimedTotal.toStringAsFixed(2),
                      mismatch.serverTotal.toStringAsFixed(2),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  // Full sale id on its own line: a non-flex trailing
                  // Text would eat the narrow row width.
                  Text(
                    '#${mismatch.insuranceSaleId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
