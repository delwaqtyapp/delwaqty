import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';

final _cartFutureProvider = FutureProvider<Cart?>((ref) async {
  final repo = ref.watch(cartRepositoryProvider);
  return repo.getCurrentCart();
});

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final cartAsync = ref.watch(_cartFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cart),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(cartRepositoryProvider).clearCart();
              ref.invalidate(_cartFutureProvider);
            },
            child: Text(l10n.clearCart),
          ),
        ],
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: l10n.emptyCart,
              message: l10n.emptyCartMessage,
              actionLabel: l10n.browseMerchants,
              onAction: () => context.go('/market'),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: 80 * index),
                      child: Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: colorScheme.onError,
                          ),
                        ),
                        onDismissed: (_) async {
                          await ref
                              .read(cartRepositoryProvider)
                              .removeFromCart(cartItemId: item.id);
                          ref.invalidate(_cartFutureProvider);
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.variantName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.variantName!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  '${item.unitPrice.toStringAsFixed(0)} ${l10n.sar} / ${l10n.quantity.toLowerCase()}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _QuantityButton(
                                      icon: Icons.remove_circle_outline,
                                      onPressed: () async {
                                        if (item.quantity <= 1) {
                                          await ref
                                              .read(cartRepositoryProvider)
                                              .removeFromCart(
                                                cartItemId: item.id,
                                              );
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
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '${item.quantity}',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    _QuantityButton(
                                      icon: Icons.add_circle_outline,
                                      onPressed: () async {
                                        await ref
                                            .read(cartRepositoryProvider)
                                            .updateCartItem(
                                              cartItemId: item.id,
                                              quantity: item.quantity + 1,
                                            );
                                        ref.invalidate(_cartFutureProvider);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: l10n.subtotal,
                        value:
                            '${cart.subtotal.toStringAsFixed(0)} ${l10n.sar}',
                      ),
                      if (cart.deliveryFee > 0)
                        _SummaryRow(
                          label: l10n.deliveryFee,
                          value:
                              '${cart.deliveryFee.toStringAsFixed(0)} ${l10n.sar}',
                        ),
                      if (cart.discount > 0)
                        _SummaryRow(
                          label: l10n.discount,
                          value:
                              '-${cart.discount.toStringAsFixed(0)} ${l10n.sar}',
                          color: colorScheme.primary,
                        ),
                      Divider(color: colorScheme.outlineVariant),
                      _SummaryRow(
                        label: l10n.total,
                        value: '${cart.total.toStringAsFixed(0)} ${l10n.sar}',
                        isBold: true,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => context.push('/market/checkout'),
                          child: Text(l10n.proceedToCheckout),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: AppLoader.circular()),
        error: (e, _) => ErrorState(
          title: l10n.error,
          message: e.toString(),
          onRetry: () => ref.invalidate(_cartFutureProvider),
          retryLabel: l10n.retry,
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(foregroundColor: colorScheme.primary),
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
    final textTheme = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
