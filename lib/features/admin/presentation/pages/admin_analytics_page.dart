import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';

class AdminAnalyticsPage extends ConsumerWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final revenueAsync = ref.watch(revenueChartProvider(30));
    final peakHoursAsync = ref.watch(peakHoursProvider);
    final topMerchantsAsync = ref.watch(topMerchantsProvider);
    final driverPerfAsync = ref.watch(driverPerformanceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.analytics)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RevenueOverviewSection(l10n: l10n, metricsAsync: metricsAsync),
            const SizedBox(height: 24),
            _RevenueChartSection(l10n: l10n, revenueAsync: revenueAsync),
            const SizedBox(height: 24),
            _PeakHoursSection(l10n: l10n, peakHoursAsync: peakHoursAsync, cs: cs),
            const SizedBox(height: 24),
            _TopMerchantsSection(l10n: l10n, topMerchantsAsync: topMerchantsAsync),
            const SizedBox(height: 24),
            _DriverPerformanceSection(l10n: l10n, driverPerfAsync: driverPerfAsync),
          ],
        ),
      ),
    );
  }
}

// ─── Revenue Overview ────────────────────────────────────────

class _RevenueOverviewSection extends StatelessWidget {
  const _RevenueOverviewSection({
    required this.l10n,
    required this.metricsAsync,
  });

  final AppLocalizations l10n;
  final AsyncValue metricsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          child: Text(
            l10n.revenueOverview,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 80),
          child: GlassCard(
            borderRadius: 20,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90D9), Color(0xFFAF52DE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: metricsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.noDataYet)),
                data: (metrics) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: Theme.of(context).colorScheme.onPrimary, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.currencySymbol} ${metrics.totalRevenue.toStringAsFixed(2)}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.revenueChart} • ${metrics.completedDeliveries + metrics.totalRides} ${l10n.orders}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Revenue Chart ───────────────────────────────────────────

class _RevenueChartSection extends StatelessWidget {
  const _RevenueChartSection({
    required this.l10n,
    required this.revenueAsync,
  });

  final AppLocalizations l10n;
  final AsyncValue<List> revenueAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 130),
          child: Text(
            l10n.orderTrends,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 160),
          child: GlassCard(
            borderRadius: 20,
            child: Container(
              height: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9500), Color(0xFFFF3B30)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: revenueAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.noDataYet)),
                data: (revenueList) {
                  if (revenueList.isEmpty) {
                    return Center(child: Text(l10n.zeroOrdersToday));
                  }
                  final maxAmount = revenueList
                      .map((r) => r.amount as double)
                      .reduce((a, b) => a > b ? a : b);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.currencySymbol} ${revenueList.fold(0.0, (sum, r) => sum + (r.amount as double)).toStringAsFixed(2)}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.days} 30',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: revenueList.reversed.take(14).toList().reversed.map((r) {
                            final amount = r.amount as double;
                            final height = maxAmount > 0
                                ? ((amount / maxAmount) * 80)
                                : 0.0;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: Container(
                                  height: height.clamp(2.0, 80.0),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: 0.7),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Peak Hours ──────────────────────────────────────────────

class _PeakHoursSection extends StatelessWidget {
  const _PeakHoursSection({
    required this.l10n,
    required this.peakHoursAsync,
    required this.cs,
  });

  final AppLocalizations l10n;
  final AsyncValue<List> peakHoursAsync;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 190),
          child: Text(
            l10n.peakHours,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 220),
          child: peakHoursAsync.when(
            loading: () => const GlassCard(
              borderRadius: 20,
              child: SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
            ),
            error: (_, __) => _PeerMetricCard(
              label: l10n.peakHours,
              value: '00:00 - 00:00',
              icon: Icons.access_time_rounded,
              color: const Color(0xFF00C7BE),
              cs: cs,
            ),
            data: (hours) {
              final ml = MaterialLocalizations.of(context);
              final topHours = hours.take(3).map((h) {
                final hour = h['hour'] as int;
                final formatted = ml.formatTimeOfDay(
                  TimeOfDay(hour: hour, minute: 0),
                );
                return formatted;
              }).join(' • ');
              return _PeerMetricCard(
                label: '${l10n.peakHours} (${hours.length} ${l10n.days})',
                value: topHours.isNotEmpty ? topHours : '00:00 - 00:00',
                icon: Icons.access_time_rounded,
                color: const Color(0xFF00C7BE),
                cs: cs,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Top Merchants ───────────────────────────────────────────

class _TopMerchantsSection extends StatelessWidget {
  const _TopMerchantsSection({
    required this.l10n,
    required this.topMerchantsAsync,
  });

  final AppLocalizations l10n;
  final AsyncValue<List> topMerchantsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 250),
          child: Text(
            l10n.topMerchants,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 280),
          child: GlassCard(
            borderRadius: 20,
            child: topMerchantsAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => PremiumEmptyState(
                icon: Icons.store_outlined,
                title: l10n.noDataYet,
                message: l10n.merchantPerformancePlaceholder,
              ),
              data: (merchants) {
                if (merchants.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.store_outlined,
                    title: l10n.noDataYet,
                    message: l10n.merchantPerformancePlaceholder,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: merchants.take(5).map((m) {
                      final name = m['name'] as String? ?? l10n.unknown;
                      final revenue = (m['total_revenue'] as num?)?.toDouble() ?? 0;
                      final deliveries = m['total_deliveries'] as int? ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(name, style: AppTextStyles.bodyLarge),
                        subtitle: Text(
                          '$deliveries ${l10n.orders}',
                          style: AppTextStyles.bodySmall,
                        ),
                        trailing: Text(
                          '${l10n.currencySymbol} ${revenue.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Driver Performance ──────────────────────────────────────

class _DriverPerformanceSection extends StatelessWidget {
  const _DriverPerformanceSection({
    required this.l10n,
    required this.driverPerfAsync,
  });

  final AppLocalizations l10n;
  final AsyncValue<List> driverPerfAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 310),
          child: Text(
            l10n.driverPerformance,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 340),
          child: GlassCard(
            borderRadius: 20,
            child: driverPerfAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => PremiumEmptyState(
                icon: Icons.speed_rounded,
                title: l10n.noDataYet,
                message: l10n.driverPerformancePlaceholder,
              ),
              data: (drivers) {
                if (drivers.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.speed_rounded,
                    title: l10n.noDataYet,
                    message: l10n.driverPerformancePlaceholder,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: drivers.take(5).map((d) {
final name = d['driver_name'] as String? ??
                        d['full_name'] as String? ??
                        l10n.unknown;
                      final completed = d['completed'] as int? ?? 0;
                      final revenue = (d['total_revenue'] as num?)?.toDouble() ?? 0;
                      final rating = (d['rating'] as num?)?.toDouble() ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .tertiaryContainer,
                          child: Icon(
                            Icons.person_rounded,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                        ),
                        title: Text(name, style: AppTextStyles.bodyLarge),
                        subtitle: Text(
                          '$completed ${l10n.orders} • ⭐ ${rating.toStringAsFixed(1)}',
                          style: AppTextStyles.bodySmall,
                        ),
                        trailing: Text(
                          '${l10n.currencySymbol} ${revenue.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helper Metric Card ──────────────────────────────────────

class _PeerMetricCard extends StatelessWidget {
  const _PeerMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.cs,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
