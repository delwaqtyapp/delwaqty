import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/commerce/domain/entities/cart.dart'
    as commerce;
import 'package:delwaqty/features/commerce/presentation/widgets/price_tag.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/cart_badge.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({
    required this.productId,
    required this.merchantId,
    super.key,
  });

  final String productId;
  final String merchantId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _quantity = 1;
  String? _selectedVariantId;
  final _instructionsController = TextEditingController();

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productRepo = ref.watch(productRepositoryProvider);

    return FutureBuilder<Product?>(
      future: productRepo.getProductById(widget.productId),
      builder: (context, snapshot) {
        final product = snapshot.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Product')),
            body: const Center(child: Text('Product not found')),
          );
        }

        final selectedVariant = _selectedVariantId != null
            ? product.variants
                .where((v) => v.id == _selectedVariantId)
                .firstOrNull
            : null;
        final unitPrice = selectedVariant?.price ?? product.price;
        final totalPrice = unitPrice * _quantity;

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              CartBadge(
                onTap: () => context.push('/market/cart'),
              ),
            ],
          ),
          body: ListView(
            children: [
              // Product image
              Container(
                height: 250,
                width: double.infinity,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: const Center(
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (product.description != null)
                      Text(
                        product.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 12),
                    PriceTag(
                      price: unitPrice,
                      originalPrice: product.originalPrice,
                      size: 'large',
                    ),

                    // Variants
                    if (product.variants.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Size',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: product.variants.map((v) {
                          final isSelected = v.id == _selectedVariantId;
                          return ChoiceChip(
                            label: Text(
                              '${v.name} - ${v.price.toStringAsFixed(0)} SAR',
                            ),
                            selected: isSelected,
                            onSelected: v.isAvailable
                                ? (_) => setState(
                                    () => _selectedVariantId = v.id)
                                : null,
                          );
                        }).toList(),
                      ),
                    ],

                    // Quantity
                    const SizedBox(height: 20),
                    Text(
                      'Quantity',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$_quantity',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),

                    // Special instructions
                    const SizedBox(height: 20),
                    TextField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Special instructions (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: product.isAvailable
                    ? () async {
                        final cartRepo =
                            ref.read(cartRepositoryProvider);
                        await cartRepo.addToCart(
                          merchantId: widget.merchantId,
                          merchantName: '',
                          item: commerce.CartItem(
                            id:
                                'ci_${DateTime.now().millisecondsSinceEpoch}',
                            productId: product.id,
                            productName: product.name,
                            variantName: selectedVariant?.name,
                            quantity: _quantity,
                            unitPrice: unitPrice,
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added $_quantity ${product.name} to cart',
                              ),
                              action: SnackBarAction(
                                label: 'View Cart',
                                onPressed: () =>
                                    context.push('/market/cart'),
                              ),
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text('Add to Cart - ${totalPrice.toStringAsFixed(0)} SAR'),
              ),
            ),
          ),
        );
      },
    );
  }
}
