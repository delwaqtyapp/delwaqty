import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/rating_stars.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/delivery_info.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/cart_badge.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/restaurant/domain/entities/branch.dart';
import 'package:delwaqty/features/restaurant/domain/entities/working_hours.dart';
import 'package:delwaqty/features/restaurant/domain/entities/restaurant_settings.dart';
import 'package:delwaqty/features/restaurant/domain/entities/offer.dart';
import 'package:delwaqty/features/restaurant/presentation/widgets/working_hours_card.dart';
import 'package:delwaqty/features/restaurant/presentation/widgets/branch_selector_sheet.dart';
import 'package:delwaqty/features/restaurant/presentation/widgets/service_type_chips.dart';
import 'package:delwaqty/features/restaurant/presentation/widgets/delivery_zone_card.dart';
import 'package:delwaqty/features/restaurant/presentation/widgets/offer_banner_card.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/section_header.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/skeleton_loader.dart';

final _merchantProvider = FutureProvider.family<Merchant?, String>((ref, id) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchantById(id);
});

final _branchesProvider = FutureProvider.family<List<Branch>, String>((ref, merchantId) async {
  final repo = ref.watch(branchRepositoryProvider);
  return repo.getBranches(merchantId);
});

final _hoursProvider = FutureProvider.family<List<WorkingHours>, String>((ref, merchantId) async {
  final repo = ref.watch(workingHoursRepositoryProvider);
  return repo.getHours(merchantId);
});

final _settingsProvider = FutureProvider.family<RestaurantSettings?, String>((ref, merchantId) async {
  final repo = ref.watch(restaurantSettingsRepositoryProvider);
  return repo.getSettings(merchantId);
});

final _offersProvider = FutureProvider.family<List<Offer>, String>((ref, merchantId) async {
  final repo = ref.watch(offerRepositoryProvider);
  return repo.getActiveOffers(merchantId);
});

class RestaurantDetailPage extends ConsumerStatefulWidget {
  const RestaurantDetailPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  ConsumerState<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends ConsumerState<RestaurantDetailPage> {
  Key _refreshKey = UniqueKey();
  Branch? _selectedBranch;

  Future<void> _onRefresh() async {
    setState(() => _refreshKey = UniqueKey());
    ref.invalidate(_merchantProvider(widget.merchantId));
    ref.invalidate(_branchesProvider(widget.merchantId));
    ref.invalidate(_hoursProvider(widget.merchantId));
    ref.invalidate(_settingsProvider(widget.merchantId));
    ref.invalidate(_offersProvider(widget.merchantId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final merchantAsync = ref.watch(_merchantProvider(widget.merchantId));

    return Scaffold(
      body: merchantAsync.when(
        data: (merchant) {
          if (merchant == null) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.restaurant_outlined,
                title: l10n.error,
                message: l10n.noData,
              ),
            );
          }
          return _buildBody(context, l10n, theme, merchant);
        },
        loading: () => const RestaurantDetailSkeleton(),
        error: (_, __) => Center(
          child: ErrorState(
            message: l10n.errorLoading,
            onRetry: _onRefresh,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n, ThemeData theme, Merchant merchant) {
    final settingsAsync = ref.watch(_settingsProvider(widget.merchantId));
    final branchesAsync = ref.watch(_branchesProvider(widget.merchantId));
    final hoursAsync = ref.watch(_hoursProvider(widget.merchantId));
    final offersAsync = ref.watch(_offersProvider(widget.merchantId));

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        key: _refreshKey,
        slivers: [
          _buildHeroImage(theme, merchant),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 100),
                    child: _buildHeader(theme, l10n, merchant),
                  ),
                  const SizedBox(height: 16),
                  settingsAsync.when(
                    data: (settings) {
                      if (settings == null) return const SizedBox.shrink();
                      return AnimatedFadeIn(
                        delay: const Duration(milliseconds: 200),
                        child: ServiceTypeChips(settings: settings),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 250),
                    child: DeliveryInfo(
                      estimatedMinutes: merchant.estimatedDeliveryMinutes,
                      deliveryFee: merchant.deliveryFee,
                      minimumOrder: merchant.minimumOrder,
                    ),
                  ),
                  const SizedBox(height: 20),
                  branchesAsync.when(
                    data: (branches) {
                      if (branches.isEmpty) return const SizedBox.shrink();
                      if (_selectedBranch == null && branches.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selectedBranch = branches.first);
                        });
                      }
                      return AnimatedFadeIn(
                        delay: const Duration(milliseconds: 300),
                        child: _buildBranchSection(context, l10n, theme, branches),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 350),
                    child: hoursAsync.when(
                      data: (hours) {
                        if (hours.isEmpty) return const SizedBox.shrink();
                        return WorkingHoursCard(hours: hours);
                      },
                      loading: () => const SizedBox(height: 60, child: ShimmerCard()),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  offersAsync.when(
                    data: (offers) {
                      if (offers.isEmpty) return const SizedBox.shrink();
                      return AnimatedFadeIn(
                        delay: const Duration(milliseconds: 400),
                        child: Column(
                          children: [
                            SectionHeader(
                              title: l10n.activeOffers,
                              actionLabel: l10n.viewAll,
                              onAction: () => context.push('/restaurant/${widget.merchantId}/offers'),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: offers.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) => OfferBannerCard(offer: offers[index]),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 450),
                    child: _buildQuickActions(context, l10n, theme),
                  ),
                  const SizedBox(height: 20),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 500),
                    child: _buildDeliveryZonesSection(context, l10n),
                  ),
                  const SizedBox(height: 20),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 550),
                    child: _buildContactSection(context, l10n, theme, merchant),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(ThemeData theme, Merchant merchant) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () => context.pop(),
      ),
      actions: [CartBadge(onTap: () => context.push('/market/cart'))],
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'merchant-${merchant.id}',
          child: Stack(
          fit: StackFit.expand,
          children: [
            if (merchant.imageUrl != null)
              Image.network(merchant.imageUrl!, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.7),
                      theme.colorScheme.tertiary.withOpacity(0.5),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  size: 80,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (merchant.isVerified) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context).verified,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n, Merchant merchant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RatingStars(rating: merchant.rating, count: merchant.ratingCount),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: merchant.isOpenNow
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                merchant.isOpenNow ? l10n.open : l10n.closed,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: merchant.isOpenNow ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (merchant.description != null && merchant.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            merchant.description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (merchant.address != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  merchant.address!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBranchSection(BuildContext context, AppLocalizations l10n, ThemeData theme, List<Branch> branches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.branches,
          actionLabel: l10n.viewAll,
          onAction: () => _showBranchSelector(context, branches),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showBranchSelector(context, branches),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.store_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedBranch?.name ?? l10n.selectBranch,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_selectedBranch?.address != null)
                        Text(
                          _selectedBranch!.address!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showBranchSelector(BuildContext context, List<Branch> branches) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BranchSelectorSheet(
        branches: branches,
        selectedBranch: _selectedBranch,
        onBranchSelected: (branch) {
          setState(() => _selectedBranch = branch);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final actions = [
      (Icons.restaurant_menu_rounded, l10n.fullMenu, '/restaurant/${widget.merchantId}/menu'),
      (Icons.local_offer_outlined, l10n.offers, '/restaurant/${widget.merchantId}/offers'),
      (Icons.reviews_outlined, l10n.reviews, '/restaurant/${widget.merchantId}/reviews'),
      (Icons.calendar_today_outlined, l10n.reserveATable, '/restaurant/${widget.merchantId}/reservation'),
      (Icons.photo_library_outlined, l10n.gallery, '/restaurant/${widget.merchantId}/gallery'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.details,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.map((action) {
            final (icon, label, route) = action;
            return Expanded(
              child: GestureDetector(
                onTap: () => context.push(route),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: theme.colorScheme.primary, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDeliveryZonesSection(BuildContext context, AppLocalizations l10n) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.deliveryZones),
          const SizedBox(height: 8),
          DeliveryZoneCard(merchantId: widget.merchantId),
        ],
      ),
    );
  }

  Widget _buildContactSection(BuildContext context, AppLocalizations l10n, ThemeData theme, Merchant merchant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.contactInfo,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (merchant.address != null)
          _buildContactRow(
            context,
            theme,
            Icons.location_on_outlined,
            l10n.directions,
            merchant.address!,
          ),
        if (merchant.address != null) const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(l10n.shareRestaurant, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(BuildContext context, ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
