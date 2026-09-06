import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/favorite_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/shared/notifications/notification_channels.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/design/premium_search_field.dart';
import 'package:delwaqty/shared/widgets/design/glass_surface.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/shared/widgets/scroll_aware_nav.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
import 'package:delwaqty/features/admin/floating_sidebar/floating_sidebar.dart';

String _merchantTypeLabel(MerchantType type, AppLocalizations l10n) =>
    switch (type) {
      MerchantType.restaurant => l10n.typeRestaurant,
      MerchantType.grocery => l10n.typeGrocery,
      MerchantType.supermarket => l10n.typeSupermarket,
      MerchantType.fruits => l10n.typeFruits,
      MerchantType.meat => l10n.typeMeat,
      MerchantType.seafood => l10n.typeSeafood,
      MerchantType.pharmacy => l10n.typePharmacy,
      MerchantType.bakery => l10n.typeBakery,
      MerchantType.sweets => l10n.typeSweets,
      MerchantType.flowers => l10n.typeFlowers,
      MerchantType.clothing => l10n.typeClothing,
      MerchantType.shoes => l10n.typeShoes,
      MerchantType.electronics => l10n.typeElectronics,
      MerchantType.mobile => l10n.typeMobile,
      MerchantType.furniture => l10n.typeFurniture,
      MerchantType.fashion => l10n.typeFashion,
      MerchantType.appliances => l10n.typeAppliances,
      MerchantType.home => l10n.typeHome,
      MerchantType.cafe => l10n.typeCafe,
      MerchantType.petShop => l10n.typePetShop,
      MerchantType.fitness => l10n.typeFitness,
      MerchantType.gas => l10n.typeGas,
      MerchantType.carwash => l10n.typeCarwash,
      MerchantType.other => l10n.typeOther,
    };

Color _merchantTypeColor(MerchantType type) => switch (type) {
  MerchantType.restaurant => AppColors.serviceRestaurant,
  MerchantType.grocery => AppColors.serviceGrocery,
  MerchantType.supermarket => AppColors.serviceSupermarket,
  MerchantType.fruits => AppColors.serviceFruits,
  MerchantType.meat => AppColors.serviceMeat,
  MerchantType.seafood => AppColors.serviceSeafood,
  MerchantType.pharmacy => AppColors.servicePharmacy,
  MerchantType.bakery => AppColors.serviceBakery,
  MerchantType.sweets => AppColors.serviceSweets,
  MerchantType.flowers => AppColors.serviceFlowers,
  MerchantType.clothing => AppColors.serviceClothing,
  MerchantType.shoes => AppColors.serviceShoes,
  MerchantType.electronics => AppColors.serviceElectronics,
  MerchantType.mobile => AppColors.serviceMobile,
  MerchantType.furniture => AppColors.serviceFurniture,
  MerchantType.fashion => AppColors.serviceFashion,
  MerchantType.appliances => AppColors.serviceAppliances,
  MerchantType.home => AppColors.serviceHome,
  MerchantType.cafe => AppColors.serviceCafe,
  MerchantType.petShop => AppColors.servicePetShop,
  MerchantType.fitness => AppColors.serviceFitness,
  MerchantType.gas => AppColors.serviceGas,
  MerchantType.carwash => AppColors.serviceCarwash,
  MerchantType.other => AppColors.serviceMore,
};

String _merchantEmoji(MerchantType type) => switch (type) {
  MerchantType.restaurant => '🍽️',
  MerchantType.grocery => '🛒',
  MerchantType.supermarket => '🏪',
  MerchantType.fruits => '🥬',
  MerchantType.meat => '🥩',
  MerchantType.seafood => '🐟',
  MerchantType.pharmacy => '💊',
  MerchantType.bakery => '🥐',
  MerchantType.sweets => '🍰',
  MerchantType.flowers => '💐',
  MerchantType.clothing => '👔',
  MerchantType.shoes => '👟',
  MerchantType.electronics => '📱',
  MerchantType.mobile => '📞',
  MerchantType.furniture => '🛋️',
  MerchantType.fashion => '👗',
  MerchantType.appliances => '🔌',
  MerchantType.home => '🔧',
  MerchantType.cafe => '☕',
  MerchantType.petShop => '🐾',
  MerchantType.fitness => '💪',
  MerchantType.gas => '⛽',
  MerchantType.carwash => '🚿',
  MerchantType.other => '🏪',
};

MerchantType? _categoryNameToMerchantType(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('مطعم') || lower.contains('restaurant')) return MerchantType.restaurant;
  if (lower.contains('بقال') || lower.contains('grocery')) return MerchantType.grocery;
  if (lower.contains('سوبرماركت') || lower.contains('supermarket')) return MerchantType.supermarket;
  if (lower.contains('فاكهة') || lower.contains('fruit')) return MerchantType.fruits;
  if (lower.contains('لحوم') || lower.contains('meat')) return MerchantType.meat;
  if (lower.contains('سمك') || lower.contains('seafood')) return MerchantType.seafood;
  if (lower.contains('صيدل') || lower.contains('pharmacy')) return MerchantType.pharmacy;
  if (lower.contains('مخب') || lower.contains('bakery')) return MerchantType.bakery;
  if (lower.contains('حلوي') || lower.contains('sweet')) return MerchantType.sweets;
  if (lower.contains('ورود') || lower.contains('flower')) return MerchantType.flowers;
  if (lower.contains('ملابس') || lower.contains('clothing')) return MerchantType.clothing;
  if (lower.contains('احذي') || lower.contains('shoe')) return MerchantType.shoes;
  if (lower.contains('electronic') || lower.contains('إلكتروني')) return MerchantType.electronics;
  if (lower.contains('جوال') || lower.contains('mobile') || lower.contains('هاتف')) return MerchantType.mobile;
  if (lower.contains('اثاث') || lower.contains('furniture')) return MerchantType.furniture;
  if (lower.contains('أزياء') || lower.contains('fashion') || lower.contains('mode')) return MerchantType.fashion;
  if (lower.contains('أجهزة') || lower.contains('appliance')) return MerchantType.appliances;
  if (lower.contains('منزل') || lower.contains('home')) return MerchantType.home;
  if (lower.contains('كافيه') || lower.contains('قهوة') || lower.contains('cafe')) return MerchantType.cafe;
  if (lower.contains('حيوان') || lower.contains('pet')) return MerchantType.petShop;
  if (lower.contains('لياقة') || lower.contains('fitness')) return MerchantType.fitness;
  if (lower.contains('بنزين') || lower.contains('gas')) return MerchantType.gas;
  if (lower.contains('غسيل') || lower.contains('carwash')) return MerchantType.carwash;
  return null;
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final isGuest = authState is AuthGuest;
    final locationAsync = ref.watch(userLocationProvider);
    final unreadCount = isGuest
        ? 0
        : ref.watch(unreadCountProvider).value ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitConfirmation(context, l10n);
      },
      child: Scaffold(
      body: SafeArea(
        child: GradientBackground(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(nearbyMerchantsProvider);
              ref.invalidate(activeCategoriesProvider);
              ref.invalidate(discoveryMerchantsProvider);
              ref.invalidate(activeCampaignsProvider);
              ref.read(userLocationProvider.notifier).refreshQuick();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                final scrollingDown =
                    ScrollAwareNavObserver.handleScrollNotification(notification);
                ref.read(bottomNavVisibleProvider.notifier).state =
                    !scrollingDown;
                return false;
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
                  const SliverToBoxAdapter(child: _PromoCarousel()),
                  SliverToBoxAdapter(
                    child: _CompactCategories(ref: ref),
                  ),
                  SliverToBoxAdapter(
                    child: _buildDiscoverySection(context, ref, l10n),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              ),
            ),
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
      error: (_, _) => l10n.searchingForLocation,
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

  Widget _buildDiscoverySection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 350),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'اكتشف بالقرب منك',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/market'),
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
          const SizedBox(height: 10),
          const _DiscoveryTabs(),
          const SizedBox(height: 4),
          const _DiscoveryContent(),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusDialog),
        ),
        icon: Image.asset('assets/logo app/logo.png', height: 44),
        title: Text(l10n.exitAppTitle),
        content: Text(l10n.exitAppConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              SystemNavigator.pop();
            },
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
  }
}

class _CompactCategories extends StatelessWidget {
  const _CompactCategories({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeCategoriesProvider);

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 250),
      child: categoriesAsync.when(
        loading: () => SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => const ShimmerCard(height: 100),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (categories) {
          if (categories.isEmpty) return const SizedBox.shrink();
          return SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = categories[index];
                final merchantType = _categoryNameToMerchantType(category.name);
                final typeColor = merchantType != null
                    ? _merchantTypeColor(merchantType)
                    : AppColors.brandPurple;
                final emoji = merchantType != null
                    ? _merchantEmoji(merchantType)
                    : '🏪';

                return AnimatedFadeIn(
                  delay: Duration(milliseconds: 280 + index * 40),
                  child: PressableScale(
                    onTap: () {
                      final typeParam = merchantType?.name ?? 'other';
                      context.push('/market?type=$typeParam');
                    },
                    child: SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: category.imageUrl != null
                                ? Image.network(
                                    category.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _categoryFallback(
                                            typeColor, emoji),
                                  )
                                : _categoryFallback(typeColor, emoji),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category.displayName(
                              Directionality.of(context) == TextDirection.rtl,
                            ),
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 11,
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
              },
            ),
          );
        },
      ),
    );
  }

  Widget _categoryFallback(Color color, String emoji) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.38),
            color.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

class _DiscoveryTabs extends ConsumerStatefulWidget {
  const _DiscoveryTabs();

  @override
  ConsumerState<_DiscoveryTabs> createState() => _DiscoveryTabsState();
}

class _DiscoveryTabsState extends ConsumerState<_DiscoveryTabs> {
  int _selectedIndex = 0;

  static const _labels = ['القريبة', 'موصى لك', 'الأشهر'];
  static const _modes = [
    DiscoveryMode.nearby,
    DiscoveryMode.recommended,
    DiscoveryMode.popular,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _selectedIndex == index;
          return PressableScale(
            onTap: () {
              if (_selectedIndex == index) return;
              setState(() => _selectedIndex = index);
              ref.read(discoveryModeProvider.notifier).state = _modes[index];
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [AppColors.brandPurpleDeep, AppColors.brandViolet],
                      )
                    : null,
                color: selected
                    ? null
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                _labels[index],
                style: AppTextStyles.labelLarge.copyWith(
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiscoveryContent extends ConsumerWidget {
  const _DiscoveryContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(discoveryMerchantsProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: merchantsAsync.when(
        loading: () => SizedBox(
          key: const ValueKey('shimmer'),
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => const ShimmerCard(height: 212),
          ),
        ),
        error: (_, _) => Padding(
          key: const ValueKey('error'),
          padding: const EdgeInsets.all(20),
          child: PremiumEmptyState(
            icon: Icons.store_outlined,
            title: AppLocalizations.of(context).noResults,
            message: AppLocalizations.of(context).errorLoading,
          ),
        ),
        data: (merchants) {
          if (merchants.isEmpty) {
            return Padding(
              key: const ValueKey('empty'),
              padding: const EdgeInsets.all(20),
              child: PremiumEmptyState(
                icon: Icons.store_outlined,
                title: AppLocalizations.of(context).noResults,
                message: AppLocalizations.of(context).nearbyEmptyHint,
              ),
            );
          }
          return SizedBox(
            key: ValueKey('merchants_${merchants.length}'),
            height: 224,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              itemCount: merchants.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final merchant = merchants[index];
                return _HomeMerchantCard(
                  merchant: merchant,
                  onTap: () =>
                      context.push('/market/merchant/${merchant.id}'),
                );
              },
            ),
          );
        },
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
          errorBuilder: (_, _, _) => DecoratedBox(
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
          const Icon(
            Icons.location_on_rounded,
            size: 13,
            color: AppColors.brandPurple,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: loading
                ? const SizedBox(
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
                  decoration: const BoxDecoration(
                    borderRadius: AppSpacing.borderRadiusCard,
                    gradient: LinearGradient(
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
                              child: const Icon(
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

class _PromoCarousel extends ConsumerStatefulWidget {
  const _PromoCarousel();

  @override
  ConsumerState<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends ConsumerState<_PromoCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _current = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncAutoPlay(int count) {
    if (count == _count) return;
    _count = count;
    _timer?.cancel();
    _timer = null;
    if (_current >= count) _current = 0;
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_current + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _handleTap(BuildContext context, Campaign campaign) async {
    final l10n = AppLocalizations.of(context);
    final cta = campaign.cta;
    if (cta != null) {
      switch (cta.type) {
        case CampaignCtaType.copyCode:
          final code = cta.code;
          if (code == null) return;
          await Clipboard.setData(ClipboardData(text: code));
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
          return;
        case CampaignCtaType.externalUrl:
          final url = cta.url;
          if (url != null) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          }
          return;
        case CampaignCtaType.internalRoute:
          final route = cta.route;
          if (route != null &&
              NotificationChannels.isAllowed(route, context: AppContext.customer)) {
            context.push(route);
          }
          return;
        case CampaignCtaType.entity:
        case CampaignCtaType.none:
          break;
      }
    }
    if (context.mounted) context.push('/campaign/${campaign.id}');
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(activeCampaignsProvider);

    return campaignsAsync.when(
      loading: () => const _PromoCarouselLoading(),
      error: (_, _) => const SizedBox.shrink(),
      data: (campaigns) {
        if (campaigns.isEmpty) return const SizedBox.shrink();
        final count = campaigns.length;
        _syncAutoPlay(count);
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
                    itemCount: count,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (context, index) {
                      final campaign = campaigns[index];
                      return GestureDetector(
                        onTap: () => _handleTap(context, campaign),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _PromoSlide(campaign: campaign),
                        ),
                      );
                    },
                  ),
                ),
                if (count > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < count; i++)
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
                                : context.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PromoCarouselLoading extends StatelessWidget {
  const _PromoCarouselLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ShimmerBox(
        width: double.infinity,
        height: 140,
        borderRadius: 24,
      ),
    );
  }
}

List<Color> _campaignColors(Campaign campaign) {
  switch (campaign.priority) {
    case CampaignPriority.critical:
      return const [Color(0xFF991B1B), Color(0xFFF87171)];
    case CampaignPriority.important:
      return const [Color(0xFF92400E), Color(0xFFFBBF24)];
    case CampaignPriority.normal:
      switch (campaign.campaignType) {
        case CampaignType.coupon:
          return const [Color(0xFF0D9488), Color(0xFF14B8A6)];
        case CampaignType.offer:
        case CampaignType.promotion:
        case CampaignType.productPromotion:
        case CampaignType.servicePromotion:
          return const [AppColors.brandPurpleDeep, AppColors.brandViolet];
        case CampaignType.outage:
        case CampaignType.importantNotice:
        case CampaignType.emergencyNotice:
        case CampaignType.safetyNotice:
          return const [Color(0xFFBE185D), Color(0xFFF43F5E)];
        case CampaignType.announcement:
        case CampaignType.informational:
        case CampaignType.serviceAnnouncement:
          return const [Color(0xFF1E40AF), Color(0xFF3B82F6)];
      }
  }
}

class _PromoSlide extends ConsumerWidget {
  const _PromoSlide({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = campaign.nameAr.isNotEmpty
        ? campaign.nameAr
        : (campaign.nameEn ?? campaign.nameAr);
    final subtitle = campaign.subtitleAr?.isNotEmpty == true
        ? campaign.subtitleAr
        : campaign.subtitleEn;
    final colors = _campaignColors(campaign);
    final coupon = campaign.cta?.type == CampaignCtaType.copyCode
        ? campaign.cta?.code
        : null;
    final imageUrl = ref
        .watch(campaignMediaUrlProvider(campaign.imagePath))
        .value;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.first.withValues(alpha: 0.72),
                  colors.last.withValues(alpha: 0.86),
                ],
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
                        name,
                        style: context.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (coupon != null)
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
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (coupon != null) ...[
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
                      coupon,
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
                      errorBuilder: (_, _, _) => _merchantHeaderGradient(
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
                        const Icon(
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