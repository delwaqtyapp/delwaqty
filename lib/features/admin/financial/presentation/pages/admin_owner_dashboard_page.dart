import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/features/admin/presentation/widgets/intelligence_stat_grid.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

class AdminOwnerDashboardPage extends ConsumerWidget {
  const AdminOwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final collections = ref.watch(platformCollectionAuditProvider);
    final settlements = ref.watch(platformSettlementAuditProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.globalFinancialAudit),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(platformCollectionAuditProvider);
              ref.invalidate(platformSettlementAuditProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformCollectionAuditProvider);
          ref.invalidate(platformSettlementAuditProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(l10n.platformCollectionsAllRegions),
              const SizedBox(height: 12),
              collections.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => PremiumCard(
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.error,
                    message: appErrorText(context, e),
                  ),
                ),
                data: (data) =>
                    _CollectionsSection(data: data, cs: cs, l10n: l10n),
              ),
              const SizedBox(height: 24),
              _SectionTitle(l10n.platformSettlementsAllRegions),
              const SizedBox(height: 12),
              settlements.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => PremiumCard(
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.error,
                    message: appErrorText(context, e),
                  ),
                ),
                data: (data) =>
                    _SettlementsSection(data: data, cs: cs, l10n: l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.bold),
  );
}

class _CollectionsSection extends StatelessWidget {
  const _CollectionsSection({
    required this.data,
    required this.cs,
    required this.l10n,
  });
  final Map<String, dynamic> data;
  final ColorScheme cs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final byRegion = (data['by_region'] as List?)?.cast<Map>() ?? [];
    final rows = (data['rows'] as List?)?.cast<Map>() ?? [];
    final sym = l10n.currencySymbol;
    String fmt(v) => '$sym ${(v is num ? v : 0).toStringAsFixed(2)}';

    final cards = [
      _Stat(l10n.total, fmt(summary['total']), const Color(0xFF5B3DF0)),
      _Stat(l10n.settled, fmt(summary['settled']), const Color(0xFF34C759)),
      _Stat(
        l10n.outstanding,
        fmt(summary['outstanding']),
        const Color(0xFFFF3B30),
      ),
      _Stat(l10n.today, fmt(summary['today']), const Color(0xFF00C7BE)),
      _Stat(l10n.periodWeek, fmt(summary['week']), const Color(0xFFFF9500)),
      _Stat(l10n.periodMonth, fmt(summary['month']), const Color(0xFFAF52DE)),
    ];

    return Column(
      children: [
        _StatGrid(cards: cards),
        const SizedBox(height: 12),
        if (byRegion.isNotEmpty) ...[
          Text(l10n.byRegion, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          PremiumCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: byRegion.take(10).map((r) {
                final region = r['region_id']?.toString() ?? '—';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          region.length > 8
                              ? '${region.substring(0, 8)}…'
                              : region,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        fmt(r['total']),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (rows.isNotEmpty) ...[
          Text(
            l10n.recentCollections,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          PremiumCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: rows.take(12).map((r) {
                final amount = r['amount'];
                final status = r['status']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          status,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        fmt(amount),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _SettlementsSection extends StatelessWidget {
  const _SettlementsSection({
    required this.data,
    required this.cs,
    required this.l10n,
  });
  final Map<String, dynamic> data;
  final ColorScheme cs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final byRegion = (data['by_region'] as List?)?.cast<Map>() ?? [];
    final rows = (data['rows'] as List?)?.cast<Map>() ?? [];
    final sym = l10n.currencySymbol;
    String fmt(v) => '$sym ${(v is num ? v : 0).toStringAsFixed(2)}';

    final cards = [
      _Stat(l10n.total, fmt(summary['total']), const Color(0xFF5B3DF0)),
      _Stat(l10n.pending, fmt(summary['pending']), const Color(0xFFFF9500)),
      _Stat(
        l10n.underReview,
        fmt(summary['under_review']),
        const Color(0xFF00C7BE),
      ),
      _Stat(l10n.approved, fmt(summary['approved']), const Color(0xFF34C759)),
      _Stat(l10n.rejected, fmt(summary['rejected']), const Color(0xFFFF3B30)),
      _Stat(
        l10n.outstanding,
        fmt(summary['outstanding']),
        const Color(0xFFAF52DE),
      ),
    ];

    return Column(
      children: [
        _StatGrid(cards: cards),
        const SizedBox(height: 12),
        if (byRegion.isNotEmpty) ...[
          Text(l10n.byRegion, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          PremiumCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: byRegion.take(10).map((r) {
                final region = r['region_id']?.toString() ?? '—';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          region.length > 8
                              ? '${region.substring(0, 8)}…'
                              : region,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        fmt(r['total']),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (rows.isNotEmpty) ...[
          Text(
            l10n.recentSettlements,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          PremiumCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: rows.take(12).map((r) {
                final amount = r['amount'];
                final status = r['status']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          status,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        fmt(amount),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.cards});
  final List<_Stat> cards;
  @override
  Widget build(BuildContext context) {
    // Shared responsive grid: content-driven tile heights, so the metric
    // tiles never clip at narrow widths or large text scales.
    return IntelligenceStatGrid(
      wideColumns: 6,
      stats: [
        for (final item in cards)
          IntelligenceStat(
            title: item.label,
            value: item.value,
            icon: Icons.account_balance_wallet_rounded,
            color: item.color,
          ),
      ],
    );
  }
}
