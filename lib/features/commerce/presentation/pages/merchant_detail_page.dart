import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/commerce/domain/entities/catalog_category.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/product_card.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/rating_stars.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/delivery_info.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/cart_badge.dart';

class MerchantDetailPage extends ConsumerWidget {
  const MerchantDetailPage({
    required this.merchantId,
    super.key,
  });

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final merchantRepo = ref.watch(merchantRepositoryProvider);
    final productRepo = ref.watch(productRepositoryProvider);
    final categoryRepo = ref.watch(catalogCategoryRepositoryProvider);

    return FutureBuilder<Merchant?>(
      future: merchantRepo.getMerchantById(merchantId),
      builder: (context, merchantSnap) {
        final merchant = merchantSnap.data;
        if (merchant == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Merchant')),
            body: const Center(child: Text('Merchant not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(merchant.name),
            actions: [
              CartBadge(
                onTap: () => context.push('/market/cart'),
              ),
            ],
          ),
          body: ListView(
            children: [
              // Merchant header
              Container(
                height: 180,
                width: double.infinity,
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                child: Center(
                  child: Icon(
                    _typeIcon(merchant.type),
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            merchant.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (merchant.isVerified)
                          const Icon(Icons.verified,
                              color: Colors.blue, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      merchant.description ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    RatingStars(
                      rating: merchant.rating,
                      showCount: true,
                      count: merchant.ratingCount,
                    ),
                    const SizedBox(height: 12),
                    DeliveryInfo(
                      estimatedMinutes: merchant.estimatedDeliveryMinutes,
                      deliveryFee: merchant.deliveryFee,
                      minimumOrder: merchant.minimumOrder,
                    ),
                    if (merchant.address != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              merchant.address!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Categories
                    FutureBuilder<List<CatalogCategory>>(
                      future: categoryRepo.getCategories(merchantId),
                      builder: (context, catSnap) {
                        final categories = catSnap.data ?? [];
                        if (categories.isEmpty) return const SizedBox();
                        return SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              return ActionChip(
                                label: Text(cat.name),
                                onPressed: () {},
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Products
                    Text(
                      'Menu',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Product grid
              FutureBuilder<List<Product>>(
                future: productRepo.getProducts(merchantId: merchantId),
                builder: (context, prodSnap) {
                  final products = prodSnap.data ?? [];
                  if (products.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No products available'),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => context.push(
                          '/market/merchant/$merchantId/product/${product.id}',
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  IconData _typeIcon(MerchantType type) {
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
}
