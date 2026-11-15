import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_overview.dart';
import 'package:delwaqty/features/admin/presentation/providers/admin_overview_providers.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_kpi_card.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_states.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(adminOverviewStatsProvider);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: l10n.adminDashboardOverview,
            subtitle: l10n.adminDashboardOverviewSubtitle,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: statsAsync.when(
              loading: () => AdminLoadingState(label: l10n.adminLoadingLiveStats),
              error: (error, _) => AdminErrorState(
                message: appErrorText(context, error),
                onRetry: () => ref.invalidate(adminOverviewStatsProvider),
              ),
              data: (stats) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminOverviewStatsProvider);
                  await ref.read(adminOverviewStatsProvider.future);
                },
                child: _StatsGrid(stats: stats, l10n: l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.l10n});

  final AdminOverviewStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _crossAxisCount(constraints.maxWidth);
        return GridView(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            mainAxisExtent: 116,
          ),
          children: [
            AdminKpiCard(
              value: '${stats.users}',
              label: l10n.adminTotalUsers,
              icon: Icons.people_rounded,
              color: AppColors.brandBlue,
            ),
            AdminKpiCard(
              value: '${stats.merchants}',
              label: l10n.adminTotalMerchants,
              icon: Icons.store_rounded,
              color: AppColors.brandViolet,
            ),
            AdminKpiCard(
              value: '${stats.orders}',
              label: l10n.adminTotalOrders,
              icon: Icons.shopping_bag_rounded,
              color: AppColors.successLight,
            ),
            AdminKpiCard(
              value: '${stats.drivers}',
              label: l10n.adminActiveDrivers,
              icon: Icons.delivery_dining_rounded,
              color: AppColors.warningLight,
            ),
            AdminKpiCard(
              value: '${stats.serviceBookings}',
              label: l10n.adminServiceBookings,
              icon: Icons.home_repair_service_rounded,
              color: AppColors.brandCyan,
            ),
          ],
        );
      },
    );
  }

  int _crossAxisCount(double width) {
    if (width > 1200) return 5;
    if (width > 800) return 3;
    return 2;
  }
}