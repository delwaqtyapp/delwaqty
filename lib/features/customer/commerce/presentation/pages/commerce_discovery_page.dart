import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/merchant_card.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/merchant_type_chip.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/cart_badge.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

final _merchantsFutureProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchants();
});

final _featuredFutureProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getFeaturedMerchants();
});

final _selectedTypeProvider = StateProvider<MerchantType?>((_) => null);

class CommerceDiscoveryPage extends ConsumerStatefulWidget {
  const CommerceDiscoveryPage({super.key});

  @override
  ConsumerState<CommerceDiscoveryPage> createState() =>
      _CommerceDiscoveryPageState();
}

class _CommerceDiscoveryPageState extends ConsumerState<CommerceDiscoveryPage> {
  bool _initialFilterSet = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selectedType = ref.watch(_selectedTypeProvider);
    final merchantsAsync = ref.watch(_merchantsFutureProvider);
    final featuredAsync = ref.watch(_featuredFutureProvider);

    final extra = GoRouterState.of(context).uri.queryParameters['type'];
    if (!_initialFilterSet && extra != null) {
      _initialFilterSet = true;
      final match = MerchantType.values
          .where((t) => t.name == extra)
          .firstOrNull;
      if (match != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(_selectedTypeProvider.notifier).state = match;
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedType != null
              ? merchantTypeLabel(selectedType, l10n)
              : l10n.allMerchants,
        ),
        actions: [CartBadge(onTap: () => context.push('/market/cart'))],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_merchantsFutureProvider);
          ref.invalidate(_featuredFutureProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimatedFadeIn(
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.searchMerchantsProducts,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                ),
                onTap: () => context.push('/market/search'),
                readOnly: true,
              ),
            ),
            const SizedBox(height: 16),

            AnimatedFadeIn(
              delay: const Duration(milliseconds: 100),
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(l10n.all),
                        selected: selectedType == null,
                        onSelected: (_) =>
                            ref.read(_selectedTypeProvider.notifier).state =
                                null,
                      ),
                    ),
                    ...MerchantType.values.map(
                      (type) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: MerchantTypeChip(
                          type: type,
                          selected: selectedType == type,
                          onSelected: (_) =>
                              ref.read(_selectedTypeProvider.notifier).state =
                                  type,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            featuredAsync.when(
              data: (merchants) {
                if (merchants.isEmpty) return const SizedBox();
                return AnimatedFadeIn(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.featured,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 250,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: merchants.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final merchant = merchants[index];
                            return SizedBox(
                              width: 260,
                              child: MerchantCard(
                                merchant: merchant,
                                onTap: () => context.push(
                                  '/market/merchant/${merchant.id}',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox(),
            ),

            merchantsAsync.when(
              data: (merchants) {
                if (merchants.isEmpty) return const SizedBox();
                final mostRequested = List<Merchant>.from(merchants)
                  ..sort((a, b) => b.rating.compareTo(a.rating));
                final topRequested = mostRequested.take(10).toList();
                return AnimatedFadeIn(
                  delay: const Duration(milliseconds: 250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.brandPurple.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.trending_up_rounded,
                              color: AppColors.brandPurple,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.mostRequested,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: _AnimatedMerchantCarousel(
                          merchants: topRequested,
                          onTap: (m) =>
                              context.push('/market/merchant/${m.id}'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox(),
            ),

            AnimatedFadeIn(
              delay: const Duration(milliseconds: 300),
              child: Text(
                l10n.allMerchants,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),

            merchantsAsync.when(
              data: (merchants) {
                final filtered = selectedType != null
                    ? merchants.where((m) => m.type == selectedType).toList()
                    : merchants;

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: PremiumEmptyState(
                      icon: Icons.store_outlined,
                      title: l10n.noMerchantsFound,
                      message: l10n.nearbyEmptyHint,
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final merchant = filtered[index];
                    return MerchantCard(
                      merchant: merchant,
                      onTap: () =>
                          context.push('/market/merchant/${merchant.id}'),
                    );
                  },
                );
              },
              loading: () => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.74,
                children: const [
                  ShimmerCard(height: 200),
                  ShimmerCard(height: 200),
                  ShimmerCard(height: 200),
                  ShimmerCard(height: 200),
                ],
              ),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.error,
                message: l10n.errorLoading,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(_merchantsFutureProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedMerchantCarousel extends StatefulWidget {
  const _AnimatedMerchantCarousel({
    required this.merchants,
    required this.onTap,
  });

  final List<Merchant> merchants;
  final void Function(Merchant) onTap;

  @override
  State<_AnimatedMerchantCarousel> createState() =>
      _AnimatedMerchantCarouselState();
}

class _AnimatedMerchantCarouselState extends State<_AnimatedMerchantCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;
  late final AnimationController _progress;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _progress.forward(from: 0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final nextPage = (_current + 1) % widget.merchants.length;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
      _progress.forward(from: 0);
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final page =
        (_controller.hasClients && _controller.position.haveDimensions)
            ? (_controller.page ?? _current.toDouble())
            : _current.toDouble();
    return Column(
      children: [
        Expanded(
          child: RepaintBoundary(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.merchants.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) {
                final merchant = widget.merchants[index];
                final distance = (page - index).abs();
                final scale = 1.0 - (distance.clamp(0.0, 1.0) * 0.07);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    scale: scale,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: () => widget.onTap(merchant),
                      child: _MostRequestedCard(merchant: merchant),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < widget.merchants.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) {
                      final double fill;
                      if (i < _current) {
                        fill = 1.0;
                      } else if (i == _current) {
                        fill = _progress.value;
                      } else {
                        fill = 0.0;
                      }
                      final alignment = isRtl
                          ? (i == _current
                              ? Alignment.centerRight
                              : Alignment.centerLeft)
                          : (i == _current
                              ? Alignment.centerLeft
                              : Alignment.centerRight);
                      return Stack(
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Align(
                            alignment: alignment,
                            child: FractionallySizedBox(
                              widthFactor: fill,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPurple,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MostRequestedCard extends StatelessWidget {
  const _MostRequestedCard({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final typeColor = merchantTypeColor(merchant.type);
    final typeEmoji = merchantEmoji(merchant.type);
    final typeLabel = merchantTypeLabel(merchant.type, l10n);
    final hasImage = merchant.imageUrl != null && merchant.imageUrl!.isNotEmpty;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (pixelRatio * 560).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: hasImage
                ? Image.network(
                    merchant.imageUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    errorBuilder: (_, _, _) => _ImageFallback(
                      typeColor: typeColor,
                      typeEmoji: typeEmoji,
                    ),
                  )
                : _ImageFallback(
                    typeColor: typeColor,
                    typeEmoji: typeEmoji,
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    typeColor.withValues(alpha: 0.30),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        typeEmoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        typeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (merchant.isOpenNow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.open,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (merchant.isOpenNow) const SizedBox(width: 6),
                if (merchant.isVerified)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  merchant.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.rating,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            merchant.rating.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (merchant.ratingCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${merchant.ratingCount})',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delivery_dining_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            merchant.estimatedDeliveryMinutes != null
                                ? '${merchant.estimatedDeliveryMinutes} ${l10n.minutesShort}'
                                : l10n.delivery,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (merchant.deliveryFee != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${merchant.deliveryFee!.toStringAsFixed(0)} ${l10n.currencySymbol}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({
    required this.typeColor,
    required this.typeEmoji,
  });

  final Color typeColor;
  final String typeEmoji;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withValues(alpha: 0.35),
            typeColor.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Text(
          typeEmoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
