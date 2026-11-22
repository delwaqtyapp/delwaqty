import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/utils/bidi_text.dart';
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
import 'package:delwaqty/features/customer/location/presentation/widgets/smart_map_picker_sheet.dart';
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
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
import 'package:delwaqty/shared/widgets/floating_glass_buttons.dart';

final _homeServiceCategoriesProvider = FutureProvider<List<ServiceCategory>>((
  ref,
) async {
  final repo = ref.watch(cachedServiceBookingRepositoryProvider);
  final all = await repo.getCategories();
  final sorted = [...all]
    ..sort(
      (a, b) =>
          serviceCategoryRank(a.type).compareTo(serviceCategoryRank(b.type)),
    );
  return sorted;
});

const _stripHeight = 124.0;
const _tileLabelHeight = 32.0;

void _precacheImageUrls(BuildContext context, Iterable<String> urls) {
  for (final url in urls) {
    if (url.isEmpty) continue;
    unawaited(precacheImage(NetworkImage(url), context, onError: (_, _) {}));
  }
}

List<_TileItem> get _allDefaultServiceItems =>
    serviceCategoryPriority.map((t) => _ServiceTile(t)).toList(growable: false);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final isGuest = authState is AuthGuest;
    final locationAsync = ref.watch(userLocationProvider);
    final unreadCount = isGuest ? 0 : ref.watch(unreadCountProvider).value ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Stack(
        children: [
          _precacheSection(context, ref),
          Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                unawaited(
                  ref.read(userLocationProvider.notifier).refreshQuick(),
                );
                try {
                  await Future.wait([
                    ref.refresh(nearbyMerchantsProvider.future),
                    ref.refresh(activeCategoriesProvider.future),
                    ref.refresh(discoveryEntriesProvider.future),
                    ref.refresh(activeCampaignsProvider.future),
                  ]);
                } catch (_) {}
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final scrollingDown =
                      ScrollAwareNavObserver.handleScrollNotification(
                        notification,
                      );
                  ref.read(bottomNavVisibleProvider.notifier).state =
                      !scrollingDown;
                  return false;
                },
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _EgyptHero(
                        ref: ref,
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
                    SliverToBoxAdapter(child: _CompactCategories(l10n: l10n)),
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
        ],
      ),
    );
  }

  /// Eagerly loads the network images used by the Main Categories strip and
  /// the discovery cards so scrolling never shows an empty white placeholder.
  Widget _precacheSection(BuildContext context, WidgetRef ref) {
    ref.listen(activeCategoriesProvider, (_, next) {
      final categories = next.value;
      if (categories != null) {
        _precacheImageUrls(context, categories.map((c) => c.imageUrl ?? ''));
      }
    });
    ref.listen(discoveryEntriesProvider, (_, next) {
      final entries = next.value;
      if (entries == null) return;
      _precacheImageUrls(context, [
        for (final e in entries)
          if (e is MerchantDiscoveryEntry)
            e.merchant.imageUrl ?? ''
          else if (e is ProviderDiscoveryEntry)
            e.provider.profileImageUrl ?? '',
      ]);
    });
    return const SizedBox.shrink();
  }

  Widget _buildDiscoverySection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          _DiscoveryTabs(l10n: l10n),
          const SizedBox(height: 6),
          const _DiscoveryContent(),
        ],
      ),
    );
  }
}

class _EgyptHero extends StatefulWidget {
  const _EgyptHero({
    required this.ref,
    required this.l10n,
    required this.authState,
    required this.isGuest,
    required this.locationAsync,
    required this.unreadCount,
  });

  final WidgetRef ref;
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

    // Hero height must never be smaller than its overlay content, otherwise a
    // tall status bar inset (notch devices) causes a bottom RenderFlex
    // overflow. Row 1 holds the mini lockup (~68dp) and Row 2 holds the
    // 48dp frosted-glass typewriter search bar.
    final topInset = MediaQuery.paddingOf(context).top;
    final contentCoreH = math.max(topButtonSize, 68.0) + zoneGap + 48.0 + 8.0;
    final contentH = topInset + 2 + contentCoreH;
    final heroH = math.max(heroImageH, contentH);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: SizedBox(
        height: heroH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/egypt/home_egypt_hero.webp'),
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
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
            ),
            Align(
              alignment: AlignmentDirectional.bottomStart,
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
                  maxWidth: screenWidth * 0.72,
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
                              FloatingNotificationCircleButton(
                                size: topButtonSize,
                                iconSize: topIconSize,
                                overDarkHero: true,
                              ),
                              const Spacer(),
                              _buildMiniLockup(
                                logoSize: logoSize,
                                arabicSize: arabicSize,
                              ),
                              const Spacer(),
                              FloatingMenuCircleButton(
                                size: topButtonSize,
                                iconSize: topIconSize,
                                overDarkHero: true,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: zoneGap),
                        _PremiumTypewriterSearchBar(
                          l10n: widget.l10n,
                          onTap: (anchor) => _GlassSearchPopupController.open(
                            context,
                            widget.ref,
                            anchor: anchor,
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
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (loc) => loc?.detailedAddress.isNotEmpty == true
          ? loc!.detailedAddress
          : widget.l10n.locationUnavailable,
      loading: () => widget.l10n.searchingForLocation,
      error: (_, _) => widget.l10n.searchingForLocation,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push('/region-selection'),
                child: Container(
                  height: height,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
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
                        child: _MarqueeLocationText(
                          text: locationText,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
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
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: height,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: height,
                height: height,
              ),
              tooltip: widget.l10n.pickLocationOnMap,
              icon: const Icon(
                Icons.map_rounded,
                size: 15,
                color: Colors.white,
              ),
              onPressed: () {
                unawaited(SmartMapPickerSheet.show(context));
              },
            ),
          ),
        ],
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
              'assets/egypt/delwaqty_logo_mark.webp',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [AppColors.brandPurpleDeep, AppColors.brandViolet],
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
              shadows: const [Shadow(color: Color(0x55000000), blurRadius: 3)],
            ),
          ),
        ),
      ],
    );
  }
}

class _MarqueeLocationText extends StatefulWidget {
  const _MarqueeLocationText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_MarqueeLocationText> createState() => _MarqueeLocationTextState();
}

class _MarqueeLocationTextState extends State<_MarqueeLocationText>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations) {
      _controller.stop();
      if (_scrollController.hasClients && _scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
    } else {
      _scheduleSync();
    }
  }

  @override
  void didUpdateWidget(covariant _MarqueeLocationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _controller.value = 0;
      if (_scrollController.hasClients && _scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
      _scheduleSync();
    }
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAnimation();
    });
  }

  void _syncAnimation() {
    if (_disableAnimations || !_scrollController.hasClients) {
      _controller.stop();
      return;
    }
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      _controller.stop();
      if (_scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
      return;
    }
    final durationMs = (maxExtent * 35).round().clamp(3500, 14000);
    final targetDuration = Duration(milliseconds: durationMs);
    if (_controller.duration != targetDuration) {
      _controller.duration = targetDuration;
    }
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  void _onTick() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final v = _controller.value;
    final double t;
    if (v <= 0.12) {
      t = 0.0;
    } else if (v >= 0.88) {
      t = 1.0;
    } else {
      t = (v - 0.12) / 0.76;
    }
    _scrollController.jumpTo(t * maxExtent);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        final textDirection = Directionality.of(context);
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: textDirection,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final overflows = painter.width > constraints.maxWidth + 1;

        if (!overflows || _disableAnimations) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
            overflow: overflows ? TextOverflow.ellipsis : TextOverflow.clip,
          );
        }

        final isRtl = textDirection == TextDirection.rtl;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: isRtl
                ? const [Colors.transparent, Colors.white, Colors.white]
                : const [Colors.white, Colors.white, Colors.transparent],
            stops: isRtl ? const [0.0, 0.10, 1.0] : const [0.0, 0.90, 1.0],
          ).createShader(bounds),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
      },
    );
  }
}

class _PremiumTypewriterSearchBar extends StatefulWidget {
  const _PremiumTypewriterSearchBar({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final void Function(Rect? anchor) onTap;

  @override
  State<_PremiumTypewriterSearchBar> createState() =>
      _PremiumTypewriterSearchBarState();
}

class _PremiumTypewriterSearchBarState
    extends State<_PremiumTypewriterSearchBar>
    with SingleTickerProviderStateMixin {
  final GlobalKey _barKey = GlobalKey();
  Timer? _timer;
  int _phraseIndex = 0;
  int _charIndex = 0;
  bool _isDeleting = false;
  bool _animationsDisabled = false;

  late final AnimationController _cursorController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..repeat(reverse: true);

  List<String> get _hints => [
    widget.l10n.searchHintRestaurants,
    widget.l10n.searchHintMarket,
    widget.l10n.searchHintServices,
    widget.l10n.searchHintDelivery,
  ];

  @override
  void initState() {
    super.initState();
    _scheduleNext(const Duration(milliseconds: 400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _animationsDisabled) {
      _animationsDisabled = disabled;
      if (disabled) {
        _timer?.cancel();
        _timer = null;
        _cursorController.stop();
        _cursorController.value = 1;
      } else {
        if (!_cursorController.isAnimating) {
          _cursorController.repeat(reverse: true);
        }
        _scheduleNext(const Duration(milliseconds: 300));
      }
    }
  }

  void _scheduleNext(Duration delay) {
    _timer?.cancel();
    if (_animationsDisabled) return;
    _timer = Timer(delay, _step);
  }

  void _step() {
    if (!mounted || _animationsDisabled) return;
    final hints = _hints;
    final currentChars = hints[_phraseIndex % hints.length].characters;
    var nextDelay = const Duration(milliseconds: 55);

    setState(() {
      if (!_isDeleting) {
        if (_charIndex < currentChars.length) {
          _charIndex++;
          nextDelay = _charIndex == currentChars.length
              ? const Duration(milliseconds: 1600)
              : const Duration(milliseconds: 55);
        } else {
          _isDeleting = true;
          nextDelay = const Duration(milliseconds: 30);
        }
      } else {
        if (_charIndex > 0) {
          _charIndex--;
          nextDelay = const Duration(milliseconds: 28);
        } else {
          _isDeleting = false;
          _phraseIndex = (_phraseIndex + 1) % hints.length;
          nextDelay = const Duration(milliseconds: 320);
        }
      }
    });

    _scheduleNext(nextDelay);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _cursorController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    final anchor = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    widget.onTap(anchor);
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final hints = _hints;
    final fullText = hints[_phraseIndex % hints.length];
    final displayText = _animationsDisabled
        ? fullText
        : fullText.characters
              .take(_charIndex.clamp(0, fullText.characters.length))
              .toString();

    return PressableScale(
      onTap: _handleTap,
      child: DecoratedBox(
        key: _barKey,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.38),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayText,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.96),
                              fontWeight: FontWeight.w500,
                              fontSize: 13.5,
                              shadows: const [
                                Shadow(color: Color(0x55000000), blurRadius: 4),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FadeTransition(
                          opacity: _cursorController,
                          child: Text(
                            '|',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.brandGold,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 24,
                    width: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Icon(
                      isRtl
                          ? Icons.arrow_back_rounded
                          : Icons.arrow_forward_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating transparent frosted-glass search menu anchored to the top hero
/// search bar so tapping the bar immediately pops out a live glass search list.
class _GlassSearchPopupController {
  _GlassSearchPopupController._();

  static OverlayEntry? _entry;

  static void open(BuildContext context, WidgetRef ref, {Rect? anchor}) {
    if (_entry != null) return;

    final router = GoRouter.maybeOf(context);
    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GlassSearchPopupOverlay(
        anchor: anchor,
        router: router,
        onDismiss: () {
          entry.remove();
          _entry = null;
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);
  }
}

class _GlassSearchPopupOverlay extends StatefulWidget {
  const _GlassSearchPopupOverlay({
    this.anchor,
    this.router,
    required this.onDismiss,
  });

  final Rect? anchor;
  final GoRouter? router;
  final VoidCallback onDismiss;

  @override
  State<_GlassSearchPopupOverlay> createState() =>
      _GlassSearchPopupOverlayState();
}

class _GlassSearchPopupOverlayState extends State<_GlassSearchPopupOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 170),
  );
  late final CurvedAnimation _pop = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close([VoidCallback? afterClose]) async {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismiss();
    afterClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final safeTop = mq.padding.top;
    final safeBottom = mq.padding.bottom;
    final viewInsetsBottom = mq.viewInsets.bottom;

    const margin = 14.0;
    final anchor = widget.anchor;
    final panelWidth = anchor != null
        ? anchor.width.clamp(260.0, size.width - margin * 2)
        : (size.width - margin * 2).clamp(260.0, 560.0);
    final left = anchor != null
        ? anchor.left.clamp(margin, size.width - panelWidth - margin)
        : (size.width - panelWidth) / 2;
    final top = anchor != null
        ? anchor.top.clamp(safeTop + 6, size.height * 0.35)
        : safeTop + 56;

    final availableBelow =
        size.height - top - math.max(safeBottom, viewInsetsBottom) - 12;
    final maxPanelHeight = math.min(440.0, math.max(170.0, availableBelow));

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.14)),
            ),
          ),
          Positioned(
            top: top,
            left: left,
            width: panelWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              child: AnimatedBuilder(
                animation: _pop,
                builder: (context, child) {
                  final t = _pop.value.clamp(0.0, 1.0);
                  final scale = 0.92 + 0.08 * t;
                  return Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  );
                },
                child: _GlassSearchPopupPanel(
                  onClose: _close,
                  router: widget.router,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSearchPopupPanel extends ConsumerStatefulWidget {
  const _GlassSearchPopupPanel({required this.onClose, required this.router});

  final Future<void> Function([VoidCallback? afterClose]) onClose;
  final GoRouter? router;

  @override
  ConsumerState<_GlassSearchPopupPanel> createState() =>
      _GlassSearchPopupPanelState();
}

class _GlassSearchPopupPanelState
    extends ConsumerState<_GlassSearchPopupPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateTo(String route, {Object? extra}) {
    final router = widget.router;
    unawaited(
      widget.onClose(() {
        if (router != null) {
          unawaited(router.push(route, extra: extra));
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1033);
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.76)
        : const Color(0xFF3E2E68).withValues(alpha: 0.80);

    final categories =
        ref.watch(activeCategoriesProvider).asData?.value ??
        const <PlatformCategory>[];
    final entries =
        ref.watch(discoveryEntriesProvider).asData?.value ??
        const <DiscoveryEntry>[];
    final nearbyMerchants =
        ref.watch(nearbyMerchantsProvider).asData?.value ?? const [];

    final q = _query.trim().toLowerCase();

    final matchedServices = <ServiceCategoryType>[];
    final matchedServiceType = q.isEmpty ? null : categoryNameToServiceType(q);
    for (final sType in serviceCategoryPriority) {
      final label = serviceTypeLabel(sType, l10n).toLowerCase();
      if (q.isEmpty ||
          label.contains(q) ||
          sType.name.toLowerCase().contains(q) ||
          matchedServiceType == sType) {
        matchedServices.add(sType);
      }
    }

    final matchedCategories = categories.where((c) {
      if (q.isEmpty) return true;
      final combined = '${c.name} ${c.nameAr ?? ''} ${c.nameEn ?? ''}'
          .toLowerCase();
      return combined.contains(q);
    }).toList();

    final combinedEntries = <DiscoveryEntry>[...entries];
    final existingMerchantIds = <String>{
      for (final e in entries)
        if (e is MerchantDiscoveryEntry) e.merchant.id,
    };
    for (final m in nearbyMerchants) {
      if (!existingMerchantIds.contains(m.id)) {
        combinedEntries.add(MerchantDiscoveryEntry(m));
      }
    }

    final matchedEntries = combinedEntries
        .where((entry) {
          if (q.isEmpty) return true;
          if (entry is MerchantDiscoveryEntry) {
            final m = entry.merchant;
            final tLabel = merchantTypeLabel(m.type, l10n).toLowerCase();
            return m.name.toLowerCase().contains(q) ||
                tLabel.contains(q) ||
                (m.description?.toLowerCase().contains(q) ?? false);
          }
          if (entry is ProviderDiscoveryEntry) {
            final p = entry.provider;
            final tLabel = serviceTypeLabel(p.categoryType, l10n).toLowerCase();
            return p.name.toLowerCase().contains(q) ||
                tLabel.contains(q) ||
                (p.description?.toLowerCase().contains(q) ?? false);
          }
          return false;
        })
        .take(10)
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.16),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF17112B).withValues(alpha: 0.68)
                  : Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.42),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 8, 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.brandPurple,
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.searchMerchantsProducts,
                            hintStyle: AppTextStyles.bodyMedium.copyWith(
                              color: subTextColor,
                              fontSize: 13.5,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                          onSubmitted: (_) => _navigateTo('/search'),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.backspace_outlined,
                            size: 18,
                            color: subTextColor,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: textColor,
                        ),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.28)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (matchedCategories.isNotEmpty ||
                            matchedServices.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.mainCategories,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: subTextColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _navigateTo('/services'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    l10n.viewAll,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.brandPurple,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              children: [
                                for (final c in matchedCategories.take(6))
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 6,
                                    ),
                                    child: _buildPopupChip(
                                      label: c.displayName(isRtl),
                                      icon: merchantCategoryIcon(
                                        '${c.name} ${c.nameAr ?? ''}',
                                      ),
                                      textColor: textColor,
                                      onTap: () {
                                        final combined =
                                            '${c.name} ${c.nameAr ?? ''} ${c.nameEn ?? ''}';
                                        final sType = categoryNameToServiceType(
                                          combined,
                                        );
                                        final mType =
                                            categoryNameToMerchantType(
                                              combined,
                                            );
                                        if (sType != null) {
                                          _navigateTo(
                                            '/home-services/providers/${sType.name}',
                                          );
                                        } else if (mType?.name == 'home' ||
                                            combined.toLowerCase().contains(
                                              'home service',
                                            )) {
                                          _navigateTo('/home-services');
                                        } else {
                                          _navigateTo(
                                            '/market?type=${mType?.name ?? 'other'}',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                for (final sType in matchedServices.take(10))
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 6,
                                    ),
                                    child: _buildPopupChip(
                                      label: serviceTypeLabel(sType, l10n),
                                      icon: serviceCategoryIcon(sType),
                                      textColor: textColor,
                                      onTap: () => _navigateTo(
                                        '/home-services/providers/${sType.name}',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (matchedEntries.isNotEmpty) ...[
                          Text(
                            l10n.discoverNearby,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: subTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final entry in matchedEntries)
                            _buildPopupEntryRow(
                              context,
                              entry: entry,
                              l10n: l10n,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              isRtl: isRtl,
                            ),
                        ] else if (matchedCategories.isEmpty &&
                            matchedServices.isEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 28,
                                    color: subTextColor,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    l10n.searchNoResults,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () => _navigateTo('/search'),
                                    icon: const Icon(
                                      Icons.manage_search_rounded,
                                      size: 18,
                                    ),
                                    label: Text(l10n.search),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildPopupChip({
    required String label,
    required IconData icon,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.brandPurple.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE5C158).withValues(alpha: 0.40),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.brandPurple),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupEntryRow(
    BuildContext context, {
    required DiscoveryEntry entry,
    required AppLocalizations l10n,
    required Color textColor,
    required Color subTextColor,
    required bool isRtl,
  }) {
    final String title;
    final String subtitle;
    final double rating;
    final IconData icon;
    final String? imageUrl;
    final VoidCallback onTap;

    if (entry is MerchantDiscoveryEntry) {
      final m = entry.merchant;
      title = m.name;
      subtitle = merchantTypeLabel(m.type, l10n);
      rating = m.rating;
      icon = merchantCategoryIcon(m.type.name);
      imageUrl = m.imageUrl;
      onTap = () => _navigateTo('/market/merchant/${m.id}');
    } else if (entry is ProviderDiscoveryEntry) {
      final p = entry.provider;
      title = p.name;
      subtitle = serviceTypeLabel(p.categoryType, l10n);
      rating = p.rating;
      icon = serviceCategoryIcon(p.categoryType);
      imageUrl = p.profileImageUrl;
      onTap = () => _navigateTo(
        '/home-services/category/${p.categoryType.name}',
        extra: p,
      );
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Category3dTileIcon(
                  color: AppColors.brandPurple,
                  icon: icon,
                  networkImageUrl: imageUrl,
                  size: 38,
                  borderRadius: 12,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: subTextColor,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppColors.rating,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isRtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: subTextColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
  bool _pressed = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 76,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                Color(0xFF1E1B4B),
                AppColors.brandPurple,
                AppColors.brandViolet,
                Color(0xFF0EA5E9),
              ],
              stops: [0.0, 0.35, 0.72, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1.2,
            ),
            boxShadow: [
              ...AppElevation.shadowGlow,
              BoxShadow(
                color: AppColors.brandPurple.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final pulse = (math.sin(t * math.pi * 2) + 1) * 0.5;
              final floatY = math.sin(t * math.pi * 2) * 2.0;
              final arrowNudge =
                  (isRtl ? -1 : 1) * math.sin(t * math.pi * 2) * 2.0;

              return Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final shiftX = (t * 2.6 - 0.8) * constraints.maxWidth;
                        return Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Transform.translate(
                            offset: Offset(shiftX, 0),
                            child: FractionallySizedBox(
                              widthFactor: 0.42,
                              heightFactor: 1.6,
                              child: Transform.rotate(
                                angle: -0.35,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.16),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: 0.90 + 0.16 * pulse,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.42 * (1 - pulse),
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: AlignmentDirectional.topStart,
                                    end: AlignmentDirectional.bottomEnd,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.30),
                                      Colors.white.withValues(alpha: 0.12),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.38),
                                  ),
                                ),
                                child: Transform.translate(
                                  offset: Offset(0, floatY),
                                  child: const Icon(
                                    Icons.two_wheeler_rounded,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E1B4B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    size: 12,
                                    color: AppColors.brandGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                  fontSize: 15.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.l10n.orderNowFast,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withValues(alpha: 0.22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.36),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Transform.translate(
                            offset: Offset(arrowNudge, 0),
                            child: Icon(
                              isRtl
                                  ? Icons.arrow_back_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
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
  const _ServiceTile(this.type, {this.iconUrl});
  final ServiceCategoryType type;
  final String? iconUrl;
}

class _CompactCategories extends ConsumerWidget {
  const _CompactCategories({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final servicesAsync = ref.watch(_homeServiceCategoriesProvider);
    final dbServices = servicesAsync.asData?.value ?? const <ServiceCategory>[];

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          categoriesAsync.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => _shimmerStrip(),
            error: (_, _) => _buildStrip(
              context,
              _mergeItems(const <PlatformCategory>[], dbServices),
            ),
            data: (categories) =>
                _buildStrip(context, _mergeItems(categories, dbServices)),
          ),
        ],
      ),
    );
  }

  List<_TileItem> _mergeItems(
    List<PlatformCategory> categories,
    List<ServiceCategory> dbServices,
  ) {
    final sortedCategories = [...categories]
      ..sort(
        (a, b) => categoryRank('${a.name} ${a.nameAr ?? ''} ${a.nameEn ?? ''}')
            .compareTo(
              categoryRank('${b.name} ${b.nameAr ?? ''} ${b.nameEn ?? ''}'),
            ),
      );

    final representedServices = <ServiceCategoryType>{};
    final items = <_TileItem>[];

    for (final c in sortedCategories) {
      final combined = '${c.name} ${c.nameAr ?? ''} ${c.nameEn ?? ''}';
      final sType = categoryNameToServiceType(combined);
      if (sType != null) {
        representedServices.add(sType);
      }
      items.add(_CategoryTile(c));
    }

    final serviceIcons = <ServiceCategoryType, String?>{
      for (final s in dbServices)
        if (s.iconUrl != null && s.iconUrl!.trim().isNotEmpty)
          s.type: s.iconUrl,
    };

    for (final s in dbServices) {
      if (s.type == ServiceCategoryType.other) continue;
      if (representedServices.add(s.type)) {
        items.add(_ServiceTile(s.type, iconUrl: s.iconUrl));
      }
    }

    for (final sType in serviceCategoryPriority) {
      if (representedServices.add(sType)) {
        items.add(_ServiceTile(sType, iconUrl: serviceIcons[sType]));
      }
    }

    return items.isEmpty ? _allDefaultServiceItems : items;
  }

  Widget _shimmerStrip() {
    return SizedBox(
      height: _stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, _) => const SizedBox(width: 74, child: ShimmerCard()),
      ),
    );
  }

  Widget _buildStrip(BuildContext context, List<_TileItem> items) {
    return SizedBox(
      height: _stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _buildTile(context, items[index]),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _TileItem item) => switch (item) {
    _CategoryTile(:final category) => _buildCategoryTile(context, category),
    _ServiceTile(:final type, :final iconUrl) => _buildServiceTile(
      context,
      type,
      iconUrl: iconUrl,
    ),
  };

  Widget _buildCategoryTile(BuildContext context, PlatformCategory category) {
    final combinedName =
        '${category.name} ${category.nameAr ?? ''} ${category.nameEn ?? ''}';
    final serviceType = categoryNameToServiceType(combinedName);
    final merchantType = categoryNameToMerchantType(combinedName);

    final icon = serviceType != null
        ? serviceCategoryIcon(serviceType)
        : merchantCategoryIcon(combinedName);
    final fallbackUrl = serviceType != null
        ? defaultServiceImageUrl(serviceType)
        : defaultCategoryImageUrl(combinedName);

    return PressableScale(
      onTap: () {
        if (serviceType != null) {
          context.push('/home-services/providers/${serviceType.name}');
        } else if (merchantType?.name == 'home' ||
            combinedName.toLowerCase().contains('home service')) {
          context.push('/home-services');
        } else {
          final typeParam = merchantType?.name ?? 'other';
          context.push('/market?type=$typeParam');
        }
      },
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Category3dTileIcon(
              color: AppColors.brandPurple,
              icon: icon,
              networkImageUrl: category.imageUrl,
              assetImagePath: merchantCategoryAsset(combinedName),
              fallbackImageUrl: fallbackUrl,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: _tileLabelHeight,
              child: Center(
                child: Text(
                  category.displayName(
                    Directionality.of(context) == TextDirection.rtl,
                  ),
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTile(
    BuildContext context,
    ServiceCategoryType type, {
    String? iconUrl,
  }) {
    final icon = serviceCategoryIcon(type);
    final label = serviceTypeLabel(type, AppLocalizations.of(context));

    return PressableScale(
      onTap: () => context.push('/home-services/providers/${type.name}'),
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Category3dTileIcon(
              color: AppColors.brandPurple,
              icon: icon,
              networkImageUrl: iconUrl,
              fallbackImageUrl: defaultServiceImageUrl(type),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: _tileLabelHeight,
              child: Center(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayfulServiceCardReveal extends StatelessWidget {
  const _PlayfulServiceCardReveal({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delayMs = (index * 65).clamp(0, 520);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 460 + delayMs),
      curve: Curves.easeOutBack,
      builder: (context, value, animatedChild) {
        final safeOpacity = value.clamp(0.0, 1.0);
        final slideY = (1.0 - value) * 26.0;
        final scale = 0.90 + (0.10 * value);
        return Opacity(
          opacity: safeOpacity,
          child: Transform.translate(
            offset: Offset(0, slideY),
            child: Transform.scale(scale: scale, child: animatedChild),
          ),
        );
      },
      child: child,
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _labels.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final selected = _selectedIndex == index;
            return PressableScale(
              onTap: () {
                if (_selectedIndex == index) return;
                setState(() => _selectedIndex = index);
                ref.read(discoveryModeProvider.notifier).state = _modes[index];
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [
                            AppColors.brandPurpleDeep,
                            AppColors.brandViolet,
                          ],
                        )
                      : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.brandPurple.withValues(
                              alpha: 0.28,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _labels[index],
                    style: AppTextStyles.labelLarge.copyWith(
                      color: selected ? Colors.white : cs.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DiscoveryContent extends ConsumerWidget {
  const _DiscoveryContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(discoveryEntriesProvider);
    final mode = ref.watch(discoveryModeProvider);

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
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
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
            key: ValueKey('entries_${mode.name}_${entries.length}'),
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _PlayfulServiceCardReveal(
                    key: ValueKey('card_${mode.name}_$i'),
                    index: i,
                    child: _buildEntryCard(context, entries[i]),
                  ),
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
        typeLabel: merchantTypeLabel(
          merchant.type,
          AppLocalizations.of(context),
        ),
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
        typeLabel: serviceTypeLabel(
          provider.categoryType,
          AppLocalizations.of(context),
        ),
        open: provider.isAvailable,
        openLabel: provider.isAvailable
            ? AppLocalizations.of(context).available
            : AppLocalizations.of(context).unavailable,
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
              NotificationChannels.isAllowed(
                route,
                context: AppContext.customer,
              )) {
            unawaited(context.push(route));
          }
          return;
        case CampaignCtaType.entity:
        case CampaignCtaType.none:
          break;
      }
    }
    if (context.mounted) {
      unawaited(context.push('/campaign/${campaign.id}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(activeCampaignsProvider);

    return campaignsAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
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
                                : context.colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
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
      child: ShimmerBox(width: double.infinity, height: 205, borderRadius: 24),
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
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final name = (!isRtl && campaign.nameEn?.isNotEmpty == true)
        ? campaign.nameEn!
        : (campaign.nameAr.isNotEmpty
              ? campaign.nameAr
              : (campaign.nameEn ?? campaign.nameAr));
    final subtitle = (!isRtl && campaign.subtitleEn?.isNotEmpty == true)
        ? campaign.subtitleEn
        : (campaign.subtitleAr?.isNotEmpty == true
              ? campaign.subtitleAr
              : campaign.subtitleEn);
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
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: colors,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.34),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
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

Widget merchantHeaderGradient(BuildContext context, Color color, String emoji) {
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.15)],
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            merchantHeaderGradient(context, color, emoji),
                      )
                    : merchantHeaderGradient(context, color, emoji),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isolateLtr(name),
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(open: open, label: openLabel),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.rating.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppColors.rating,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            if (ratingCount > 0) ...[
                              const SizedBox(width: 2),
                              Text(
                                '($ratingCount)',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
                    const SizedBox(height: 9),
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
    final dotColor = open ? AppColors.successLight : AppColors.errorLight;
    final bg = dotColor.withValues(alpha: 0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dotColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              color: dotColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
