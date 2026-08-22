import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

class AdminFinancialCenter extends ConsumerWidget {
  const AdminFinancialCenter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final revenueAsync = ref.watch(revenueBreakdownProvider);
    final commissionAsync = ref.watch(commissionSummaryProvider);
    final revenueOverviewAsync = ref.watch(revenueOverviewProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminFinancialCenter),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(revenueBreakdownProvider);
              ref.invalidate(commissionSummaryProvider);
              ref.invalidate(revenueOverviewProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(revenueBreakdownProvider);
          ref.invalidate(commissionSummaryProvider);
          ref.invalidate(revenueOverviewProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 68,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  children: [
                    _FinanceQuickAction(
                      icon: Icons.menu_book_rounded,
                      label: l10n.adminTransactionLedger,
                      color: const Color(0xFFFF9500),
                      onTap: () => context.push('/admin/transaction-ledger'),
                    ),
                    _FinanceQuickAction(
                      icon: Icons.percent_rounded,
                      label: l10n.adminCommissions,
                      color: const Color(0xFF5B3DF0),
                      onTap: () => context.push('/admin/commissions'),
                    ),
                    _FinanceQuickAction(
                      icon: Icons.account_balance_wallet_rounded,
                      label: l10n.adminWalletIntelligence,
                      color: const Color(0xFFAF52DE),
                      onTap: () => context.push('/admin/wallet-intelligence'),
                    ),
                    _FinanceQuickAction(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Top-Up Requests',
                      color: const Color(0xFF34C759),
                      onTap: () => context.push('/admin/topup-requests'),
                    ),
                    _FinanceQuickAction(
                      icon: Icons.receipt_long_rounded,
                      label: 'Collections',
                      color: const Color(0xFF00C7BE),
                      onTap: () => context.push('/admin/collections'),
                    ),
                    _FinanceQuickAction(
                      icon: Icons.account_balance_rounded,
                      label: 'Settlements',
                      color: const Color(0xFFFF3B30),
                      onTap: () => context.push('/admin/settlements'),
                    ),
                    _FinanceQuickAction(
                      icon: Icons.shield_rounded,
                      label: 'Grace',
                      color: const Color(0xFF5B3DF0),
                      onTap: () => context.push('/admin/grace-management'),
                    ),
                    _FinanceQuickAction(
                      icon: Icons.wallet_rounded,
                      label: 'Receiving',
                      color: const Color(0xFFFF9500),
                      onTap: () => context.push('/admin/receiving-wallets'),
                    ),
                    if ((ref.watch(adminIsOwnerProvider)).value ?? false)
                      _FinanceQuickAction(
                        icon: Icons.public_rounded,
                        label: 'Global Audit',
                        color: const Color(0xFF5B3DF0),
                        onTap: () => context.push('/admin/owner-dashboard'),
                      ),
                  ],
                ),
              ),
              AnimatedFadeIn(
                child: revenueAsync.when(
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
                      message: l10n.errorLoadingMetrics,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(revenueBreakdownProvider),
                    ),
                  ),
                  data: (revenue) => _buildRevenueHero(revenue, cs, context),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  l10n.revenueSummary,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              revenueOverviewAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (overview) => _buildRevenueOverviewCards(overview, cs, context),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  l10n.commissionRules,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              commissionAsync.when(
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
                    message: l10n.errorLoadingMetrics,
                    actionLabel: l10n.retry,
                    onAction: () => ref.invalidate(commissionSummaryProvider),
                  ),
                ),
                data: (summary) => _buildCommissionSection(summary, cs, context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueHero(RevenueOverview revenue, ColorScheme cs, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF5B3DF0), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: cs.onPrimary,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.currencySymbol} ${revenue.totalGmv.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.kpiTotalGmv,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueOverviewCards(RevenueOverview overview, ColorScheme cs, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      _MetricData(l10n.kpiTotalGmv, overview.totalGmv, const Color(0xFF5B3DF0)),
      _MetricData(l10n.kpiPlatformCommission, overview.totalCommission, const Color(0xFF34C759)),
      _MetricData(l10n.returnsLabel, overview.refundCount.toDouble(), const Color(0xFFFF3B30)),
      _MetricData(l10n.commissionRate7, overview.commission7pct, const Color(0xFF00C7BE)),
      _MetricData(l10n.commissionRate3, overview.commission3pct, const Color(0xFFFF9500)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 5 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: items
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
                              '${l10n.currencySymbol} ${item.value.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
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

  Widget _buildCommissionSection(CommissionSummary summary, ColorScheme cs, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _CommissionStatCard(
                label: l10n.total,
                value: summary.totalCommission,
                color: const Color(0xFF5B3DF0),
                context: context,
              ),
              const SizedBox(width: 12),
              _CommissionStatCard(
                label: l10n.pending,
                value: summary.pendingCommission,
                color: const Color(0xFFFF9500),
                context: context,
              ),
              const SizedBox(width: 12),
              _CommissionStatCard(
                label: l10n.realizedStat,
                value: summary.fulfilledCommission,
                color: const Color(0xFF34C759),
                context: context,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (summary.activeRules.isNotEmpty) ...[
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 250),
            child: PremiumCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activeRulesCount(summary.activeRules.length),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...summary.activeRules.take(10).map(
                    (rule) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: rule.rate > 0
                                  ? const Color(0xFF5B3DF0).withValues(alpha: 0.1)
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Text(
                              '${rule.rate.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: rule.rate > 0 ? const Color(0xFF5B3DF0) : cs.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${rule.entityKey} (${rule.entityType})',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _CommissionStatCard extends StatelessWidget {
  const _CommissionStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.context,
  });

  final String label;
  final double value;
  final Color color;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.currencySymbol} ${value.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceQuickAction extends StatelessWidget {
  const _FinanceQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
