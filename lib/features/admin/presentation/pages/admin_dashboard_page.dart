import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dashboardAsync = ref.watch(dashboardMetricsProvider);
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(recentActivityProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedFadeIn(
                    child: Text(
                      l10n.adminDashboard,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      ref.invalidate(dashboardMetricsProvider);
                      ref.invalidate(recentActivityProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 80),
                child: Text(
                  l10n.platformOverview,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 20),
              dashboardAsync.when(
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
                      onAction: () => ref.invalidate(dashboardMetricsProvider),
                    ),
                  ),
                ),
                data: (dashboard) {
                  return _buildStatsGrid(dashboard, l10n, cs);
                },
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  l10n.quickActions,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(context, l10n, cs),
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
              const SizedBox(height: 12),
              activityAsync.when(
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
                      message: l10n.errorLoadingActivity,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(recentActivityProvider),
                    ),
                  ),
                ),
                data: (activities) {
                  if (activities.isEmpty) {
                    return AnimatedFadeIn(
                      delay: const Duration(milliseconds: 250),
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
                          delay: Duration(milliseconds: 250 + i * 50),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    AdminDashboardMetrics dashboard,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return LayoutBuilder(
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
            _StatPremiumCard(
              title: l10n.totalUsers,
              value: dashboard.totalUsers.toString(),
              icon: Icons.people_outline_rounded,
              color: const Color(0xFF4A90D9),
              cs: cs,
            ),
            _StatPremiumCard(
              title: l10n.totalMerchants,
              value: dashboard.totalMerchants.toString(),
              icon: Icons.store_outlined,
              color: const Color(0xFF34C759),
              cs: cs,
            ),
            _StatPremiumCard(
              title: l10n.totalOrders,
              value: dashboard.pendingOrders.toString(),
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFFF9500),
              cs: cs,
            ),
            _StatPremiumCard(
              title: l10n.revenue,
              value: 'ج.م ${dashboard.totalRevenue.toStringAsFixed(0)}',
              icon: Icons.payments_outlined,
              color: const Color(0xFFAF52DE),
              cs: cs,
            ),
            _StatPremiumCard(
              title: l10n.activeDrivers,
              value: dashboard.activeDrivers.toString(),
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF007AFF),
              cs: cs,
            ),
            _StatPremiumCard(
              title: l10n.pendingOrdersStat,
              value: dashboard.pendingOrders.toString(),
              icon: Icons.pending_outlined,
              color: const Color(0xFFFF3B30),
              cs: cs,
            ),
            _StatPremiumCard(
              title: l10n.totalRides,
              value: dashboard.totalRides.toString(),
              icon: Icons.directions_car_rounded,
              color: const Color(0xFF00C7BE),
              cs: cs,
            ),
            _StatPremiumCard(
              title: l10n.totalDeliveries,
              value: dashboard.totalDeliveries.toString(),
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFFFF6482),
              cs: cs,
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsGrid(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final actions = [
      _QuickActionData(
        l10n.verificationRequests,
        Icons.verified_user_outlined,
        const Color(0xFF34C759),
        '/admin/verifications',
      ),
_QuickActionData(
          l10n.userManagement,
          Icons.people_outline_rounded,
          const Color(0xFF4A90D9),
          '/admin/members',
        ),
      _QuickActionData(
        l10n.merchantManagement,
        Icons.store_outlined,
        const Color(0xFF34C759),
        '/admin/merchants',
      ),
      _QuickActionData(
        l10n.orderManagement,
        Icons.receipt_long_rounded,
        const Color(0xFFFF9500),
        '/admin/orders',
      ),
      _QuickActionData(
        l10n.admin,
        Icons.directions_car_rounded,
        const Color(0xFF007AFF),
        '/admin/drivers',
      ),
      _QuickActionData(
        l10n.delivery,
        Icons.inventory_2_rounded,
        const Color(0xFFFF6482),
        '/admin/deliveries',
      ),
      _QuickActionData(
        l10n.complaintsManagement,
        Icons.warning_amber_rounded,
        const Color(0xFFFF3B30),
        '/admin/complaints',
      ),
      _QuickActionData(
        l10n.sanctionsManagement,
        Icons.gavel_rounded,
        const Color(0xFFFF9500),
        '/admin/sanctions',
      ),
      _QuickActionData(
        l10n.liveTracking,
        Icons.map_rounded,
        const Color(0xFF00C7BE),
        '/admin/live-tracking',
      ),
      _QuickActionData(
        l10n.supportChat,
        Icons.chat_bubble_rounded,
        const Color(0xFF34C759),
        '/admin/support-chat',
      ),
      _QuickActionData(
        l10n.settings,
        Icons.settings_rounded,
        const Color(0xFFAF52DE),
        '/admin/settings',
      ),
      _QuickActionData(
        l10n.analytics,
        Icons.analytics_rounded,
        const Color(0xFF5856D6),
        '/admin/analytics',
      ),
      _QuickActionData(
        l10n.pushNotificationsTitle,
        Icons.notifications_active_rounded,
        const Color(0xFF34C759),
        '/admin/push-notifications',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
            ? 4
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
              delay: Duration(milliseconds: 100 + index * 50),
              child: _QuickActionCard(
                data: action,
                cs: cs,
                onTap: () => context.go(action.route),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickActionData {
  const _QuickActionData(this.label, this.icon, this.color, this.route);
  final String label;
  final IconData icon;
  final Color color;
  final String route;
}

class _StatPremiumCard extends StatelessWidget {
  const _StatPremiumCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.cs,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.data,
    required this.cs,
    required this.onTap,
  });

  final _QuickActionData data;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: PremiumCard(
        padding: const EdgeInsets.all(8),
        radius: AppSpacing.radiusCard,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: data.color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              data.label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityGlassTile extends StatelessWidget {
  const _ActivityGlassTile({
    required this.activity,
    required this.l10n,
    required this.cs,
  });

  final dynamic activity;
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
                  '${activity.resource} · $timeText',
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
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
