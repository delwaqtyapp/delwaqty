import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';

class AdminCollectionsPage extends ConsumerWidget {
  const AdminCollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final summaryAsync = ref.watch(adminCollectionSummaryProvider);
    final listAsync = ref.watch(adminCollectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regional Collections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(adminCollectionSummaryProvider);
              ref.invalidate(adminCollectionsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminCollectionSummaryProvider);
          ref.invalidate(adminCollectionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            summaryAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoaderCircular(),
                ),
              ),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.error,
                message: e.toString(),
                actionLabel: l10n.retry,
                onAction: () =>
                    ref.invalidate(adminCollectionSummaryProvider),
              ),
              data: (s) => Column(
                children: [
                  _MetricGrid(summary: s),
                  const SizedBox(height: 12),
                  PremiumCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reconciliation',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _ReconcileRow(
                          label: 'Total Collected',
                          value: s.total,
                          color: cs.primary,
                        ),
                        _ReconcileRow(
                          label: 'Approved Settlements',
                          value: -s.settled,
                          color: Colors.green,
                        ),
                        const Divider(),
                        _ReconcileRow(
                          label: 'Closing Outstanding',
                          value: s.outstanding,
                          color: s.outstanding > 0
                              ? Colors.orange
                              : Colors.green,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Collection Ledger',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            listAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoaderCircular(),
                ),
              ),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.error,
                message: e.toString(),
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(adminCollectionsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const PremiumEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No collections',
                    message: 'No received top-ups in this region yet.',
                  );
                }
                return Column(
                  children: [
                    for (final c in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PremiumCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${l10n.currencySymbol} ${c.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Account: ${c.accountId}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (c.reference != null)
                                      Text(
                                        'Ref: ${c.reference}',
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: c.status == 'settled'
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  c.status == 'settled'
                                      ? 'Settled'
                                      : 'Collected',
                                  style: TextStyle(
                                    color: c.status == 'settled'
                                        ? Colors.green
                                        : Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});
  final dynamic summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      ('Today', summary.today),
      ('Week', summary.week),
      ('Month', summary.month),
      ('Total', summary.total),
      ('Pending', summary.pending),
      ('Approved', summary.approved),
      ('Rejected', summary.rejected),
      ('Settled', summary.settled),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: items
          .map(
            (e) => PremiumCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    e.$1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    '${l10n.currencySymbol} ${e.$2.toStringAsFixed(2)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ReconcileRow extends StatelessWidget {
  const _ReconcileRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });
  final String label;
  final double value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = value < 0
        ? '- ${l10n.currencySymbol} ${value.abs().toStringAsFixed(2)}'
        : '${l10n.currencySymbol} ${value.toStringAsFixed(2)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
          Text(
            display,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
