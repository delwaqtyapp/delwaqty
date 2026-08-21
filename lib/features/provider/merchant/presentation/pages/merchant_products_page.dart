import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

final _merchantIdProvider = providerMerchantIdProvider;

final _productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(merchantDashboardRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  return repo.getMerchantProducts(merchantId);
});

class MerchantProductsPage extends ConsumerStatefulWidget {
  const MerchantProductsPage({super.key});

  @override
  ConsumerState<MerchantProductsPage> createState() =>
      _MerchantProductsPageState();
}

class _MerchantProductsPageState extends ConsumerState<MerchantProductsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final productsAsync = ref.watch(_productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageProducts),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_productsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/merchant-dashboard/products/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addProduct),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchProducts,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ShimmerCard(height: 80),
                ),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_productsProvider),
                ),
              ),
              data: (products) {
                final filtered = _searchQuery.isEmpty
                    ? products
                    : products.where((p) {
                        final name =
                            (p['name'] as String? ?? '').toLowerCase();
                        return name.contains(_searchQuery.toLowerCase());
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: PremiumEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.noProductsFound,
                      message: _searchQuery.isNotEmpty
                          ? l10n.noResultsFound
                          : l10n.noProductsFound,
                      actionLabel: _searchQuery.isEmpty
                          ? l10n.addProduct
                          : null,
                      onAction: _searchQuery.isEmpty
                          ? () =>
                              context.push('/merchant-dashboard/products/new')
                          : null,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_productsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _ProductCard(
                          product: product,
                          onTap: () {
                            final id = product['id'] as String;
                            context.push(
                              '/merchant-dashboard/products/$id/edit',
                            );
                          },
                          onDelete: () => _confirmDelete(context, ref, product),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> product,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProduct),
        content: Text(
          '${l10n.areYouSureYouWantToDelete} ${product['name'] as String? ?? ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final repo = ref.read(merchantDashboardRepositoryProvider);
              final id = product['id'] as String;
              await repo.deleteProduct(id);
              ref.invalidate(_productsProvider);
              if (context.mounted) {
                context.showAppSnackBar(l10n.productDeleted);
              }
            },
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = product['name'] as String? ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final isAvailable = product['is_available'] as bool? ?? true;
    final imageUrl = product['image_url'] as String?;

    return Dismissible(
      key: ValueKey(product['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onError,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Icon(
                      Icons.image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            title: Text(
              name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  '${AppLocalizations.of(context).currencySymbol} ${price.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isAvailable ? AppColors.successLight : AppColors.errorLight)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isAvailable
                        ? AppLocalizations.of(context).available
                        : AppLocalizations.of(context).unavailable,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isAvailable ? AppColors.successLight : AppColors.errorLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ),
    );
  }
}
