import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/favorite_button.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';
import 'package:delwaqty/features/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/design/premium_search_field.dart';
import 'package:delwaqty/shared/widgets/design/glass_surface.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/home/domain/home_domain.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
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

Color _merchantTypeColor(MerchantType type) => switch (type) {
  MerchantType.restaurant => AppColors.serviceRestaurant,
  MerchantType.grocery => AppColors.serviceGrocery,
  MerchantType.pharmacy => AppColors.servicePharmacy,
  MerchantType.flowers => AppColors.merchantFashion,
  MerchantType.bakery => AppColors.orderPending,
  MerchantType.electronics => AppColors.serviceRide,
  MerchantType.furniture => AppColors.serviceHome,
  MerchantType.fashion => AppColors.merchantFashion,
  MerchantType.home => AppColors.serviceHome,
  MerchantType.other => AppColors.serviceMore,
};

String _merchantEmoji(MerchantType type) => switch (type) {
  MerchantType.restaurant => '🍽️',
  MerchantType.grocery => '🛒',
  MerchantType.pharmacy => '💊',
  MerchantType.flowers => '💐',
  MerchantType.bakery => '🥐',
  MerchantType.electronics => '📱',
  MerchantType.furniture => '🛋️',
  MerchantType.fashion => '👗',
  MerchantType.home => '🔧',
  MerchantType.other => '🏪',
};

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const String couponCode = 'DELWAQTY30';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final isGuest = authState is AuthGuest;
    final locationAsync = ref.watch(userLocationProvider);
    final unreadCount = isGuest
        ? 0
        : ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: SafeArea(
        child: GradientBackground(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(nearbyMerchantsProvider);
              ref.read(userLocationProvider.notifier).refreshQuick();
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(
                    context,
                    ref,
                    l10n,
                    authState,
                    isGuest,
                    locationAsync,
                    unreadCount,
                  ),
                ),
                SliverToBoxAdapter(child: _buildSearchBar(context, l10n)),
                SliverToBoxAdapter(
                  child: _HeroOrderCard(
                    onTap: () => context.push('/direct-delivery'),
                  ),
                ),
                SliverToBoxAdapter(child: _buildServiceGrid(context, ref, l10n)),
                SliverToBoxAdapter(
                  child: _buildSectionTitle(
                    context,
                    l10n.nearby,
                    () => context.push('/market'),
                  ),
                ),
                _buildMerchantList(context, ref, l10n, featured: false),
                const SliverToBoxAdapter(child: _PromoCarousel()),
                SliverToBoxAdapter(
                  child: _buildSectionTitle(
                    context,
                    l10n.popular,
                    () => context.push('/market'),
                  ),
                ),
                _buildMerchantList(context, ref, l10n, featured: true),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting(AppLocalizations l10n, AuthState authState) {
    if (authState is AuthGuest) return l10n.hello;
    if (authState is AuthAuthenticated) {
      final name = authState.user.fullName ?? authState.user.username;
      if (name != null && name.isNotEmpty) return l10n.helloName(name);
    }
    return l10n.goodEvening;
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AuthState authState,
    bool isGuest,
    AsyncValue<UserLocation?> locationAsync,
    int unreadCount,
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          children: [
            _GlassCircleButton(
              icon: Icons.menu_rounded,
              onTap: () => FloatingSidebarController.open(context, ref),
            ),
            const SizedBox(width: 10),
            const _LogoMark(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(l10n, authState),
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _LocationChip(
                    text: locationText,
                    loading: isLocationLoading,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _NotificationCircle(
              unreadCount: unreadCount,
              onTap: isGuest
                  ? () => context.push('/login')
                  : () => context.push('/notifications'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: PremiumSearchField(
          readOnly: true,
          hint: l10n.searchHint,
          onTap: () => context.go('/search'),
          onFilterPressed: () => context.go('/search'),
        ),
      ),
    );
  }

  Widget _buildServiceGrid(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final merchants = ref.watch(nearbyMerchantsProvider).valueOrNull;
    int countOf(MerchantType type) =>
        merchants?.where((m) => m.type == type).length ?? 0;

    final services = [
      _ServiceData(
        Icons.restaurant_rounded,
        l10n.restaurants,
        AppColors.serviceRestaurant,
        countOf(MerchantType.restaurant),
      ),
      _ServiceData(
        Icons.local_grocery_store_rounded,
        l10n.grocery,
        AppColors.serviceGrocery,
        countOf(MerchantType.grocery),
      ),
      _ServiceData(
        Icons.local_pharmacy_rounded,
        l10n.pharmacy,
        AppColors.servicePharmacy,
        countOf(MerchantType.pharmacy),
      ),
      _ServiceData(
        Icons.home_repair_service_rounded,
        l10n.homeServices,
        AppColors.serviceHome,
        countOf(MerchantType.home),
      ),
      _ServiceData(
        Icons.local_shipping_rounded,
        l10n.delivery,
        AppColors.serviceDelivery,
        null,
      ),
      _ServiceData(
        Icons.local_offer_rounded,
        l10n.offers,
        AppColors.serviceOffers,
        null,
      ),
      _ServiceData(
        Icons.more_horiz_rounded,
        l10n.settings,
        AppColors.serviceMore,
        null,
      ),
    ];

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return _ServiceTile(
              icon: service.icon,
              label: service.label,
              color: service.color,
              count: service.count,
              delay: Duration(milliseconds: 250 + index * 50),
              onTap: () {
                switch (index) {
                  case 0:
                    context.push('/market');
                  case 1:
                    context.push('/market?type=grocery');
                  case 2:
                    context.push('/market?type=pharmacy');
                  case 3:
                    context.push('/market?type=home');
                  case 4:
                    context.push('/direct-delivery');
                  case 5:
                    context.push('/market');
                  case 6:
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
    VoidCallback onViewAll,
  ) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                AppLocalizations.of(context).viewAll,
                style: AppTextStyles.labelLarge.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    required bool featured,
  }) {
    final merchantsAsync = ref.watch(nearbyMerchantsProvider);

    return merchantsAsync.when(
      loading: () => SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, __) => const ShimmerCard(height: 212),
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
      data: (all) {
        var merchants = all;
        if (featured) {
          final featuredMerchants = all.where((m) => m.isFeatured).toList();
          if (featuredMerchants.isNotEmpty) {
            merchants = featuredMerchants.take(6).toList();
          } else {
            merchants = all.take(6).toList();
          }
        }
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
            height: 224,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              itemCount: merchants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final merchant = merchants[index];
                return _HomeMerchantCard(
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
}

class _ServiceData {
  const _ServiceData(this.icon, this.label, this.color, this.count);
  final IconData icon;
  final String label;
  final Color color;
  final int? count;
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
    required this.delay,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final int? count;
  final Duration delay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedFadeIn(
      delay: delay,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.38),
                      color.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: GlassSurface(
        borderRadius: 16,
        blur: 16,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: context.colorScheme.onSurface, size: 22),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335B3DF0),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/logo app/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandPurpleDeep, AppColors.brandViolet],
              ),
            ),
            child: Center(
              child: Text(
                AppLocalizations.of(context).appNameAr,
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.text, required this.loading});

  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 13,
            color: AppColors.brandPurple,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: loading
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.brandPurple,
                    ),
                  )
                : Text(
                    text,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCircle extends StatelessWidget {
  const _NotificationCircle({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: PressableScale(
        onTap: onTap,
        child: GlassSurface(
          borderRadius: AppSpacing.radiusFull,
          blur: 16,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    color: context.colorScheme.onSurface,
                    size: 22,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 7,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: context.colorScheme.surfaceContainerLowest,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _HeroOrderCard extends StatefulWidget {
  const _HeroOrderCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HeroOrderCard> createState() => _HeroOrderCardState();
}

class _HeroOrderCardState extends State<_HeroOrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 150),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final v = _controller.value;
              final bobY = math.sin(v * 2 * math.pi) * 3;
              return AnimatedScale(
                scale: _pressed ? 0.98 : 1,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                child: Container(
                  height: 74,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: AppSpacing.borderRadiusCard,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandPurpleDeep, AppColors.brandViolet],
                    ),
                    boxShadow: AppElevation.shadowGlow,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.4 + 2.8 * v, -0.6),
                            end: Alignment(-0.4 + 2.8 * v, 0.6),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 16,
                        right: 16,
                        child: Container(
                          height: 1.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      for (final i in [0, 1, 2]) _HeroParticle(v: v, seed: i),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Transform.translate(
                              offset: Offset(0, -bobY),
                              child: Icon(
                                Icons.rocket_launch_rounded,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.orderDirectly,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    l10n.fastestWayToOrder,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSlide(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              offset: _pressed
                                  ? const Offset(0.35, 0)
                                  : Offset.zero,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                                child: Icon(
                                  isRtl
                                      ? Icons.arrow_back_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroParticle extends StatelessWidget {
  const _HeroParticle({required this.v, required this.seed});

  final double v;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final pv = (v * 2 + seed * 0.31) % 1.0;
    final size = 4.0 + seed * 2.0;
    return Positioned(
      right: 26 + seed * 24.0,
      bottom: -6 + pv * 58,
      child: Opacity(
        opacity: (0.5 * (1 - pv)).clamp(0.0, 1.0).toDouble(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  static const String couponCode = 'DELWAQTY30';
  late final PageController _controller;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_current + 1) % 3;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyCoupon(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: couponCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).codeCopied),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slides = [
      _PromoSlideData(
        title: '30% OFF',
        subtitle: l10n.onboardingDesc2,
        coupon: couponCode,
        colors: const [AppColors.brandPurpleDeep, AppColors.brandViolet],
      ),
      _PromoSlideData(
        title: l10n.freeDelivery,
        subtitle: l10n.freeDeliveryPromoSub,
        colors: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
      ),
      _PromoSlideData(
        title: l10n.discount,
        subtitle: l10n.offersPromoSub,
        colors: const [Color(0xFFBE185D), Color(0xFFF43F5E)],
      ),
    ];

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 450),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            SizedBox(
              height: 140,
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return GestureDetector(
                    onTap: () {
                      if (slide.coupon != null) {
                        _copyCoupon(context);
                      } else {
                        context.push('/market');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _PromoSlide(data: slide),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _current == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _current == i
                          ? AppColors.brandPurple
                          : context.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoSlideData {
  const _PromoSlideData({
    required this.title,
    required this.subtitle,
    this.coupon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final String? coupon;
  final List<Color> colors;
}

class _PromoSlide extends StatelessWidget {
  const _PromoSlide({required this.data});

  final _PromoSlideData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.colors,
        ),
        boxShadow: [
          BoxShadow(
            color: data.colors.first.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: -34,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        style: context.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data.coupon != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.copyCode,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (data.coupon != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.coupon!,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMerchantCard extends StatelessWidget {
  const _HomeMerchantCard({required this.merchant, required this.onTap});

  final Merchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = _merchantTypeColor(merchant.type);
    final typeLabel = _merchantTypeLabel(merchant.type, l10n);

    return SizedBox(
      width: 170,
      child: PremiumCard(
        onTap: onTap,
        color: context.colorScheme.surfaceContainerLowest,
        borderColor: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (merchant.imageUrl != null)
                    Image.network(
                      merchant.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _merchantHeaderGradient(
                        context,
                        color,
                        _merchantEmoji(merchant.type),
                      ),
                    )
                  else
                    _merchantHeaderGradient(
                      context,
                      color,
                      _merchantEmoji(merchant.type),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _StatusBadge(
                        open: merchant.isOpenNow,
                        label: merchant.isOpenNow ? l10n.open : l10n.closed,
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.25),
                        ),
                        child: FavoriteButton(
                          targetId: merchant.id,
                          type: FavoriteType.merchant,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          typeLabel,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.name,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: AppColors.rating,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        merchant.rating.toStringAsFixed(1),
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (merchant.ratingCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${merchant.ratingCount})',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (merchant.deliveryAvailable &&
                          merchant.estimatedDeliveryMinutes != null)
                        Text(
                          '${merchant.estimatedDeliveryMinutes} ${l10n.minutesShort}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (merchant.deliveryAvailable &&
                      merchant.deliveryFee != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.delivery_dining_rounded,
                          size: 14,
                          color: AppColors.brandPurple,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            merchant.deliveryFee == 0
                                ? l10n.freeDelivery
                                : '${merchant.deliveryFee!.toStringAsFixed(0)} ${l10n.currencySymbol}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppColors.brandPurple,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _merchantHeaderGradient(
    BuildContext context,
    Color color,
    String emoji,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: AppTextStyles.displaySmall.copyWith(fontSize: 44),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.open, required this.label});

  final bool open;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bg = open ? AppColors.successLight : Colors.black.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
