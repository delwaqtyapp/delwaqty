import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
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
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/shared/widgets/scroll_aware_nav.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
import 'package:delwaqty/features/admin/floating_sidebar/floating_sidebar.dart';

final _homeServiceCategoriesProvider =
    FutureProvider<List<ServiceCategory>>((ref) async {
  final repo = ref.watch(cachedServiceBookingRepositoryProvider);
  final all = await repo.getCategories();
  const priority = [
    ServiceCategoryType.doctor,
    ServiceCategoryType.nurse,
    ServiceCategoryType.teacher,
    ServiceCategoryType.barber,
    ServiceCategoryType.deliveryCar,
    ServiceCategoryType.plumbing,
    ServiceCategoryType.electrical,
    ServiceCategoryType.carpentry,
    ServiceCategoryType.painting,
    ServiceCategoryType.cleaning,
    ServiceCategoryType.acMaintenance,
    ServiceCategoryType.pipeChange,
    ServiceCategoryType.plastering,
    ServiceCategoryType.carpetCleaning,
    ServiceCategoryType.dishRepair,
    ServiceCategoryType.pestControl,
    ServiceCategoryType.applianceRepair,
  ];
  int rank(ServiceCategoryType t) {
    final i = priority.indexOf(t);
    return i == -1 ? priority.length : i;
  }

  final sorted = [...all]..sort((a, b) => rank(a.type).compareTo(rank(b.type)));
  return sorted;
});

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

    return Scaffold(
      body: SafeArea(
        child: GradientBackground(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(nearbyMerchantsProvider);
              ref.invalidate(activeCategoriesProvider);
              ref.invalidate(discoveryEntriesProvider);
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
                  const SliverToBoxAdapter(
                    child: _ServicesSection(),
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
          // Daily/repeat demand first, the rest behind "view all".
          final sorted = [...categories]..sort(
              (a, b) => categoryRank(a.name).compareTo(categoryRank(b.name)),
            );
          const visibleCount = 6;
          final showAllTile = sorted.length > visibleCount;
          final visible = showAllTile
              ? sorted.sublist(0, visibleCount)
              : sorted;
          return SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              itemCount: visible.length + (showAllTile ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index >= visible.length) {
                  return AnimatedFadeIn(
                    delay: Duration(
                        milliseconds: 280 + visible.length * 40),
                    child: PressableScale(
                      onTap: () => context.push('/services'),
                      child: SizedBox(
                        width: 80,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.brandPurpleDeep,
                                    AppColors.brandViolet,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.apps_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocalizations.of(context).viewAll,
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
                }
                final category = visible[index];
                final merchantType = categoryNameToMerchantType(category.name);
                final typeColor = merchantType != null
                    ? merchantTypeColor(merchantType)
                    : AppColors.brandPurple;
                final emoji = merchantType != null
                    ? merchantEmoji(merchantType)
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

/// Horizontal "الخدمات" section on the home page: all booking service
/// categories in priority order — each tile opens its own service page.
class _ServicesSection extends ConsumerWidget {
  const _ServicesSection();

  String _label(ServiceCategoryType t) => switch (t) {
        ServiceCategoryType.doctor => 'حجز دكتور',
        ServiceCategoryType.nurse => 'ممرض',
        ServiceCategoryType.teacher => 'مدرسين',
        ServiceCategoryType.barber => 'حجز حلاق',
        ServiceCategoryType.deliveryCar => 'سيارة توصيل',
        ServiceCategoryType.plumbing => 'سباكة',
        ServiceCategoryType.electrical => 'كهرباء',
        ServiceCategoryType.carpentry => 'نجارة',
        ServiceCategoryType.painting => 'دهان',
        ServiceCategoryType.cleaning => 'تنظيف',
        ServiceCategoryType.acMaintenance => 'صيانة تكييف',
        ServiceCategoryType.pipeChange => 'تغيير أنبوبة',
        ServiceCategoryType.plastering => 'نقاشة',
        ServiceCategoryType.carpetCleaning => 'غسيل السجاد',
        ServiceCategoryType.dishRepair => 'إصلاح الدش',
        ServiceCategoryType.pestControl => 'مكافحة حشرات',
        ServiceCategoryType.applianceRepair => 'إصلاح أجهزة',
        ServiceCategoryType.other => 'خدمات أخرى',
      };

  IconData _icon(ServiceCategoryType t) => switch (t) {
        ServiceCategoryType.doctor => Icons.medical_services_rounded,
        ServiceCategoryType.nurse => Icons.health_and_safety_rounded,
        ServiceCategoryType.teacher => Icons.school_rounded,
        ServiceCategoryType.barber => Icons.content_cut_rounded,
        ServiceCategoryType.deliveryCar => Icons.local_taxi_rounded,
        ServiceCategoryType.plumbing => Icons.plumbing_rounded,
        ServiceCategoryType.electrical => Icons.electrical_services_rounded,
        ServiceCategoryType.carpentry => Icons.carpenter_rounded,
        ServiceCategoryType.painting => Icons.format_paint_rounded,
        ServiceCategoryType.cleaning => Icons.cleaning_services_rounded,
        ServiceCategoryType.acMaintenance => Icons.ac_unit_rounded,
        ServiceCategoryType.pipeChange => Icons.settings_input_component_rounded,
        ServiceCategoryType.plastering => Icons.format_color_fill_rounded,
        ServiceCategoryType.carpetCleaning => Icons.local_laundry_service_rounded,
        ServiceCategoryType.dishRepair => Icons.satellite_alt_rounded,
        ServiceCategoryType.pestControl => Icons.bug_report_rounded,
        ServiceCategoryType.applianceRepair => Icons.build_rounded,
        ServiceCategoryType.other => Icons.home_repair_service_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(_homeServiceCategoriesProvider);
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          servicesAsync.when(
            loading: () => SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) =>
                    const ShimmerBox(width: 90, height: 100),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (services) {
              if (services.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  itemCount: services.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final color = _serviceColor(service.type);
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: 320 + index * 40),
                      child: PressableScale(
                        onTap: () => context.push(
                          service.type == ServiceCategoryType.deliveryCar
                              ? '/home-services/cars'
                              : '/home-services/providers/${service.type.name}',
                        ),
                        child: SizedBox(
                          width: 92,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      color.withValues(alpha: 0.35),
                                      color.withValues(alpha: 0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Icon(_icon(service.type),
                                    color: color, size: 26),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _label(service.type),
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
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
        ],
      ),
    );
  }

  Color _serviceColor(ServiceCategoryType t) => switch (t) {
        ServiceCategoryType.doctor => AppColors.errorLight,
        ServiceCategoryType.nurse => AppColors.successLight,
        ServiceCategoryType.teacher => AppColors.infoLight,
        ServiceCategoryType.barber => AppColors.brandViolet,
        ServiceCategoryType.deliveryCar => AppColors.serviceDelivery,
        ServiceCategoryType.plumbing => AppColors.serviceHome,
        ServiceCategoryType.electrical => AppColors.serviceElectronics,
        ServiceCategoryType.carpentry => AppColors.serviceBakery,
        ServiceCategoryType.painting => AppColors.serviceFashion,
        ServiceCategoryType.cleaning => AppColors.serviceDelivery,
        ServiceCategoryType.acMaintenance => AppColors.serviceSeafood,
        ServiceCategoryType.pipeChange => AppColors.serviceGrocery,
        ServiceCategoryType.plastering => AppColors.serviceFurniture,
        ServiceCategoryType.carpetCleaning => AppColors.serviceCafe,
        ServiceCategoryType.dishRepair => AppColors.serviceElectronics,
        ServiceCategoryType.pestControl => AppColors.serviceGas,
        ServiceCategoryType.applianceRepair => AppColors.serviceAppliances,
        ServiceCategoryType.other => AppColors.serviceMore,
      };
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
    final entriesAsync = ref.watch(discoveryEntriesProvider);

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
      child: entriesAsync.when(
        loading: () => Column(
          key: const ValueKey('shimmer'),
          children: [
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: ShimmerCard(height: 96),
              ),
          ],
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
        data: (entries) {
          if (entries.isEmpty) {
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
          return Column(
            key: ValueKey('entries_${entries.length}'),
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _buildEntryCard(context, entries[i]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, DiscoveryEntry entry) {
    if (entry is MerchantDiscoveryEntry) {
      final merchant = entry.merchant;
      return _HomeDiscoveryListCard(
        imageUrl: merchant.imageUrl,
        emoji: merchantEmoji(merchant.type),
        color: merchantTypeColor(merchant.type),
        name: merchant.name,
        typeLabel: merchantTypeLabel(merchant.type, AppLocalizations.of(context)),
        open: merchant.isOpenNow,
        openLabel: merchant.isOpenNow
            ? AppLocalizations.of(context).open
            : AppLocalizations.of(context).closed,
        rating: merchant.rating,
        ratingCount: merchant.ratingCount,
        subtitle: merchant.deliveryAvailable && (merchant.deliveryFee ?? 0) > 0
            ? '${(merchant.deliveryFee ?? 0).toStringAsFixed(0)} ${AppLocalizations.of(context).currencySymbol}'
            : merchant.deliveryAvailable
                ? AppLocalizations.of(context).freeDelivery
                : merchant.estimatedDeliveryMinutes != null
                    ? '${merchant.estimatedDeliveryMinutes} ${AppLocalizations.of(context).minutesShort}'
                    : null,
        favoriteId: merchant.id,
        onTap: () => context.push('/market/merchant/${merchant.id}'),
      );
    }
    if (entry is ProviderDiscoveryEntry) {
      final provider = entry.provider;
      return _HomeDiscoveryListCard(
        imageUrl: provider.profileImageUrl,
        emoji: serviceTypeEmoji(provider.categoryType),
        color: serviceTypeColor(provider.categoryType),
        name: provider.name,
        typeLabel: serviceTypeLabel(provider.categoryType),
        open: provider.isAvailable,
        openLabel: provider.isAvailable ? 'متاح' : 'غير متاح',
        rating: provider.rating,
        ratingCount: provider.ratingCount,
        subtitle: provider.hourlyRate != null
            ? '${provider.hourlyRate!.toStringAsFixed(0)} ${AppLocalizations.of(context).currencySymbol}/${AppLocalizations.of(context).perHour}'
            : null,
        onTap: () => context.push(
          '/home-services/category/${provider.categoryType.name}',
          extra: provider,
        ),
      );
    }
    return const SizedBox.shrink();
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

Widget merchantHeaderGradient(
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

class _HomeDiscoveryListCard extends StatelessWidget {
  const _HomeDiscoveryListCard({
    required this.name,
    required this.typeLabel,
    required this.emoji,
    required this.color,
    required this.open,
    required this.openLabel,
    required this.rating,
    required this.ratingCount,
    required this.onTap,
    this.imageUrl,
    this.subtitle,
    this.favoriteId,
  });

  final String name;
  final String typeLabel;
  final String emoji;
  final Color color;
  final bool open;
  final String openLabel;
  final double rating;
  final int ratingCount;
  final VoidCallback onTap;
  final String? imageUrl;
  final String? subtitle;
  final String? favoriteId;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      color: context.colorScheme.surfaceContainerLowest,
      borderColor: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 72,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => merchantHeaderGradient(
                          context,
                          color,
                          emoji,
                        ),
                      )
                    : merchantHeaderGradient(context, color, emoji),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusBadge(open: open, label: openLabel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          typeLabel,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: AppColors.rating,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (ratingCount > 0) ...[
                        const SizedBox(width: 3),
                        Text(
                          '($ratingCount)',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (favoriteId != null)
                        FavoriteButton(
                          targetId: favoriteId!,
                          type: FavoriteType.merchant,
                          size: 18,
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
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
                            subtitle!,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppColors.brandPurple,
                              fontWeight: FontWeight.w600,
                            ),
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