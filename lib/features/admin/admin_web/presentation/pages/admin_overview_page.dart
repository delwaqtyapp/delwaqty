import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_overview.dart';
import 'package:delwaqty/features/admin/presentation/providers/admin_overview_providers.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_kpi_card.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_states.dart';

class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminOverviewStatsProvider);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Dashboard Overview',
            subtitle: 'Live platform counters at a glance',
          ),
          const SizedBox(height: 32),
          Expanded(
            child: statsAsync.when(
              loading: () => const AdminLoadingState(label: 'Loading live stats…'),
              error: (error, _) => AdminErrorState(
                message: 'Could not load dashboard stats.\n$error',
                onRetry: () => ref.invalidate(adminOverviewStatsProvider),
              ),
              data: (stats) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminOverviewStatsProvider);
                  await ref.read(adminOverviewStatsProvider.future);
                },
                child: _StatsGrid(stats: stats),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final AdminOverviewStats stats;

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
              label: 'Total Users',
              icon: Icons.people_rounded,
              color: AppColors.brandBlue,
            ),
            AdminKpiCard(
              value: '${stats.merchants}',
              label: 'Total Merchants',
              icon: Icons.store_rounded,
              color: AppColors.brandViolet,
            ),
            AdminKpiCard(
              value: '${stats.orders}',
              label: 'Total Orders',
              icon: Icons.shopping_bag_rounded,
              color: AppColors.successLight,
            ),
            AdminKpiCard(
              value: '${stats.drivers}',
              label: 'Active Drivers',
              icon: Icons.delivery_dining_rounded,
              color: AppColors.warningLight,
            ),
            AdminKpiCard(
              value: '${stats.serviceBookings}',
              label: 'Service Bookings',
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