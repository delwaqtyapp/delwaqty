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
    // Compute the percent from the same two numbers shown in the row
    // so the admin never sees contradictory figures.
    final ratio = alert.totalLines > 0
        ? alert.clientPricedLines / alert.totalLines
        : alert.clientPricedRatio;
    final pct = (ratio * 100).toStringAsFixed(1);
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
