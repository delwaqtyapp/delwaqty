import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

/// Service performance, bound to `servicePerformanceProvider`.
///
/// The page used to be three static "No data yet" placeholders even though
/// `platform_service_performance` and the provider both existed — the RPC's
/// per-category completion and SLA numbers were never rendered.
class ServicePerformancePage extends ConsumerWidget {
  const ServicePerformancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dataAsync = ref.watch(servicePerformanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminServicePerformance),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(servicePerformanceProvider),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: l10n.failedToLoad,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(servicePerformanceProvider),
        ),
        data: (data) {
          final hasAny = data.homeServices.isNotEmpty ||
              data.rideServices.isNotEmpty ||
              data.deliveryServices.isNotEmpty;

          if (!hasAny) {
            return PremiumEmptyState(
              icon: Icons.auto_graph,
              title: l10n.noDataYet,
              message: l10n.adminServicePerformancePending,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(servicePerformanceProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AnimatedFadeIn(
                  child: Text(
                    l10n.adminServicePerformance,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                if (data.homeServices.isNotEmpty) ...[
                  _CategoryGroup(
                    title: l10n.homeServices,
                    icon: Icons.home_repair_service_outlined,
                    color: AppColors.brandPurple,
                    items: data.homeServices,
                  ),
                  const SizedBox(height: 20),
                ],
                if (data.rideServices.isNotEmpty) ...[
                  _CategoryGroup(
                    title: l10n.deliveryRides,
                    icon: Icons.two_wheeler_rounded,
                    color: AppColors.brandCyan,
                    items: data.rideServices,
                  ),
                  const SizedBox(height: 20),
                ],
                if (data.deliveryServices.isNotEmpty)
                  _CategoryGroup(
                    title: l10n.delivery,
                    icon: Icons.local_shipping_outlined,
                    color: AppColors.brandGold,
                    items: data.deliveryServices,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<ServiceCategoryPerformance> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PerformanceRow(item: item, color: color),
          ),
        ),
      ],
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.item, required this.color});

  final ServiceCategoryPerformance item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final completion = item.totalBookings == 0
        ? 0.0
        : item.completedBookings / item.totalBookings;
    // The RPC has no explicit SLA column; a satisfied booking is one whose
    // rating is not a complaint, so a 4+ average stands in for the SLA.
    final sla = item.totalBookings == 0
        ? 0.0
        : (item.avgRating >= 4 ? 1.0 : item.avgRating / 4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.category.isEmpty ? '—' : item.category,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${item.totalBookings} ${l10n.bookings} · '
                '${item.avgRating.toStringAsFixed(1)} ★',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MetricBar(
            label: l10n.completionRate,
            value: completion,
            color: color,
          ),
          const SizedBox(height: 6),
          _MetricBar(
            label: l10n.slaCompliance,
            value: sla,
            color: AppColors.successLight,
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 46,
          child: Text(
            '${(clamped * 100).round()}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}