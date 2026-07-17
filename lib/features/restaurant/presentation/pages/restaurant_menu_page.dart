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
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

final _categoriesProvider = FutureProvider.family<List<CatalogCategory>, String>((ref, merchantId) async {
  final repo = ref.watch(catalogCategoryRepositoryProvider);
  return repo.getCategories(merchantId);
});

final _productsProvider = FutureProvider.family<List<Product>, String>((ref, merchantId) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts(merchantId: merchantId);
});

class RestaurantMenuPage extends ConsumerStatefulWidget {
  const RestaurantMenuPage({super.key, required this.merchantId, this.merchantName});

  final String merchantId;
  final String? merchantName;

  @override
  ConsumerState<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends ConsumerState<RestaurantMenuPage> {
  String? _selectedCategoryId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(_categoriesProvider(widget.merchantId));
    final productsAsync = ref.watch(_productsProvider(widget.merchantId));

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
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.searchMenu,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
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
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CategoryChip(
                      label: l10n.allCategories,
                      isSelected: _selectedCategoryId == null,
                      onTap: () => setState(() => _selectedCategoryId = null),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        label: cat.name,
                        isSelected: _selectedCategoryId == cat.id,
                        onTap: () => setState(() => _selectedCategoryId = cat.id),
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
            child: productsAsync.when(
              data: (products) {
                var filtered = products;
                if (_selectedCategoryId != null) {
                  filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((p) =>
                    p.name.toLowerCase().contains(_searchQuery) ||
                    (p.description?.toLowerCase().contains(_searchQuery) ?? false) ||
                    p.tags.any((t) => t.toLowerCase().contains(_searchQuery))
                  ).toList();
                }
                if (filtered.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: l10n.noProductsInCategory,
                    message: l10n.searchNoResultsMessage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(_productsProvider(widget.merchantId));
                    ref.invalidate(_categoriesProvider(widget.merchantId));
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
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
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShimmerCard(height: 80),
                ),
              ),
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
