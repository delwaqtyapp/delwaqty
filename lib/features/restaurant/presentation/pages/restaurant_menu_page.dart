import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/commerce/domain/entities/catalog_category.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/skeleton_loader.dart';

final _categoriesProvider = FutureProvider.family<List<CatalogCategory>, String>((ref, merchantId) async {
  final repo = ref.watch(catalogCategoryRepositoryProvider);
  return repo.getCategories(merchantId);
});

class MenuState {
  final List<Product> products;
  final bool hasMore;
  final bool isLoadingMore;
  final int offset;
  final String? categoryId;
  final String searchQuery;

  const MenuState({
    this.products = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.offset = 0,
    this.categoryId,
    this.searchQuery = '',
  });

  MenuState copyWith({
    List<Product>? products,
    bool? hasMore,
    bool? isLoadingMore,
    int? offset,
    String? categoryId,
    bool clearCategory = false,
    String? searchQuery,
  }) {
    return MenuState(
      products: products ?? this.products,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      offset: offset ?? this.offset,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class RestaurantMenuNotifier extends AutoDisposeFamilyAsyncNotifier<MenuState, String> {
  static const _limit = 20;

  @override
  FutureOr<MenuState> build(String merchantId) async {
    final repo = ref.watch(productRepositoryProvider);
    final products = await repo.getProducts(
      merchantId: merchantId,
      limit: _limit,
      offset: 0,
    );
    return MenuState(
      products: products,
      hasMore: products.length >= _limit,
      offset: products.length,
    );
  }

  Future<void> loadNextPage() async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.isLoadingMore || !currentState.hasMore) return;

    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final repo = ref.read(productRepositoryProvider);
      final products = await repo.getProducts(
        merchantId: arg,
        categoryId: currentState.categoryId,
        limit: _limit,
        offset: currentState.offset,
      );

      final newProducts = [...currentState.products, ...products];
      state = AsyncValue.data(currentState.copyWith(
        products: newProducts,
        hasMore: products.length >= _limit,
        isLoadingMore: false,
        offset: currentState.offset + products.length,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> setCategory(String? categoryId) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = const AsyncValue.loading();

    try {
      final repo = ref.read(productRepositoryProvider);
      final products = await repo.getProducts(
        merchantId: arg,
        categoryId: categoryId,
        limit: _limit,
        offset: 0,
      );

      state = AsyncValue.data(MenuState(
        products: products,
        hasMore: products.length >= _limit,
        offset: products.length,
        categoryId: categoryId,
        searchQuery: currentState.searchQuery,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> setSearchQuery(String query) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = const AsyncValue.loading();

    try {
      final repo = ref.read(productRepositoryProvider);
      List<Product> products;
      if (query.isEmpty) {
        products = await repo.getProducts(
          merchantId: arg,
          categoryId: currentState.categoryId,
          limit: _limit,
          offset: 0,
        );
      } else {
        products = await repo.searchProducts(query, merchantId: arg);
      }

      state = AsyncValue.data(MenuState(
        products: products,
        hasMore: query.isEmpty ? products.length >= _limit : false,
        offset: products.length,
        categoryId: currentState.categoryId,
        searchQuery: query,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final restaurantMenuProvider = AsyncNotifierProvider.autoDispose.family<RestaurantMenuNotifier, MenuState, String>(
  RestaurantMenuNotifier.new,
);

class RestaurantMenuPage extends ConsumerStatefulWidget {
  const RestaurantMenuPage({super.key, required this.merchantId, this.merchantName});

  final String merchantId;
  final String? merchantName;

  @override
  ConsumerState<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends ConsumerState<RestaurantMenuPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(restaurantMenuProvider(widget.merchantId).notifier).loadNextPage();
    }
  }

  void _debounceSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(restaurantMenuProvider(widget.merchantId).notifier).setSearchQuery(query.trim());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(_categoriesProvider(widget.merchantId));
    final menuStateAsync = ref.watch(restaurantMenuProvider(widget.merchantId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.merchantName ?? l10n.menu),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _debounceSearch,
              decoration: InputDecoration(
                hintText: l10n.searchMenu,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(restaurantMenuProvider(widget.merchantId).notifier).setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              final menuState = menuStateAsync.valueOrNull;
              final selectedCategoryId = menuState?.categoryId;
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CategoryChip(
                      label: l10n.allCategories,
                      isSelected: selectedCategoryId == null,
                      onTap: () => ref.read(restaurantMenuProvider(widget.merchantId).notifier).setCategory(null),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        label: cat.name,
                        isSelected: selectedCategoryId == cat.id,
                        onTap: () => ref.read(restaurantMenuProvider(widget.merchantId).notifier).setCategory(cat.id),
                      ),
                    )),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 40),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: menuStateAsync.when(
              data: (menuState) {
                final products = menuState.products;
                if (products.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: l10n.noProductsInCategory,
                    message: l10n.searchNoResultsMessage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(restaurantMenuProvider(widget.merchantId));
                    ref.invalidate(_categoriesProvider(widget.merchantId));
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length + (menuState.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == products.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final product = products[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _ProductListTile(
                          product: product,
                          onTap: () => context.push(
                            '/market/merchant/${widget.merchantId}/product/${product.id}',
                            extra: widget.merchantName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const RestaurantMenuSkeleton(),
              error: (_, __) => Center(
                child: ErrorState(message: AppLocalizations.of(context).errorLoading),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: isSelected ? theme.colorScheme.primary : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  const _ProductListTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: product.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(product.imageUrl!, fit: BoxFit.cover),
                        )
                      : Icon(
                          Icons.fastfood_outlined,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${product.price.toStringAsFixed(0)} ${l10n.sar}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (product.originalPrice != null && product.originalPrice! > product.price) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${product.originalPrice!.toStringAsFixed(0)} ${l10n.sar}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!product.isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.outOfStock,
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.red.shade700),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
