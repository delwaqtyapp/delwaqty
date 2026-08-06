import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/search_filter.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/favorite_button.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/design/premium_search_field.dart';

IconData merchantTypeIcon(MerchantType type) {
  switch (type) {
    case MerchantType.restaurant:
      return Icons.restaurant;
    case MerchantType.grocery:
      return Icons.local_grocery_store;
    case MerchantType.pharmacy:
      return Icons.local_pharmacy;
    case MerchantType.flowers:
      return Icons.local_florist;
    case MerchantType.bakery:
      return Icons.bakery_dining;
    case MerchantType.electronics:
      return Icons.devices;
    case MerchantType.furniture:
      return Icons.chair;
    case MerchantType.fashion:
      return Icons.checkroom;
    case MerchantType.home:
      return Icons.home_repair_service;
    case MerchantType.other:
      return Icons.store;
  }
}

Color merchantTypeColor(MerchantType type) {
  switch (type) {
    case MerchantType.restaurant:
      return AppColors.merchantFood;
    case MerchantType.grocery:
      return AppColors.merchantGrocery;
    case MerchantType.pharmacy:
      return AppColors.merchantPharmacy;
    case MerchantType.flowers:
      return const Color(0xFFC2185B);
    case MerchantType.bakery:
      return const Color(0xFFE65100);
    case MerchantType.electronics:
      return AppColors.merchantElectronics;
    case MerchantType.furniture:
      return AppColors.merchantFurniture;
    case MerchantType.fashion:
      return AppColors.merchantFashion;
    case MerchantType.home:
      return const Color(0xFF1565C0);
    case MerchantType.other:
      return const Color(0xFF546E7A);
  }
}

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

final _queryProvider = StateProvider<String>((_) => '');

final _selectedTypeProvider = StateProvider<MerchantType?>((_) => null);

final _selectedSortProvider = StateProvider<SortBy>((_) => SortBy.distance);

final _searchResultsProvider = FutureProvider<List<Merchant>>((ref) async {
  final query = ref.watch(_queryProvider);
  final type = ref.watch(_selectedTypeProvider);
  final sortBy = ref.watch(_selectedSortProvider);
  final repo = ref.watch(merchantRepositoryProvider);

  if (query.trim().isEmpty && type == null) {
    return repo.getMerchants(filter: SearchFilter(sortBy: sortBy), limit: 50);
  }

  if (query.trim().isNotEmpty) {
    final results = await repo.searchMerchants(query.trim());
    if (type != null) {
      return results.where((m) => m.type == type).toList();
    }
    return results;
  }

  return repo.getMerchants(
    type: type,
    filter: SearchFilter(sortBy: sortBy),
    limit: 50,
  );
});

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(_queryProvider.notifier).state = value;
    });
  }

  void _onTypeSelected(MerchantType? type) {
    ref.read(_selectedTypeProvider.notifier).state = type;
  }

  void _onSortSelected(SortBy sort) {
    ref.read(_selectedSortProvider.notifier).state = sort;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resultsAsync = ref.watch(_searchResultsProvider);
    final selectedType = ref.watch(_selectedTypeProvider);
    final selectedSort = ref.watch(_selectedSortProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.search)),
      body: GradientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PremiumSearchField(
                controller: _searchController,
                hint: l10n.searchHint,
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  _debounceTimer?.cancel();
                  ref.read(_queryProvider.notifier).state = value;
                },
              ),
            ),
            const SizedBox(height: 14),
            _buildFilterPills(l10n, selectedType),
            const SizedBox(height: 10),
            _buildSortBar(l10n, selectedSort),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_searchResultsProvider);
                  await ref.read(_searchResultsProvider.future);
                },
                child: resultsAsync.when(
                  data: (merchants) {
                    if (merchants.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 80),
                          PremiumEmptyState(
                            icon: Icons.search_off_rounded,
                            title: l10n.searchNoResults,
                            message: l10n.searchNoResultsMessage,
                          ),
                        ],
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: merchants.length,
                      itemBuilder: (context, index) {
                        return AnimatedFadeIn(
                          delay: Duration(milliseconds: index * 60),
                          child: _SearchMerchantCard(
                            merchant: merchants[index],
                            onTap: () => context.push(
                              '/market/merchant/${merchants[index].id}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => _buildLoadingSkeleton(),
                  error: (e, _) => ListView(
                    children: [
                      const SizedBox(height: 80),
                      PremiumEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: l10n.error,
                        message: e.toString(),
                        actionLabel: l10n.retry,
                        onAction: () => ref.invalidate(_searchResultsProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills(AppLocalizations l10n, MerchantType? selectedType) {
    final filters = <(String label, IconData? icon, MerchantType? type)>[
      (l10n.popular, null, null),
      (l10n.restaurants, merchantTypeIcon(MerchantType.restaurant), MerchantType.restaurant),
      (l10n.grocery, merchantTypeIcon(MerchantType.grocery), MerchantType.grocery),
      (l10n.pharmacy, merchantTypeIcon(MerchantType.pharmacy), MerchantType.pharmacy),
      (l10n.homeServices, merchantTypeIcon(MerchantType.home), MerchantType.home),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, icon, type) = filters[index];
          return _PremiumPill(
            label: label,
            icon: icon,
            selected: selectedType == type,
            onTap: () => _onTypeSelected(type),
          );
        },
      ),
    );
  }

  Widget _buildSortBar(AppLocalizations l10n, SortBy selectedSort) {
    final sortOptions = <(String label, SortBy sort)>[
      (l10n.sortByDistance, SortBy.distance),
      (l10n.sortByRating, SortBy.rating),
      (l10n.sortByPrice, SortBy.priceLow),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sortOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, sort) = sortOptions[index];
          return _PremiumPill(
            label: label,
            icon: Icons.sort_rounded,
            compact: true,
            selected: selectedSort == sort,
            onTap: () => _onSortSelected(sort),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return ShimmerLoading(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest,
              borderRadius: AppSpacing.borderRadiusCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.radiusCard),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: context.colorScheme.surfaceContainerHighest,
                            borderRadius: AppSpacing.borderRadiusSm,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          height: 12,
                          decoration: BoxDecoration(
                            color: context.colorScheme.surfaceContainerHighest,
                            borderRadius: AppSpacing.borderRadiusSm,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 70,
                          height: 11,
                          decoration: BoxDecoration(
                            color: context.colorScheme.surfaceContainerHighest,
                            borderRadius: AppSpacing.borderRadiusSm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 6 : 9,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandPurple, AppColors.brandViolet],
                )
              : null,
          color: selected ? null : colorScheme.surfaceContainerLowest,
          borderRadius: AppSpacing.borderRadiusFull,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: selected ? AppElevation.shadowGlow : AppElevation.shadowXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 15 : 17,
                color: selected ? Colors.white : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: (compact
                      ? Theme.of(context).textTheme.labelMedium
                      : Theme.of(context).textTheme.labelLarge)
                  ?.copyWith(
                    color: selected ? Colors.white : colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMerchantCard extends StatelessWidget {
  const _SearchMerchantCard({required this.merchant, required this.onTap});

  final Merchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = merchantTypeColor(merchant.type);
    final typeLabel = _merchantTypeLabel(merchant.type, l10n);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      onTap: onTap,
      color: colorScheme.surfaceContainerLowest,
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 116,
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
                    child: _OpenBadge(
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
                        borderRadius: AppSpacing.borderRadiusFull,
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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant.name,
                  style: textTheme.titleSmall?.copyWith(
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
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (merchant.ratingCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${merchant.ratingCount})',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (merchant.deliveryAvailable &&
                        merchant.estimatedDeliveryMinutes != null)
                      Text(
                        '${merchant.estimatedDeliveryMinutes} ${l10n.minutesShort}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
                          style: textTheme.bodySmall?.copyWith(
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
        child: Text(emoji, style: AppTextStyles.displaySmall.copyWith(fontSize: 44)),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.open, required this.label});

  final bool open;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bg = open ? AppColors.successLight : Colors.black.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.borderRadiusFull,
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
