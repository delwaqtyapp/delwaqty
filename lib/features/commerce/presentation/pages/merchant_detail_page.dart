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
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class MerchantDetailPage extends ConsumerStatefulWidget {
  const MerchantDetailPage({required this.merchantId, super.key});

  final String merchantId;

  @override
  ConsumerState<MerchantDetailPage> createState() =>
      _MerchantDetailPageState();
}

class _MerchantDetailPageState extends ConsumerState<MerchantDetailPage> {
  Key _refreshKey = UniqueKey();
  String? _selectedCategoryId;

  Future<void> _onRefresh() async {
    setState(() => _refreshKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final merchantRepo = ref.watch(merchantRepositoryProvider);
    final productRepo = ref.watch(productRepositoryProvider);
    final categoryRepo = ref.watch(catalogCategoryRepositoryProvider);

    return FutureBuilder<Merchant?>(
      key: _refreshKey,
      future: merchantRepo.getMerchantById(widget.merchantId),
      builder: (context, merchantSnap) {
        if (merchantSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.loading)),
            body: const Center(child: AppLoaderCircular()),
          );
        }

        final merchant = merchantSnap.data;
        if (merchant == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.error)),
            body: ErrorState(message: l10n.noData),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(merchant.name),
            actions: [CartBadge(onTap: () => context.push('/market/cart'))],
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
            children: [
              Hero(
                tag: 'merchant-${merchant.id}',
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colorScheme.primaryContainer.withValues(
                          alpha: 0.6,
                        ),
                        context.colorScheme.surface,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _typeIcon(merchant.type),
                        size: 52,
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 100),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              merchant.name,
                              style: context.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (merchant.isVerified)
                            Icon(
                              Icons.verified,
                              color: context.colorScheme.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (merchant.description != null &&
                        merchant.description!.isNotEmpty)
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          merchant.description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 300),
                      child: RatingStars(
                        rating: merchant.rating,
                        showCount: true,
                        count: merchant.ratingCount,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 400),
                      child: DeliveryInfo(
                        estimatedMinutes: merchant.estimatedDeliveryMinutes,
                        deliveryFee: merchant.deliveryFee,
                        minimumOrder: merchant.minimumOrder,
                      ),
                    ),
                    if (merchant.address != null) ...[
                      const SizedBox(height: 10),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 500),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                merchant.address!,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 550),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 18,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.workingHours,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            merchant.isOpenNow
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            size: 18,
                            color: merchant.isOpenNow
                                ? AppColors.successLight
                                : context.colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            merchant.isOpenNow ? l10n.open : l10n.closed,
                            style: context.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: merchant.isOpenNow
                                  ? AppColors.successLight
                                  : context.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (merchant.type == MerchantType.restaurant)
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 580),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.push('/restaurant/${merchant.id}'),
                            icon: const Icon(Icons.restaurant_outlined),
                            label: Text(l10n.viewFullMenu),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 600),
                      child: FutureBuilder<List<CatalogCategory>>(
                        future: categoryRepo.getCategories(widget.merchantId),
                        builder: (context, catSnap) {
                          final categories = catSnap.data ?? [];
                          if (categories.isEmpty) return const PremiumEmptyState(
                            icon: Icons.category_outlined,
                            title: 'No Categories',
                            message: 'This merchant has no categories yet.',
                          );
                          return SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                return ActionChip(
                                  label: Text(cat.name),
                                  onPressed: () {
                                    setState(() {
                                      _selectedCategoryId =
                                          _selectedCategoryId == cat.id
                                              ? null
                                              : cat.id;
                                    });
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 700),
                      child: Text(
                        l10n.menu,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              FutureBuilder<List<Product>>(
                key: _refreshKey,
                future: productRepo.getProducts(
                  merchantId: widget.merchantId,
                  categoryId: _selectedCategoryId,
                ),
                builder: (context, prodSnap) {
                  if (prodSnap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: AppLoaderCircular(),
                      ),
                    );
                  }

                  final products = prodSnap.data ?? [];
                  if (products.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PremiumEmptyState(
                        icon: Icons.shopping_bag_outlined,
                        title: l10n.menu,
                        message: l10n.noData,
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
                      return Hero(
                        tag: 'product-${product.id}',
                        child: ProductCard(
                          product: product,
                          onTap: () => context.push(
                            '/market/merchant/${widget.merchantId}/product/${product.id}',
                            extra: merchant.name,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
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
