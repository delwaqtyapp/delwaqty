import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_search_bar.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/search_filter.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/rating_stars.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AppSearchBar(
              controller: _searchController,
              hint: l10n.searchHint,
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                _debounceTimer?.cancel();
                ref.read(_queryProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildFilterChips(l10n, selectedType),
          const SizedBox(height: 8),
          _buildSortBar(l10n, selectedSort),
          const SizedBox(height: 8),
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
                        EmptyState(
                          icon: Icons.search_off_rounded,
                          title: l10n.searchNoResults,
                          message: l10n.searchNoResultsMessage,
                        ),
                      ],
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
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
                    EmptyState(
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
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n, MerchantType? selectedType) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final filters = <(String label, MerchantType?)>[
      (l10n.popular, null),
      (l10n.restaurants, MerchantType.restaurant),
      (l10n.grocery, MerchantType.grocery),
      (l10n.pharmacy, MerchantType.pharmacy),
      (l10n.homeServices, MerchantType.home),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, type) = filters[index];
          final isSelected = selectedType == type;
          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => _onTypeSelected(type),
            selectedColor: colorScheme.primary,
            checkmarkColor: colorScheme.onPrimary,
            labelStyle: textTheme.labelLarge?.copyWith(
              color: isSelected ? colorScheme.onPrimary : null,
            ),
            avatar: type == null
                ? null
                : Icon(
                    merchantTypeIcon(type),
                    size: 18,
                    color: isSelected ? colorScheme.onPrimary : null,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSortBar(AppLocalizations l10n, SortBy selectedSort) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final sortOptions = <(String label, SortBy sort)>[
      (l10n.sortByDistance, SortBy.distance),
      (l10n.sortByRating, SortBy.rating),
      (l10n.sortByPrice, SortBy.priceLow),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          ...sortOptions.map((option) {
            final (label, sort) = option;
            final isSelected = selectedSort == sort;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => _onSortSelected(sort),
                selectedColor: colorScheme.secondaryContainer,
                labelStyle: textTheme.labelMedium?.copyWith(
                  color: isSelected ? colorScheme.onSecondaryContainer : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LoadingSkeleton(height: 90, borderRadius: 0),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(
                      width: MediaQuery.sizeOf(context).width * 0.35,
                      height: 14,
                    ),
                    const SizedBox(height: 8),
                    LoadingSkeleton(
                      width: MediaQuery.sizeOf(context).width * 0.2,
                      height: 12,
                    ),
                    const SizedBox(height: 8),
                    LoadingSkeleton(
                      width: MediaQuery.sizeOf(context).width * 0.3,
                      height: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchMerchantCard extends StatelessWidget {
  const _SearchMerchantCard({required this.merchant, required this.onTap});

  final Merchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final typeColor = merchantTypeColor(merchant.type);
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [typeColor, typeColor.withValues(alpha: 0.7)],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Icon(
                        merchantTypeIcon(merchant.type),
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (merchant.isVerified)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 12,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                l10n.verified,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (merchant.isOpenNow)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                            child: Text(
                              l10n.open,
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    RatingStars(
                      rating: merchant.rating,
                      size: 14,
                      showCount: true,
                      count: merchant.ratingCount,
                    ),
                    const SizedBox(height: 6),
                    if (merchant.deliveryAvailable)
                      Row(
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              merchant.estimatedDeliveryMinutes != null
                                  ? '${merchant.estimatedDeliveryMinutes} ${AppLocalizations.of(context).minutes}'
                                  : AppLocalizations.of(context).delivery,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    if (merchant.deliveryFee != null)
                      Text(
                        merchant.deliveryFee == 0
                            ? AppLocalizations.of(context).freeDelivery
                            : '${merchant.deliveryFee!.toStringAsFixed(0)} ${AppLocalizations.of(context).sar}',
                        style: textTheme.bodySmall?.copyWith(
                          color: merchant.deliveryFee == 0
                              ? AppColors.successLight
                              : colorScheme.primary,
                          fontWeight: FontWeight.w600,
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
  }
}
