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
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/shared/widgets/scroll_aware_nav.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/core/theme/app_icons.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';

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

String _serviceLabel(ServiceCategoryType t) => switch (t) {
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

IconData _serviceIcon(ServiceCategoryType t) => switch (t) {
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

const _topBookingTypes = <ServiceCategoryType>[
  ServiceCategoryType.doctor,
  ServiceCategoryType.nurse,
  ServiceCategoryType.teacher,
  ServiceCategoryType.barber,
];

List<_TileItem> get _topBookingItems =>
    _topBookingTypes.map((t) => _ServiceTile(t)).toList(growable: false);

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: RefreshIndicator(
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
                  child: _EgyptHero(
                    l10n: l10n,
                    authState: authState,
                    isGuest: isGuest,
                    locationAsync: locationAsync,
                    unreadCount: unreadCount,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: _DirectOrderButton(
                      l10n: l10n,
                      onTap: () => context.push('/direct-delivery'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CompactCategories(ref: ref, l10n: l10n),
                ),
                const SliverToBoxAdapter(child: _PromoCarousel()),
                SliverToBoxAdapter(
                  child: _buildDiscoverySection(context, ref, l10n),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.discoverNearby,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.nearbySubtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/market'),
                  child: Text(
                    l10n.viewAll,
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
          _DiscoveryTabs(l10n: l10n),
          const SizedBox(height: 4),
          const _DiscoveryContent(),
        ],
      ),
    );
  }
}

class _EgyptHero extends StatefulWidget {
  const _EgyptHero({
    required this.l10n,
    required this.authState,
    required this.isGuest,
    required this.locationAsync,
    required this.unreadCount,
  });

  final AppLocalizations l10n;
  final AuthState authState;
  final bool isGuest;
  final AsyncValue<UserLocation?> locationAsync;
  final int unreadCount;

  @override
  State<_EgyptHero> createState() => _EgyptHeroState();
}

class _EgyptHeroState extends State<_EgyptHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _reveal.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;

    // The hero is exactly the image's natural-fit height: the direct-order
    // button lives right below the image bottom edge (its own sliver).
    // Natural aspect of assets/egypt/home_egypt_hero.png (1821x864).
    final heroImageH = screenWidth * (864 / 1821);

    final horizontalPadding = (screenWidth * 0.055).clamp(16.0, 28.0);
    final topButtonSize = (screenWidth * 0.095).clamp(36.0, 44.0);
    final topIconSize = (topButtonSize * 0.44).clamp(18.0, 22.0);
    const logoSize = 44.0;
    const arabicSize = 12.0;
    final zoneGap = (screenHeight * 0.008).clamp(4.0, 9.0);
    final greetingName = widget.authState is AuthAuthenticated
        ? (widget.authState as AuthAuthenticated).user.fullName
        : null;

    // Hero height must never be smaller than its overlay content, otherwise a
    // tall status bar inset (notch devices) causes a bottom RenderFlex
    // overflow. The second row holds the search circle + the user greeting
    // (~60dp worst case); take the max against the image height.
    final topInset = MediaQuery.paddingOf(context).top;
    final contentCoreH = topButtonSize + zoneGap + 88.0;
    final contentH = topInset + 2 + contentCoreH;
    final heroH = math.max(heroImageH, contentH);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(28),
      ),
      child: SizedBox(
        height: heroH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/egypt/home_egypt_hero.png'),
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  12,
                  (heroH - heroImageH) + 12,
                ),
                child: _buildLocationBadge(
                  context,
                  height: 28,
                  maxWidth: 150,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF2E146F).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      2,
                      horizontalPadding,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            children: [
                              _NotificationCircle(
                                unreadCount: widget.unreadCount,
                                onTap: widget.isGuest
                                    ? () => context.push('/login')
                                    : () => context.push('/notifications'),
                                size: topButtonSize,
                                iconSize: topIconSize,
                              ),
                              const Spacer(),
                              _buildMiniLockup(
                                logoSize: logoSize,
                                arabicSize: arabicSize,
                              ),
                              const Spacer(),
                              _MenuCircleButton(
                                onTap: () => AppShell.scaffoldKey
                                    .currentState
                                    ?.openDrawer(),
                                size: topButtonSize,
                                iconSize: topIconSize,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: zoneGap),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SearchCircleButton(
                                onTap: () => context.push('/search'),
                                size: topButtonSize,
                                iconSize: topIconSize,
                              ),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: _UserGreeting(
                                    l10n: widget.l10n,
                                    name: greetingName,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBadge(
    BuildContext context, {
    required double height,
    required double maxWidth,
  }) {
    final locationText = widget.locationAsync.when(
      data: (loc) => loc?.detailedAddress.isNotEmpty == true
          ? loc!.detailedAddress
          : widget.l10n.locationUnavailable,
      loading: () => widget.l10n.searchingForLocation,
      error: (_, _) => widget.l10n.searchingForLocation,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                locationText,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniLockup({
    required double logoSize,
    required double arabicSize,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              'assets/egypt/delwaqty_logo_mark.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.brandPurpleDeep,
                      AppColors.brandViolet,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.apps_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 1),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            widget.l10n.appNameAr,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: arabicSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF7F7FA),
              letterSpacing: 0.5,
              shadows: const [
                Shadow(color: Color(0x55000000), blurRadius: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchCircleButton extends StatelessWidget {
  const _SearchCircleButton({
    required this.onTap,
    this.size = 54,
    this.iconSize = 24,
  });

  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          AppIcons.actionSearch,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}

class _UserGreeting extends StatelessWidget {
  const _UserGreeting({required this.l10n, this.name});

  final AppLocalizations l10n;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final titleSize = (screenWidth * 0.05).clamp(18.0, 22.0);
    final taglineSize = (screenWidth * 0.030).clamp(11.0, 13.0);
    final hasName = name != null && name!.isNotEmpty;
    final greeting = hasName ? '${l10n.welcome}، $name' : l10n.welcome;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          greeting,
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.brandGold,
            fontWeight: FontWeight.w900,
            fontSize: titleSize,
          ),
          textAlign: TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          l10n.greetingSubtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: taglineSize,
            shadows: const [
              Shadow(color: Color(0x55000000), blurRadius: 4),
            ],
          ),
          textAlign: TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DirectOrderButton extends StatefulWidget {
  const _DirectOrderButton({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  State<_DirectOrderButton> createState() => _DirectOrderButtonState();
}

class _DirectOrderButtonState extends State<_DirectOrderButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 60,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(30)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandPurple, AppColors.brandBlue],
          ),
          boxShadow: AppElevation.shadowGlow,
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final ping = math.sin(t * math.pi);
            final slide = (ping * 2 - 1) * 16;
            final bob = math.sin(t * math.pi * 2) * 1.5;
            final wind = math.cos(t * math.pi);
            return Row(
              children: [
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Speed wind trailing behind the motorcycle — it
                      // stretches opposite the travel direction and fades
                      // near the turnarounds (where speed drops to zero).
                      for (var i = 0; i < 4; i++)
                        Opacity(
                          opacity: (0.55 - i * 0.14).clamp(0.08, 0.55),
                          child: Transform.translate(
                            offset: Offset(
                              slide - wind * (12 + 8 * i),
                              bob,
                            ),
                            child: Container(
                              width: 16 - i * 2.2,
                              height: i >= 2 ? 2.5 : 3,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x30FFFFFF),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Opacity(
                        opacity: 0.12,
                        child: Transform.translate(
                          offset: Offset(-slide * 2.4, bob * 2),
                          child: const Icon(
                            Icons.two_wheeler_rounded,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: 0.3,
                        child: Transform.translate(
                          offset: Offset(-slide * 1.4, bob * 1.4),
                          child: const Icon(
                            Icons.two_wheeler_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(slide, bob),
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.l10n.orderDirectly,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.l10n.fastestWayToOrder,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    isRtl
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}

sealed class _TileItem {
  const _TileItem();
}

class _CategoryTile extends _TileItem {
  const _CategoryTile(this.category);
  final PlatformCategory category;
}

class _ServiceTile extends _TileItem {
  const _ServiceTile(this.type);
  final ServiceCategoryType type;
}

class _CompactCategories extends StatelessWidget {
  const _CompactCategories({required this.ref, required this.l10n});

  final WidgetRef ref;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final servicesAsync = ref.watch(_homeServiceCategoriesProvider);

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.mainCategories,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/services'),
                  child: Text(
                    l10n.viewAll,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          categoriesAsync.when(
            loading: () => _shimmerStrip(),
            error: (_, _) => _buildStrip(context, _topBookingItems),
            data: (categories) => servicesAsync.when(
              loading: () => _shimmerStrip(),
              error: (_, _) => _buildStrip(context, _topBookingItems),
              data: (services) {
                if (categories.isEmpty && services.isEmpty) {
                  return _buildStrip(context, _topBookingItems);
                }
                final sorted = [...categories]
                  ..sort(
                    (a, b) =>
                        categoryRank(a.name).compareTo(categoryRank(b.name)),
                  );
                final items = <_TileItem>[
                  for (final c in sorted) _CategoryTile(c),
                  for (final s in services) _ServiceTile(s.type),
                ];
                return _buildStrip(context, items);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerStrip() {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) =>
            const SizedBox(width: 150, child: ShimmerCard(height: 108)),
      ),
    );
  }

  Widget _buildStrip(BuildContext context, List<_TileItem> items) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _buildTile(context, items[index], index),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _TileItem item, int index) =>
      switch (item) {
        _CategoryTile(:final category) =>
          _buildCategoryTile(context, category, index),
        _ServiceTile(:final type) => _buildServiceTile(context, type, index),
      };

  Widget _buildCategoryTile(
    BuildContext context,
    PlatformCategory category,
    int index,
  ) {
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
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      typeColor.withValues(alpha: 0.38),
                      typeColor.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: typeColor.withValues(alpha: 0.25)),
                ),
                child: category.imageUrl != null
                    ? Image.network(
                        category.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _emojiFallback(emoji),
                      )
                    : _emojiFallback(emoji),
              ),
              const SizedBox(height: 6),
              Text(
                category.displayName(
                  Directionality.of(context) == TextDirection.rtl,
                ),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 13,
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

  Widget _buildServiceTile(
    BuildContext context,
    ServiceCategoryType type,
    int index,
  ) {
    final color = _serviceColor(type);
    final icon = _serviceIcon(type);
    final label = _serviceLabel(type);

    return AnimatedFadeIn(
      delay: Duration(milliseconds: 280 + index * 40),
      child: PressableScale(
        onTap: () => context.push(
          type == ServiceCategoryType.deliveryCar
              ? '/home-services/cars'
              : '/home-services/providers/${type.name}',
        ),
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.38),
                      color.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 13,
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

  Widget _emojiFallback(String emoji) {
    return Center(
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    );
  }
}

class _DiscoveryTabs extends ConsumerStatefulWidget {
  const _DiscoveryTabs({required this.l10n});

  final AppLocalizations l10n;

  @override
  ConsumerState<_DiscoveryTabs> createState() => _DiscoveryTabsState();
}

class _DiscoveryTabsState extends ConsumerState<_DiscoveryTabs> {
  int _selectedIndex = 0;

  static const _modes = [
    DiscoveryMode.nearby,
    DiscoveryMode.recommended,
    DiscoveryMode.popular,
  ];

  List<String> get _labels => [
    widget.l10n.closest,
    widget.l10n.topRated,
    widget.l10n.mostRequested,
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

class _MenuCircleButton extends StatelessWidget {
  const _MenuCircleButton({
    required this.onTap,
    this.size = 54,
    this.iconSize = 24,
  });

  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          AppIcons.navDrawer,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}

class _NotificationCircle extends StatelessWidget {
  const _NotificationCircle({
    required this.unreadCount,
    required this.onTap,
    this.size = 54,
    this.iconSize = 24,
  });

  final int unreadCount;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: iconSize,
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
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
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
                  height: 205,
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
        height: 205,
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
      radius: 22,
      color: context.colorScheme.surfaceContainerLowest,
      borderColor: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 110,
                height: 110,
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
                            maxLines: 1,
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