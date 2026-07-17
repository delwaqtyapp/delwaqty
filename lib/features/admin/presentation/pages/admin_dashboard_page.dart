import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dashboardAsync = ref.watch(dashboardMetricsProvider);
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardMetricsProvider);
              ref.invalidate(recentActivityProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedFadeIn(
              child: Text(
                l10n.platformOverview,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            dashboardAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: AppLoaderCircular(),
                ),
              ),
              error: (e, _) => AnimatedFadeIn(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: PremiumEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingMetrics,
                      actionLabel: l10n.retry,
                      onAction: () =>
                          ref.invalidate(dashboardMetricsProvider),
                    ),
                  ),
                ),
              ),
              data: (dashboard) {
                if (dashboard == null) {
                  return AnimatedFadeIn(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: PremiumEmptyState(
                          icon: Icons.bar_chart_rounded,
                          title: l10n.noDataAvailable,
                          message: l10n.noDataAvailable,
                        ),
                      ),
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 3
                        : constraints.maxWidth > 600
                            ? 2
                            : 1;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.0,
                      children: [
                        _StatCard(
                          title: l10n.totalUsers,
                          value: dashboard.totalUsers.toString(),
                          icon: Icons.people_outline,
                          color: Colors.blue,
                        ),
                        _StatCard(
                          title: l10n.totalMerchants,
                          value: dashboard.totalMerchants.toString(),
                          icon: Icons.store_outlined,
                          color: Colors.green,
                        ),
                        _StatCard(
                          title: l10n.totalOrders,
                          value: dashboard.totalOrders.toString(),
                          icon: Icons.shopping_cart_outlined,
                          color: Colors.orange,
                        ),
                        _StatCard(
                          title: l10n.revenue,
                          value:
                              'SAR ${dashboard.totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.payments_outlined,
                          color: Colors.purple,
                        ),
                        _StatCard(
                          title: l10n.activeDrivers,
                          value: dashboard.activeDrivers.toString(),
                          icon: Icons.local_shipping_outlined,
                          color: Colors.teal,
                        ),
                        _StatCard(
                          title: l10n.pendingOrdersStat,
                          value: dashboard.pendingOrders.toString(),
                          icon: Icons.pending_outlined,
                          color: Colors.amber,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 200),
              child: Text(
                l10n.recentActivity,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            activityAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: AppLoaderCircular(),
                ),
              ),
              error: (e, _) => AnimatedFadeIn(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: PremiumEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.error,
                      message: l10n.errorLoadingActivity,
                      actionLabel: l10n.retry,
                      onAction: () =>
                          ref.invalidate(recentActivityProvider),
                    ),
                  ),
                ),
              ),
              data: (activities) {
                if (activities.isEmpty) {
                  return AnimatedFadeIn(
                    delay: const Duration(milliseconds: 300),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: PremiumEmptyState(
                          icon: Icons.history_rounded,
                          title: l10n.noRecentActivity,
                          message: l10n.noRecentActivity,
                        ),
                      ),
                    ),
                  );
                }
                return AnimatedFadeIn(
                  delay: const Duration(milliseconds: 300),
                  child: Card(
                    child: Column(
                      children: [
                        for (int i = 0;
                            i < activities.length && i < 10;
                            i++) ...[
                          ListTile(
                            leading: CircleAvatar(
                              child:
                                  Icon(_getActivityIcon(activities[i].action)),
                            ),
                            title: Text(activities[i].action),
                            subtitle: Text(
                              '${activities[i].resource} · ${_formatTime(activities[i].timestamp)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                          ),
                          if (i < activities.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String action) {
    if (action.toLowerCase().contains('create') ||
        action.toLowerCase().contains('register')) {
      return Icons.person_add;
    }
    if (action.toLowerCase().contains('order')) {
      return Icons.shopping_cart;
    }
    if (action.toLowerCase().contains('dispute') ||
        action.toLowerCase().contains('report')) {
      return Icons.warning_amber;
    }
    if (action.toLowerCase().contains('payout') ||
        action.toLowerCase().contains('payment')) {
      return Icons.payments;
    }
    return Icons.info_outline;
  }

  String _formatTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()} weeks ago';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
