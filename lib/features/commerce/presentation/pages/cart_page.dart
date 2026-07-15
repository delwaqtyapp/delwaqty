import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/cart.dart';

final _cartFutureProvider = FutureProvider<Cart?>((ref) async {
  final repo = ref.watch(cartRepositoryProvider);
  return repo.getCurrentCart();
});

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartAsync = ref.watch(_cartFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(cartRepositoryProvider).clearCart();
              ref.invalidate(_cartFutureProvider);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => context.go('/market'),
                    child: const Text('Browse Merchants'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        [
                          if (item.variantName != null) item.variantName!,
                          '${item.unitPrice.toStringAsFixed(0)} SAR each',
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              if (item.quantity <= 1) {
                                await ref
                                    .read(cartRepositoryProvider)
                                    .removeFromCart(cartItemId: item.id);
                              } else {
                                await ref
                                    .read(cartRepositoryProvider)
                                    .updateCartItem(
                                      cartItemId: item.id,
                                      quantity: item.quantity - 1,
                                    );
                              }
                              ref.invalidate(_cartFutureProvider);
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${item.quantity}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref
                                  .read(cartRepositoryProvider)
                                  .updateCartItem(
                                    cartItemId: item.id,
                                    quantity: item.quantity + 1,
                                  );
                              ref.invalidate(_cartFutureProvider);
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Cart summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Subtotal',
                      value: '${cart.subtotal.toStringAsFixed(0)} SAR',
                    ),
                    if (cart.deliveryFee > 0)
                      _SummaryRow(
                        label: 'Delivery',
                        value: '${cart.deliveryFee.toStringAsFixed(0)} SAR',
                      ),
                    if (cart.discount > 0)
                      _SummaryRow(
                        label: 'Discount',
                        value: '-${cart.discount.toStringAsFixed(0)} SAR',
                        color: Colors.green,
                      ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Total',
                      value: '${cart.total.toStringAsFixed(0)} SAR',
                      isBold: true,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.push('/market/checkout'),
                        child: const Text('Proceed to Checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
