import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

class PlatformIntelligenceDashboard extends ConsumerStatefulWidget {
  const PlatformIntelligenceDashboard({super.key});

  @override
  ConsumerState<PlatformIntelligenceDashboard> createState() =>
      _PlatformIntelligenceDashboardState();
}

class _PlatformIntelligenceDashboardState
    extends ConsumerState<PlatformIntelligenceDashboard> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final filter = ref.watch(adminTimeFilterProvider);
    final kpiAsync = ref.watch(platformKpiProvider);
    final alertsAsync = ref.watch(operationalAlertsProvider);
    final revenueAsync = ref.watch(revenueBreakdownProvider);
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminCommandCenter),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(platformKpiProvider);
              ref.invalidate(operationalAlertsProvider);
              ref.invalidate(revenueBreakdownProvider);
              ref.invalidate(recentActivityProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformKpiProvider);
          ref.invalidate(operationalAlertsProvider);
          ref.invalidate(revenueBreakdownProvider);
          ref.invalidate(recentActivityProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedFadeIn(child: _buildScopeRow(context)),
              const SizedBox(height: 12),
              AnimatedFadeIn(child: _buildTimeFilter(filter, cs)),
              const SizedBox(height: 20),
              kpiAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => AnimatedFadeIn(
                  child: PremiumCard(
                    child: PremiumEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingMetrics,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(platformKpiProvider),
                    ),
                  ),
                ),
                data: (kpi) => _buildKpiGroups(kpi, l10n, cs),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  l10n.revenueOverview,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              revenueAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => AnimatedFadeIn(
                  delay: const Duration(milliseconds: 180),
                  child: PremiumCard(
                    child: PremiumEmptyState(
                      icon: Icons.account_balance_wallet_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingMetrics,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(revenueBreakdownProvider),
                    ),
                  ),
                ),
                data: (revenue) => AnimatedFadeIn(
                  delay: const Duration(milliseconds: 180),
                  child: _buildRevenueSection(revenue, l10n, cs),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  l10n.operationalAlertsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              alertsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => AnimatedFadeIn(
                  delay: const Duration(milliseconds: 280),
                  child: PremiumCard(
                    child: PremiumEmptyState(
                      icon: Icons.warning_amber_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingMetrics,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(operationalAlertsProvider),
                    ),
                  ),
                ),
                data: (alerts) {
                  if (alerts.isEmpty) {
                    return AnimatedFadeIn(
                      delay: const Duration(milliseconds: 280),
                      child: PremiumCard(
                        child: PremiumEmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          title: l10n.noOperationalAlerts,
                          message: l10n.platformHealthy,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < alerts.length; i++)
                        AnimatedFadeIn(
                          delay: Duration(milliseconds: 280 + i * 50),
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: i < alerts.length - 1 ? 8 : 0,
                            ),
                            child: _AlertCard(alert: alerts[i], cs: cs),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  l10n.recentActivityTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              activityAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCircular(),
                  ),
                ),
                error: (e, _) => AnimatedFadeIn(
                  delay: const Duration(milliseconds: 320),
                  child: PremiumCard(
                    child: PremiumEmptyState(
                      icon: Icons.history_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingActivity,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(recentActivityProvider),
                    ),
                  ),
                ),
                data: (activities) {
                  if (activities.isEmpty) {
                    return AnimatedFadeIn(
                      delay: const Duration(milliseconds: 320),
                      child: PremiumCard(
                        child: PremiumEmptyState(
                          icon: Icons.history_rounded,
                          title: l10n.noRecentActivity,
                          message: l10n.noRecentActivity,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < activities.length && i < 8; i++)
                        AnimatedFadeIn(
                          delay: Duration(milliseconds: 320 + i * 50),
                          child: Padding(
                            padding: EdgeInsets.only(bottom: i < 7 ? 8 : 0),
                            child: _ActivityGlassTile(
                              activity: activities[i],
                              l10n: l10n,
                              cs: cs,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 360),
                child: Text(
                  l10n.quickActions,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final regionAsync = ref.watch(governoratesProvider);
    final scopeRegion = ref.watch(adminScopeRegionProvider);

    return Row(
      children: [
        const Icon(
          Icons.tune_rounded,
          size: 16,
          color: Color(0xFF5B3DF0),
        ),
        const SizedBox(width: 6),
        Text(
          l10n.regions,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: regionAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (regions) {
              return DropdownButtonFormField<String?>(
                initialValue: scopeRegion,
                isDense: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.allGovernorates),
                  ),
                  for (final r in regions.take(30))
                    DropdownMenuItem<String?>(
                      value: r.id,
                      child: Text(r.nameAr),
                    ),
                ],
                onChanged: (v) {
                  ref.read(adminScopeRegionProvider.notifier).state = v;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGroups(
    PlatformKpiSummary kpi,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final currency = l10n.currencySymbol;
    final groups = [
      (
        l10n.dashGroupPlatform,
        Icons.dashboard_outlined,
        const Color(0xFF007AFF),
        [
          _KpiItem(
            l10n.kpiTotalUsers,
            kpi.totalUsers.toString(),
            Icons.people_outline_rounded,
            const Color(0xFF4A90D9),
          ),
          _KpiItem(
            l10n.kpiActiveMerchants,
            kpi.activeMerchants.toString(),
            Icons.store_outlined,
            const Color(0xFF34C759),
          ),
          _KpiItem(
            l10n.kpiOnlineDrivers,
            kpi.onlineDrivers.toString(),
            Icons.local_shipping_rounded,
            const Color(0xFF007AFF),
          ),
          _KpiItem(
            l10n.kpiPendingVerification,
            kpi.pendingVerification.toString(),
            Icons.verified_user_outlined,
            const Color(0xFF8B5CF6),
          ),
        ],
      ),
      (
        l10n.dashGroupOperations,
        Icons.settings_outlined,
        const Color(0xFFFF9500),
        [
          _KpiItem(
            l10n.kpiTotalOrders,
            kpi.totalOrders.toString(),
            Icons.receipt_long_rounded,
            const Color(0xFFFF9500),
          ),
          _KpiItem(
            l10n.kpiActiveRides,
            kpi.activeRides.toString(),
            Icons.directions_car_rounded,
            const Color(0xFF00C7BE),
          ),
          _KpiItem(
            l10n.kpiOpenComplaints,
            kpi.openComplaints.toString(),
            Icons.warning_amber_rounded,
            const Color(0xFFFF3B30),
          ),
          _KpiItem(
            l10n.kpiActiveSanctions,
            kpi.activeSanctions.toString(),
            Icons.gavel_rounded,
            const Color(0xFFFF6482),
          ),
        ],
      ),
      (
        l10n.dashGroupFinancial,
        Icons.account_balance_rounded,
        const Color(0xFF5B3DF0),
        [
          _KpiItem(
            l10n.kpiTotalGmv,
            '$currency ${kpi.totalGmv.toStringAsFixed(0)}',
            Icons.payments_outlined,
            const Color(0xFFAF52DE),
          ),
          _KpiItem(
            l10n.kpiPlatformCommission,
            '$currency ${kpi.platformCommission.toStringAsFixed(0)}',
            Icons.account_balance_rounded,
            const Color(0xFF5B3DF0),
          ),
          _KpiItem(
            l10n.kpiWalletLiability,
            '$currency ${kpi.totalWalletLiability.toStringAsFixed(0)}',
            Icons.savings_outlined,
            const Color(0xFF14B8A6),
          ),
          _KpiItem(
            l10n.kpiPaymentFailures,
            kpi.paymentFailures.toString(),
            Icons.error_outline_rounded,
            const Color(0xFFE65100),
          ),
        ],
      ),
      (
        l10n.dashGroupRisk,
        Icons.security_outlined,
        const Color(0xFFFF3B30),
        [
          _KpiItem(
            l10n.kpiSosActive,
            kpi.sosActive.toString(),
            Icons.sos_rounded,
            const Color(0xFFFF3B30),
          ),
          _KpiItem(
            l10n.kpiPendingWithdrawals,
            kpi.pendingWithdrawals.toString(),
            Icons.currency_exchange_rounded,
            const Color(0xFF8B5CF6),
          ),
          _KpiItem(
            l10n.kpiCancelledOrders,
            kpi.cancelledOrders.toString(),
            Icons.cancel_outlined,
            const Color(0xFFFF9500),
          ),
          _KpiItem(
            l10n.kpiPendingOrders,
            kpi.pendingOrders.toString(),
            Icons.hourglass_empty_rounded,
            const Color(0xFF34C759),
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int g = 0; g < groups.length; g++)
          Padding(
            padding: EdgeInsets.only(top: g == 0 ? 0 : 16),
            child: _KpiGroup(
              title: groups[g].$1,
              icon: groups[g].$2,
              color: groups[g].$3,
              items: groups[g].$4,
              startDelay: g * 100,
              cs: cs,
            ),
          ),
      ],
    );
  }

  Widget _buildTimeFilter(AdminTimeFilter filter, ColorScheme cs) {
    final l10n = AppLocalizations.of(context);
    final periodLabels = {
      AdminTimePeriod.today: l10n.periodToday,
      AdminTimePeriod.week: l10n.periodWeek,
      AdminTimePeriod.month: l10n.periodMonth,
      AdminTimePeriod.quarter: l10n.periodQuarter,
      AdminTimePeriod.all: l10n.periodAll,
    };
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AdminTimePeriod.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = AdminTimePeriod.values[index];
          final isSelected = filter.period == period;
          return FilterChip(
            label: Text(
              periodLabels[period]!,
              style: TextStyle(
                color: isSelected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            selected: isSelected,
            onSelected: (_) {
              ref.read(adminTimeFilterProvider.notifier).state =
                  filter.copyWith(period: period);
            },
            selectedColor: cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueSection(
    RevenueOverview revenue,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final currency = l10n.currencySymbol;
    final items = [
      _RevenueItem(l10n.revenueGmv, revenue.totalGmv, const Color(0xFF5B3DF0)),
      _RevenueItem(
        l10n.revenuePlatformCommission,
        revenue.totalCommission,
        const Color(0xFF34C759),
      ),
      _RevenueItem(
        l10n.revenueRideGmv,
        revenue.commission7pct,
        const Color(0xFF00C7BE),
      ),
      _RevenueItem(
        l10n.revenueDeliveryGmv,
        revenue.commission3pct,
        const Color(0xFFFF6482),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
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
                  radius: AppSpacing.radiusCard,
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
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: item.color,
                          size: 16,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$currency ${item.amount.toStringAsFixed(0)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
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

  Widget _buildQuickActionsGrid(BuildContext context, AppLocalizations l10n) {
    final actions = [
      _QuickActionData(
        l10n.adminFinancialCenter,
        Icons.account_balance_rounded,
        const Color(0xFF5B3DF0),
        '/admin/financial-center',
      ),
      _QuickActionData(
        l10n.adminMembers,
        Icons.people_rounded,
        const Color(0xFF4A90D9),
        '/admin/members',
      ),
      _QuickActionData(
        l10n.adminDeliveryIntelligence,
        Icons.local_shipping_rounded,
        const Color(0xFF00897B),
        '/admin/delivery-intelligence',
      ),
      _QuickActionData(
        l10n.adminVerifications,
        Icons.verified_user_rounded,
        const Color(0xFF34C759),
        '/admin/verifications',
      ),
      _QuickActionData(
        l10n.adminMerchantIntelligence,
        Icons.store_outlined,
        const Color(0xFF34C759),
        '/admin/merchant-intelligence',
      ),
      _QuickActionData(
        l10n.complaints,
        Icons.warning_amber_rounded,
        const Color(0xFFFF3B30),
        '/admin/complaints',
      ),
      _QuickActionData(
        l10n.adminProviderIntelligence,
        Icons.engineering_outlined,
        const Color(0xFF0288D1),
        '/admin/provider-intelligence',
      ),
      _QuickActionData(
        l10n.sanctions,
        Icons.gavel_rounded,
        const Color(0xFFFF9500),
        '/admin/sanctions',
      ),
      _QuickActionData(
        l10n.adminWalletIntelligence,
        Icons.account_balance_wallet_rounded,
        const Color(0xFFAF52DE),
        '/admin/wallet-intelligence',
      ),
      _QuickActionData(
        l10n.liveTracking,
        Icons.map_rounded,
        const Color(0xFF00C7BE),
        '/admin/live-tracking',
      ),
      _QuickActionData(
        l10n.adminTransactionLedger,
        Icons.receipt_long_rounded,
        const Color(0xFFFF9500),
        '/admin/transaction-ledger',
      ),
      _QuickActionData(
        l10n.supportChat,
        Icons.chat_bubble_rounded,
        const Color(0xFF34C759),
        '/admin/support-chat',
      ),
      _QuickActionData(
        l10n.adminServicePerformance,
        Icons.analytics_rounded,
        const Color(0xFF5856D6),
        '/admin/service-performance',
      ),
      _QuickActionData(
        l10n.adminPushNotifications,
        Icons.campaign_rounded,
        const Color(0xFF34C759),
        '/admin/push-notifications',
      ),
      _QuickActionData(
        l10n.adminSettingsPage,
        Icons.settings_rounded,
        const Color(0xFFAF52DE),
        '/admin/settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 3;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return AnimatedFadeIn(
              delay: Duration(milliseconds: 400 + index * 50),
              child: GestureDetector(
                onTap: () => context.push(action.route),
                child: PremiumCard(
                  padding: const EdgeInsets.all(8),
                  radius: AppSpacing.radiusCard,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: action.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(action.icon, color: action.color, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action.label,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _KpiItem {
  const _KpiItem(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _KpiGroup extends StatelessWidget {
  const _KpiGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.startDelay,
    required this.cs,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<_KpiItem> items;
  final int startDelay;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          delay: Duration(milliseconds: startDelay),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 600
                    ? 3
                    : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                for (int i = 0; i < items.length; i++)
                  AnimatedFadeIn(
                    delay: Duration(milliseconds: startDelay + i * 40),
                    child: _KpiCard(item: items[i], cs: cs),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item, required this.cs});
  final _KpiItem item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      radius: AppSpacing.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueItem {
  const _RevenueItem(this.label, this.amount, this.color);
  final String label;
  final double amount;
  final Color color;
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.cs});
  final OperationalAlert alert;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(alert.severity);
    final severityIcon = _severityIcon(alert.severity);

    return PremiumCard(
      padding: const EdgeInsets.all(12),
      radius: AppSpacing.radiusCard,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(severityIcon, color: severityColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  alert.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (alert.count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                alert.count.toString(),
                style: TextStyle(
                  color: severityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFFF3B30);
      case 'medium':
      case 'warning':
        return const Color(0xFFFF9500);
      case 'low':
      case 'info':
        return const Color(0xFF007AFF);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return Icons.error_rounded;
      case 'medium':
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'low':
      case 'info':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}

class _QuickActionData {
  const _QuickActionData(this.label, this.icon, this.color, this.route);
  final String label;
  final IconData icon;
  final Color color;
  final String route;
}

class _ActivityGlassTile extends StatelessWidget {
  const _ActivityGlassTile({
    required this.activity,
    required this.l10n,
    required this.cs,
  });

  final AdminActivityLog activity;
  final AppLocalizations l10n;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final icon = _getActivityIcon(activity.action);
    final iconColor = _getActivityColor(activity.action);
    final timeText = _formatTime(activity.timestamp);

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: AppSpacing.radiusCard,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.action,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity.resource} Â· $timeText',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 18),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String action) {
    final a = action.toLowerCase();
    if (a.contains('create') || a.contains('register'))
      return Icons.person_add_rounded;
    if (a.contains('order')) return Icons.shopping_cart_rounded;
    if (a.contains('dispute') || a.contains('report'))
      return Icons.warning_amber_rounded;
    if (a.contains('payout') || a.contains('payment'))
      return Icons.payments_rounded;
    if (a.contains('ride') || a.contains('trip'))
      return Icons.directions_car_rounded;
    if (a.contains('delivery')) return Icons.inventory_2_rounded;
    if (a.contains('driver')) return Icons.person_rounded;
    return Icons.info_outline_rounded;
  }

  Color _getActivityColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('create') || a.contains('register'))
      return const Color(0xFF4A90D9);
    if (a.contains('order')) return const Color(0xFFFF9500);
    if (a.contains('dispute') || a.contains('report'))
      return const Color(0xFFFF3B30);
    if (a.contains('payout') || a.contains('payment'))
      return const Color(0xFF34C759);
    if (a.contains('ride') || a.contains('trip'))
      return const Color(0xFF00C7BE);
    if (a.contains('delivery')) return const Color(0xFFFF6482);
    if (a.contains('driver')) return const Color(0xFF007AFF);
    return cs.onSurfaceVariant;
  }

  String _formatTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes.toString());
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours.toString());
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays.toString());
    return l10n.weeksAgo;
  }
}
