import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
        title: const Text('Global Financial Audit'),
        actions: [
          IconButton(
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
              const _SectionTitle('Platform Collections (all regions)'),
              const SizedBox(height: 12),
              collections.when(
                loading: () =>
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: AppLoaderCircular())),
                error: (e, _) => PremiumCard(
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.error,
                    message: e.toString(),
                  ),
                ),
                data: (data) => _CollectionsSection(data: data, cs: cs, l10n: l10n),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Platform Settlements (all regions)'),
              const SizedBox(height: 12),
              settlements.when(
                loading: () =>
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: AppLoaderCircular())),
                error: (e, _) => PremiumCard(
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.error,
                    message: e.toString(),
                  ),
                ),
                data: (data) => _SettlementsSection(data: data, cs: cs, l10n: l10n),
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      );
}

class _CollectionsSection extends StatelessWidget {
  const _CollectionsSection({required this.data, required this.cs, required this.l10n});
  final Map<String, dynamic> data;
  final ColorScheme cs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final byRegion = (data['by_region'] as List?)?.cast<Map>() ?? [];
    final rows = (data['rows'] as List?)?.cast<Map>() ?? [];
    final sym = l10n.currencySymbol;
    String fmt(v) => '$sym ${(v is num ? v : 0).toStringAsFixed(2)}';

    final cards = [
      _Stat(l10n.total, fmt(summary['total']), const Color(0xFF5B3DF0)),
      _Stat('Settled', fmt(summary['settled']), const Color(0xFF34C759)),
      _Stat('Outstanding', fmt(summary['outstanding']), const Color(0xFFFF3B30)),
      _Stat('Today', fmt(summary['today']), const Color(0xFF00C7BE)),
      _Stat('Week', fmt(summary['week']), const Color(0xFFFF9500)),
      _Stat('Month', fmt(summary['month']), const Color(0xFFAF52DE)),
    ];

    return Column(
      children: [
        _StatGrid(cards: cards),
        const SizedBox(height: 12),
        if (byRegion.isNotEmpty) ...[
          Text('By region', style: Theme.of(context).textTheme.titleSmall),
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
                          region.length > 8 ? '${region.substring(0, 8)}…' : region,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        fmt(r['total']),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
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
          Text('Recent collections', style: Theme.of(context).textTheme.titleSmall),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
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
  const _SettlementsSection({required this.data, required this.cs, required this.l10n});
  final Map<String, dynamic> data;
  final ColorScheme cs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final byRegion = (data['by_region'] as List?)?.cast<Map>() ?? [];
    final rows = (data['rows'] as List?)?.cast<Map>() ?? [];
    final sym = l10n.currencySymbol;
    String fmt(v) => '$sym ${(v is num ? v : 0).toStringAsFixed(2)}';

    final cards = [
      _Stat(l10n.total, fmt(summary['total']), const Color(0xFF5B3DF0)),
      _Stat('Pending', fmt(summary['pending']), const Color(0xFFFF9500)),
      _Stat('Under Review', fmt(summary['under_review']), const Color(0xFF00C7BE)),
      _Stat('Approved', fmt(summary['approved']), const Color(0xFF34C759)),
      _Stat('Rejected', fmt(summary['rejected']), const Color(0xFFFF3B30)),
      _Stat('Outstanding', fmt(summary['outstanding']), const Color(0xFFAF52DE)),
    ];

    return Column(
      children: [
        _StatGrid(cards: cards),
        const SizedBox(height: 12),
        if (byRegion.isNotEmpty) ...[
          Text('By region', style: Theme.of(context).textTheme.titleSmall),
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
                          region.length > 8 ? '${region.substring(0, 8)}…' : region,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        fmt(r['total']),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
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
          Text('Recent settlements', style: Theme.of(context).textTheme.titleSmall),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth > 600 ? 6 : 2;
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: cards
              .map(
                (item) => PremiumCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded, color: item.color, size: 16),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.value,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
