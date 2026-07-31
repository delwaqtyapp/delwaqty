import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/home/domain/home_domain.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/floating_sidebar/floating_sidebar.dart';

String _merchantTypeLabel(MerchantType type, AppLocalizations l10n) =>
    switch (type) {
      MerchantType.restaurant => l10n.typeRestaurant,
      MerchantType.grocery => l10n.typeGrocery,
      MerchantType.pharmacy => l10n.typePharmacy,
      MerchantType.flowers => l10n.typeFlowers,
      MerchantType.bakery => l10n.typeBakery,
      MerchantType.electronics => l10n.typeElectronics,
      MerchantType.furniture => l10n.typeFurniture,
      MerchantType.fashion => l10n.typeFashion,
      MerchantType.home => l10n.typeHome,
      MerchantType.other => l10n.typeOther,
    };

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final isGuest = authState is AuthGuest;
    final locationAsync = ref.watch(userLocationProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nearbyMerchantsProvider);
            ref.read(userLocationProvider.notifier).refresh();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(context, ref, l10n, isGuest, locationAsync),
              ),
              SliverToBoxAdapter(child: _buildSearchBar(context, l10n)),
              SliverToBoxAdapter(child: _buildServiceGrid(context, l10n)),
              SliverToBoxAdapter(
                child: _buildSectionTitle(context, l10n.nearby, l10n),
              ),
              _buildMerchantList(context, ref, l10n),
              SliverToBoxAdapter(child: _buildPromoBanner(context, l10n)),
              SliverToBoxAdapter(
                child: _buildSectionTitle(context, l10n.popular, l10n),
              ),
              _buildMerchantList(context, ref, l10n),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    bool isGuest,
    AsyncValue<UserLocation?> locationAsync,
  ) {
    final locationText = locationAsync.when(
      data: (loc) => loc?.detailedAddress.isNotEmpty == true
          ? loc!.detailedAddress
          : l10n.locationUnavailable,
      loading: () => l10n.searchingForLocation,
      error: (_, __) => l10n.searchingForLocation,
    );
    final isLocationLoading =
        locationAsync is AsyncLoading || locationAsync is AsyncError;
    return AnimatedFadeIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => FloatingSidebarController.open(context, ref),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colorScheme.primary,
                    context.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: context.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  l10n.appNameAr,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      if (isLocationLoading)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: context.colorScheme.primary,
                          ),
                        )
                      else
                        Flexible(
                          child: Text(
                            locationText,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    isGuest ? l10n.welcomeGuestButton : l10n.hello,
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _buildNotificationBadge(context, isGuest),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBadge(BuildContext context, bool isGuest) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: IconButton(
        onPressed: isGuest
            ? () => context.push('/login')
            : () => context.push('/notifications'),
        icon: Badge(
          backgroundColor: context.colorScheme.error,
          smallSize: 8,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: context.colorScheme.onSurface,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: GestureDetector(
          onTap: () => context.go('/search'),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: 0.25,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Icon(Icons.search_rounded, color: context.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.searchHint,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.tune_rounded,
                  color: context.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context, AppLocalizations l10n) {
    final services = [
      _ServiceData(
        Icons.restaurant_rounded,
        l10n.restaurants,
        AppColors.serviceRestaurant,
      ),
      _ServiceData(
        Icons.local_grocery_store_rounded,
        l10n.grocery,
        AppColors.serviceGrocery,
      ),
      _ServiceData(
        Icons.local_pharmacy_rounded,
        l10n.pharmacy,
        AppColors.servicePharmacy,
      ),
      _ServiceData(Icons.local_taxi_rounded, l10n.ride, AppColors.serviceRide),
      _ServiceData(
        Icons.home_repair_service_rounded,
        l10n.homeServices,
        AppColors.serviceHome,
      ),
      _ServiceData(
        Icons.local_shipping_rounded,
        l10n.delivery,
        AppColors.serviceDelivery,
      ),
      _ServiceData(
        Icons.local_offer_rounded,
        l10n.offers,
        AppColors.serviceOffers,
      ),
      _ServiceData(
        Icons.more_horiz_rounded,
        l10n.settings,
        AppColors.serviceMore,
      ),
    ];

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return _ServiceTile(
              icon: service.icon,
              label: service.label,
              color: service.color,
              delay: Duration(milliseconds: 250 + index * 50),
              onTap: () {
                if (index == 0) {
                  context.push('/market');
                } else if (index == 1) {
                  context.push('/market?type=grocery');
                } else if (index == 2) {
                  context.push('/market?type=pharmacy');
                } else if (index == 3) {
                  context.push('/ride/book');
                } else if (index == 4) {
                  context.push('/market?type=home');
                } else if (index == 5) {
                  context.push('/direct-delivery');
                } else if (index == 6) {
                  context.push('/market');
                } else if (index == 7) {
                  context.push('/settings');
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    AppLocalizations l10n,
  ) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/market'),
              child: Text(l10n.viewAll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final merchantsAsync = ref.watch(nearbyMerchantsProvider);

    return merchantsAsync.when(
      loading: () => SliverToBoxAdapter(
        child: SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const ShimmerCard(height: 180),
          ),
        ),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: PremiumEmptyState(
            icon: Icons.store_outlined,
            title: l10n.noResults,
            message: l10n.errorLoading,
          ),
        ),
      ),
      data: (merchants) {
        if (merchants.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumEmptyState(
                icon: Icons.store_outlined,
                title: l10n.noResults,
                message: l10n.nearbyEmptyHint,
              ),
            ),
          );
        }
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              itemCount: merchants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final merchant = merchants[index];
                return _MerchantCard(
                  merchant: merchant,
                  onTap: () => context.push('/market/merchant/${merchant.id}'),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromoBanner(BuildContext context, AppLocalizations l10n) {
    const couponCode = 'DELWAQTY30';
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 450),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: GestureDetector(
          onTap: () async {
            await Clipboard.setData(const ClipboardData(text: couponCode));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.codeCopied),
                duration: const Duration(milliseconds: 1500),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6750A4), Color(0xFF9A82DB)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6750A4).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colorScheme.onPrimary.withValues(
                        alpha: 0.1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colorScheme.onPrimary.withValues(
                        alpha: 0.08,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '30% OFF',
                              style: context.textTheme.headlineSmall?.copyWith(
                                color: context.colorScheme.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: context.colorScheme.onPrimary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.copyCode,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: context.colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.onboardingDesc2,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.colorScheme.onPrimary.withValues(
                            alpha: 0.85,
                          ),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.onPrimary.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          couponCode,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: context.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceData {
  const _ServiceData(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.delay,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Duration delay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedFadeIn(
      delay: delay,
      child: PressableScale(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.labelSmall,
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

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.merchant, required this.onTap});

  final Merchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emoji = _getMerchantEmoji(merchant.type);

    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.onSurface.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    context.colorScheme.primaryContainer.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: AppTextStyles.displaySmall.copyWith(fontSize: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.rating,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        merchant.rating.toStringAsFixed(1),
                        style: context.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        _merchantTypeLabel(
                          merchant.type,
                          AppLocalizations.of(context),
                        ),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMerchantEmoji(MerchantType type) {
    switch (type) {
      case MerchantType.restaurant:
        return '🍽️';
      case MerchantType.grocery:
        return '🛒';
      case MerchantType.pharmacy:
        return '💊';
      case MerchantType.electronics:
        return '📱';
      default:
        return '🏪';
    }
  }
}
