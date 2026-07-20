import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/merchant/merchant_module.dart';
import 'package:delwaqty/features/merchant/domain/entities/merchant_stats.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _merchantIdProvider = Provider<String>((_) => 'current-merchant-id');

final _statsProvider = FutureProvider<MerchantStats>((ref) async {
  final repo = ref.watch(merchantDashboardRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  return repo.getMerchantStats(merchantId);
});

class MerchantDashboardPage extends ConsumerStatefulWidget {
  const MerchantDashboardPage({super.key});

  @override
  ConsumerState<MerchantDashboardPage> createState() =>
      _MerchantDashboardPageState();
}

class _MerchantDashboardPageState
    extends ConsumerState<MerchantDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(_statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.merchantDashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_statsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_statsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedFadeIn(
                child: Text(
                  l10n.overview,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              statsAsync.when(
                loading: () => _buildStatsShimmer(),
                error: (e, _) => AnimatedFadeIn(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: PremiumEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: l10n.error,
                        message: l10n.errorLoading,
                        actionLabel: l10n.retry,
                        onAction: () => ref.invalidate(_statsProvider),
                      ),
                    ),
                  ),
                ),
                data: (stats) => _buildStatsGrid(context, stats),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  l10n.quickActions,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 300),
                child: _buildQuickActions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsShimmer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: List.generate(4, (_) => const ShimmerCard(height: 80)),
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, MerchantStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _StatCard(
              title: AppLocalizations.of(context).todayOrders,
              value: stats.todayOrders.toString(),
              icon: Icons.shopping_cart_outlined,
              color: Colors.blue,
            ),
            _StatCard(
              title: AppLocalizations.of(context).revenue,
              value: '${AppLocalizations.of(context).currencySymbol} ${stats.todayRevenue.toStringAsFixed(0)}',
              icon: Icons.payments_outlined,
              color: Colors.green,
            ),
            _StatCard(
              title: AppLocalizations.of(context).pending,
              value: stats.pendingOrders.toString(),
              icon: Icons.pending_outlined,
              color: Colors.orange,
            ),
            _StatCard(
              title: AppLocalizations.of(context).rating,
              value: stats.averageRating.toStringAsFixed(1),
              icon: Icons.star_outline_rounded,
              color: Colors.amber,
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(AppLocalizations.of(context).viewOrders),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/merchant-dashboard/orders'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(AppLocalizations.of(context).manageProducts),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/merchant-dashboard/products'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: Text(AppLocalizations.of(context).createOffer),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
        ],
      ),
    );
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
