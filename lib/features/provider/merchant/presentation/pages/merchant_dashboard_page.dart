import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_stats.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/availability/presentation/providers/provider_availability_providers.dart';
import 'package:delwaqty/services/realtime/realtime_channel_constants.dart';
import 'package:delwaqty/services/realtime/realtime_service.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

final _merchantIdProvider = providerMerchantIdProvider;

final _statsProvider = FutureProvider<MerchantStats>((ref) async {
  final repo = ref.watch(merchantDashboardRepositoryProvider);
  final merchantId = await ref.watch(_merchantIdProvider.future);
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
  static const _dashboardChannel =
      '${RealtimeChannels.providerOrders}-dashboard';
  bool _togglingOpen = false;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  Future<void> _subscribeRealtime() async {
    try {
      final merchantId = await ref.read(_merchantIdProvider.future);
      if (!mounted || merchantId.isEmpty) return;
      ref.read(realtimeServiceProvider).subscribe(
            channelName: _dashboardChannel,
            opts: [
              RealtimeChannelFilter(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'orders',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'merchant_id',
                  value: merchantId,
                ),
                callback: (_) => ref.invalidate(_statsProvider),
              ),
            ],
          );
    } catch (_) {}
  }

  @override
  void dispose() {
    ref.read(realtimeServiceProvider).unsubscribe(_dashboardChannel);
    super.dispose();
  }

  Future<void> _toggleStoreOpen(bool nextOpen) async {
    if (_togglingOpen) return;
    setState(() => _togglingOpen = true);
    try {
      await ref
          .read(providerAvailabilityRepositoryProvider)
          .setAvailability(nextOpen);
      ref.invalidate(providerAvailabilityProvider);
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _togglingOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(_statsProvider);
    final availabilityAsync = ref.watch(providerAvailabilityProvider);
    final isOpen = availabilityAsync.value?['is_open'] as bool? ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.merchantDashboard),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_statsProvider);
              ref.invalidate(providerAvailabilityProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_statsProvider);
          ref.invalidate(providerAvailabilityProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedFadeIn(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOpen
                                ? AppColors.successLight
                                : AppColors.warningLight,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOpen
                                    ? l10n.storeOpenStatus
                                    : l10n.storeClosedStatus,
                                style: context.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.autoProvisionedStoreReady,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isOpen,
                          onChanged: _togglingOpen ? null : _toggleStoreOpen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
              color: AppColors.infoLight,
            ),
            _StatCard(
              title: AppLocalizations.of(context).revenue,
              value: '${AppLocalizations.of(context).currencySymbol} ${stats.todayRevenue.toStringAsFixed(0)}',
              icon: Icons.payments_outlined,
              color: AppColors.successLight,
            ),
            _StatCard(
              title: AppLocalizations.of(context).pending,
              value: stats.pendingOrders.toString(),
              icon: Icons.pending_outlined,
              color: AppColors.warningLight,
            ),
            _StatCard(
              title: AppLocalizations.of(context).rating,
              value: stats.averageRating.toStringAsFixed(1),
              icon: Icons.star_outline_rounded,
              color: AppColors.rating,
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            leading: const Icon(Icons.warehouse_outlined),
            title: Text(l10n.inventory),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/merchant-dashboard/inventory'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(l10n.storefront),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/merchant-dashboard/storefront'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: Text(AppLocalizations.of(context).createOffer),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/merchant-dashboard/offers'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: Text(l10n.branches),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/merchant-dashboard/branches'),
          ),
          if (ref
              .watch(providerCapabilitiesProvider)
              .contains(ProviderCapability.availability)) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.toggle_on_outlined),
              title: Text(l10n.availability),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/provider-availability'),
            ),
          ],
          if (ref
              .watch(providerCapabilitiesProvider)
              .contains(ProviderCapability.verification)) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(l10n.verification),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/provider-verification'),
            ),
          ],
          if (ref
              .watch(providerCapabilitiesProvider)
              .contains(ProviderCapability.documents)) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.documents),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/provider-documents'),
            ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(l10n.reservations),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/merchant-dashboard/reservations'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: Text(l10n.reviews),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/merchant-dashboard/reviews'),
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
