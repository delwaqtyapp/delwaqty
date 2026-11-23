import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/features/admin/presentation/widgets/intelligence_stat_grid.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

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
        title: Text(l10n.regionalCollections),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
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
                message: appErrorText(context, e),
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(adminCollectionSummaryProvider),
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
                          l10n.reconciliation,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _ReconcileRow(
                          label: l10n.totalCollected,
                          value: s.total,
                          color: cs.primary,
                        ),
                        _ReconcileRow(
                          label: l10n.approvedSettlements,
                          value: -s.settled,
                          color: Colors.green,
                        ),
                        const Divider(),
                        _ReconcileRow(
                          label: l10n.closingOutstanding,
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
              l10n.collectionLedger,
              style: Theme.of(context).textTheme.titleMedium
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
                message: appErrorText(context, e),
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(adminCollectionsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: l10n.noCollections,
                    message: l10n.noCollectionsYet,
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
                                      '${l10n.account}: ${c.accountId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    if (c.reference != null)
                                      Text(
                                        'Ref: ${c.reference}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
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
                                      ? l10n.settled
                                      : l10n.collected,
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
    final cs = Theme.of(context).colorScheme;
    String fmt(double v) => '${l10n.currencySymbol} ${v.toStringAsFixed(2)}';
    // Shared responsive grid: content-driven tile heights, so nothing
    // clips at narrow widths or large text scales.
    return IntelligenceStatGrid(
      stats: [
        IntelligenceStat(
          title: l10n.today,
          value: fmt(summary.today as double),
          icon: Icons.today_rounded,
          color: AppColors.brandPurple,
        ),
        IntelligenceStat(
          title: l10n.periodWeek,
          value: fmt(summary.week as double),
          icon: Icons.date_range_rounded,
          color: cs.tertiary,
        ),
        IntelligenceStat(
          title: l10n.periodMonth,
          value: fmt(summary.month as double),
          icon: Icons.calendar_month_rounded,
          color: cs.primary,
        ),
        IntelligenceStat(
          title: l10n.total,
          value: fmt(summary.total as double),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.brandPurple,
        ),
        IntelligenceStat(
          title: l10n.pending,
          value: fmt(summary.pending as double),
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warningLight,
        ),
        IntelligenceStat(
          title: l10n.approved,
          value: fmt(summary.approved as double),
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.successLight,
        ),
        IntelligenceStat(
          title: l10n.rejected,
          value: fmt(summary.rejected as double),
          icon: Icons.cancel_outlined,
          color: AppColors.errorLight,
        ),
        IntelligenceStat(
          title: l10n.settled,
          value: fmt(summary.settled as double),
          icon: Icons.payments_outlined,
          color: AppColors.infoLight,
        ),
      ],
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
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
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
