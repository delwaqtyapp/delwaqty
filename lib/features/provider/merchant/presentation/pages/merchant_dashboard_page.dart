import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_stats.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_storefront_page.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/availability/presentation/providers/provider_availability_providers.dart';
import 'package:delwaqty/services/realtime/realtime_channel_constants.dart';
import 'package:delwaqty/services/realtime/realtime_service.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/floating_glass_buttons.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
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

class _MerchantDashboardPageState extends ConsumerState<MerchantDashboardPage> {
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
      ref
          .read(realtimeServiceProvider)
          .subscribe(
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

  Future<void> _openWorkspaceSwitcher(
    BuildContext context,
    AppLocalizations l10n,
    ProviderProfilesState profilesState,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.switchWorkspace,
                style: Theme.of(sheetCtx).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (profilesState.isOwner) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.brandPurple,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.ownerAllModesUnlocked,
                          style: const TextStyle(
                            color: AppColors.brandPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: profilesState.profiles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, idx) {
                    final p = profilesState.profiles[idx];
                    final isActive =
                        p.categoryType == profilesState.activeCategory;
                    final canSwitch = p.isApproved || profilesState.isOwner;
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: isActive
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: AppColors.brandPurple,
                                width: 1.5,
                              ),
                            )
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.brandPurple.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(
                            p.categoryType == 'home_services'
                                ? Icons.handyman_rounded
                                : Icons.storefront_rounded,
                            color: AppColors.brandPurple,
                          ),
                        ),
                        title: Text(
                          p.displayName.isNotEmpty
                              ? p.displayName
                              : _categoryLabel(l10n, p.categoryType),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${_categoryLabel(l10n, p.categoryType)} · ${p.isApproved ? l10n.verified : (p.status == 'rejected' ? l10n.rejected : l10n.pendingReview)}',
                        ),
                        trailing: isActive
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.successLight,
                              )
                            : canSwitch
                            ? const Icon(Icons.chevron_right_rounded)
                            : const Icon(Icons.lock_clock_rounded, size: 18),
                        onTap: !canSwitch
                            ? null
                            : () async {
                                Navigator.of(sheetCtx).pop();
                                try {
                                  await Supabase.instance.client.rpc(
                                    'switch_active_provider_profile',
                                    params: {'p_category_type': p.categoryType},
                                  );
                                  if (!mounted) return;
                                  ref.invalidate(providerProfilesProvider);
                                  ref.invalidate(providerRawCategoryProvider);
                                  ref.invalidate(providerMerchantIdProvider);
                                  ref.invalidate(storefrontProvider);
                                  ref.invalidate(_statsProvider);
                                  ref.invalidate(providerAvailabilityProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    context.showAppSnackBar(
                                      appErrorText(context, e),
                                      isError: true,
                                    );
                                  }
                                }
                              },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _openRequestServiceDialog(context, l10n);
                  },
                  icon: const Icon(Icons.add_business_rounded),
                  label: Text(l10n.requestAdditionalService),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'restaurant':
        return l10n.restaurant;
      case 'grocery':
        return l10n.grocery;
      case 'pharmacy':
        return l10n.pharmacy;
      case 'bakery':
        return l10n.bakery;
      case 'cafe':
        return l10n.cafe;
      case 'electronics':
        return l10n.electronics;
      case 'fashion':
        return l10n.fashion;
      case 'home_services':
        return l10n.homeServices;
      default:
        return l10n.other;
    }
  }

  Future<void> _openRequestServiceDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    const categories = [
      'restaurant',
      'grocery',
      'pharmacy',
      'bakery',
      'home_services',
      'electronics',
      'fashion',
    ];
    String selectedCat = 'grocery';
    final nameCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(l10n.requestAdditionalService),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.additionalServiceHint,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCat,
                decoration: InputDecoration(
                  labelText: l10n.storeCategoryLabel,
                  border: const OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(_categoryLabel(l10n, c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDlgState(() => selectedCat = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.serviceDisplayName,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dlgCtx).pop(true),
              child: Text(l10n.submit),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) {
      nameCtrl.dispose();
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'request_additional_provider_profile',
        params: {
          'p_category_type': selectedCat,
          'p_display_name': nameCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      ref.invalidate(providerProfilesProvider);
      if (context.mounted) {
        context.showAppSnackBar(l10n.serviceRequestSubmitted);
      }
    } catch (e) {
      if (context.mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    } finally {
      nameCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(_statsProvider);
    final availabilityAsync = ref.watch(providerAvailabilityProvider);
    final storefrontAsync = ref.watch(storefrontProvider);
    final profilesState =
        ref.watch(providerProfilesProvider).value ??
        const ProviderProfilesState();
    final isOpen = availabilityAsync.value?['is_open'] as bool? ?? true;
    final storeData = storefrontAsync.value;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: const Padding(
          padding: EdgeInsetsDirectional.only(start: 12),
          child: Center(child: FloatingMenuCircleButton(size: 40)),
        ),
        title: Text(l10n.merchantDashboard),
        actions: [
          IconButton(
            tooltip: l10n.support,
            icon: const Icon(Icons.support_agent_rounded),
            onPressed: () => context.push('/support'),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 6),
              child: FloatingNotificationCircleButton(size: 40),
            ),
          ),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(_statsProvider);
              ref.invalidate(providerAvailabilityProvider);
              ref.invalidate(storefrontProvider);
              ref.invalidate(providerProfilesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_statsProvider);
          ref.invalidate(providerAvailabilityProvider);
          ref.invalidate(storefrontProvider);
          ref.invalidate(providerProfilesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedFadeIn(
                child: _StoreHeroCard(
                  storeName: (storeData?.name.isNotEmpty == true)
                      ? storeData!.name
                      : l10n.merchantDashboard,
                  logoUrl: storeData?.logoUrl,
                  category: profilesState.activeCategory.isNotEmpty
                      ? profilesState.activeCategory
                      : (storeData?.type ?? ''),
                  rating: statsAsync.value?.averageRating ?? 5.0,
                  isOpen: isOpen,
                  toggling: _togglingOpen,
                  onToggle: _toggleStoreOpen,
                  onEditStorefront: () =>
                      context.push('/merchant-dashboard/storefront'),
                  onSwitchWorkspace: () =>
                      _openWorkspaceSwitcher(context, l10n, profilesState),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 80),
                child: Text(
                  l10n.overview,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                loading: () => _buildStatsShimmer(),
                error: (e, _) => AnimatedFadeIn(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
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
                delay: const Duration(milliseconds: 180),
                child: Text(
                  l10n.quickActions,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 240),
                child: _buildQuickActionsGrid(context, statsAsync.value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsShimmer() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: List.generate(4, (_) => const ShimmerCard(height: 90)),
    );
  }

  Widget _buildStatsGrid(BuildContext context, MerchantStats stats) {
    final l10n = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: l10n.todayOrders,
          value: stats.todayOrders.toString(),
          icon: Icons.shopping_bag_outlined,
          color: AppColors.infoLight,
          onTap: () => context.push('/merchant-dashboard/orders'),
        ),
        _StatCard(
          title: l10n.revenue,
          value:
              '${stats.todayRevenue.toStringAsFixed(0)} ${l10n.currencySymbol}',
          icon: Icons.payments_outlined,
          color: AppColors.successLight,
          onTap: () => context.push('/provider-financial-center'),
        ),
        _StatCard(
          title: l10n.pending,
          value: stats.pendingOrders.toString(),
          icon: Icons.pending_actions_rounded,
          color: stats.pendingOrders > 0
              ? AppColors.warningLight
              : AppColors.brandPurple,
          highlight: stats.pendingOrders > 0,
          onTap: () => context.push('/merchant-dashboard/orders'),
        ),
        _StatCard(
          title: l10n.rating,
          value: stats.averageRating.toStringAsFixed(1),
          icon: Icons.star_rounded,
          color: AppColors.rating,
          onTap: () => context.push('/merchant-dashboard/reviews'),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, MerchantStats? stats) {
    final l10n = AppLocalizations.of(context);
    final caps = ref.watch(providerCapabilitiesProvider);
    final pendingCount = stats?.pendingOrders ?? 0;

    final items = <_QuickActionItem>[
      if (caps.contains(ProviderCapability.orders))
        _QuickActionItem(
          title: l10n.viewOrders,
          icon: Icons.receipt_long_rounded,
          color: AppColors.infoLight,
          badgeCount: pendingCount,
          onTap: () => context.push('/merchant-dashboard/orders'),
        ),
      if (caps.contains(ProviderCapability.catalog))
        _QuickActionItem(
          title: l10n.manageProducts,
          icon: Icons.inventory_2_rounded,
          color: AppColors.brandPurple,
          onTap: () => context.push('/merchant-dashboard/products'),
        ),
      if (caps.contains(ProviderCapability.catalog))
        _QuickActionItem(
          title: l10n.inventory,
          icon: Icons.warehouse_rounded,
          color: AppColors.brandViolet,
          onTap: () => context.push('/merchant-dashboard/inventory'),
        ),
      _QuickActionItem(
        title: l10n.storefront,
        icon: Icons.storefront_rounded,
        color: AppColors.successLight,
        onTap: () => context.push('/merchant-dashboard/storefront'),
      ),
      if (caps.contains(ProviderCapability.offers))
        _QuickActionItem(
          title: l10n.createOffer,
          icon: Icons.local_offer_rounded,
          color: AppColors.warningLight,
          onTap: () => context.push('/merchant-dashboard/offers'),
        ),
      _QuickActionItem(
        title: l10n.adminBannersTitle,
        icon: Icons.view_carousel_rounded,
        color: AppColors.brandViolet,
        onTap: () => context.push('/merchant-dashboard/banners'),
      ),
      if (caps.contains(ProviderCapability.branches))
        _QuickActionItem(
          title: l10n.branches,
          icon: Icons.store_rounded,
          color: Colors.teal,
          onTap: () => context.push('/merchant-dashboard/branches'),
        ),
      if (caps.contains(ProviderCapability.bookings) ||
          caps.contains(ProviderCapability.orders))
        _QuickActionItem(
          title: l10n.reservations,
          icon: Icons.calendar_month_rounded,
          color: Colors.indigo,
          onTap: () => context.push('/merchant-dashboard/reservations'),
        ),
      if (caps.contains(ProviderCapability.reviews))
        _QuickActionItem(
          title: l10n.reviews,
          icon: Icons.rate_review_rounded,
          color: AppColors.rating,
          onTap: () => context.push('/merchant-dashboard/reviews'),
        ),
      if (caps.contains(ProviderCapability.availability))
        _QuickActionItem(
          title: l10n.availability,
          icon: Icons.schedule_rounded,
          color: Colors.deepOrange,
          onTap: () => context.push('/provider-availability'),
        ),
      _QuickActionItem(
        title: l10n.financialCenter,
        icon: Icons.account_balance_wallet_rounded,
        color: Colors.green,
        onTap: () => context.push('/provider-financial-center'),
      ),
      if (caps.contains(ProviderCapability.verification))
        _QuickActionItem(
          title: l10n.verification,
          icon: Icons.verified_user_rounded,
          color: Colors.blueGrey,
          onTap: () => context.push('/provider-verification'),
        ),
      if (caps.contains(ProviderCapability.documents))
        _QuickActionItem(
          title: l10n.documents,
          icon: Icons.folder_open_rounded,
          color: Colors.brown,
          onTap: () => context.push('/provider-documents'),
        ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, index) => _QuickActionCard(item: items[index]),
    );
  }
}

class _StoreHeroCard extends StatelessWidget {
  const _StoreHeroCard({
    required this.storeName,
    required this.logoUrl,
    required this.category,
    required this.rating,
    required this.isOpen,
    required this.toggling,
    required this.onToggle,
    required this.onEditStorefront,
    required this.onSwitchWorkspace,
  });

  final String storeName;
  final String? logoUrl;
  final String category;
  final double rating;
  final bool isOpen;
  final bool toggling;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditStorefront;
  final VoidCallback onSwitchWorkspace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPurple, AppColors.brandViolet],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurple.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: (logoUrl != null && logoUrl!.isNotEmpty)
                    ? NetworkImage(logoUrl!)
                    : null,
                child: (logoUrl == null || logoUrl!.isEmpty)
                    ? const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (category.isNotEmpty) ...[
                          InkWell(
                            onTap: onSwitchWorkspace,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.swap_horiz_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.switchWorkspace,
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                onPressed: onSwitchWorkspace,
              ),
              IconButton(
                tooltip: l10n.storefront,
                icon: const Icon(
                  Icons.edit_location_alt_rounded,
                  color: Colors.white,
                ),
                onPressed: onEditStorefront,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isOpen ? Colors.greenAccent : Colors.amberAccent)
                    .withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOpen ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOpen ? l10n.storeOpenStatus : l10n.storeClosedStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Switch(
                  value: isOpen,
                  onChanged: toggling ? null : onToggle,
                  activeThumbColor: Colors.greenAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.item});
  final _QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onTap: item.onTap,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (item.badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${item.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    this.highlight = false,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onTap: onTap ?? () {},
      child: Card(
        margin: EdgeInsets.zero,
        shape: highlight
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: color.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
