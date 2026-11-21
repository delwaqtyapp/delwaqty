import 'package:delwaqty/features/customer/commerce/presentation/providers/cart_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/floating_glass_buttons.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

final _cartFutureProvider = Provider<AsyncValue<Cart?>>((ref) {
  return ref.watch(cartProvider);
});

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A snackbar queued on an earlier page (e.g. add-to-cart) must never
    // overlay the checkout button; drop it as the cart opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
    final l10n = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final cartAsync = ref.watch(_cartFutureProvider);

    final hasItems = cartAsync.value?.items.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: const Padding(
          padding: EdgeInsetsDirectional.only(start: 12),
          child: Center(child: FloatingMenuCircleButton(size: 40)),
        ),
        title: Text(l10n.cart),
        actions: [
          if (hasItems)
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(l10n.clearCartTitle),
                    content: Text(l10n.clearCartConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(l10n.clearCart),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(cartProvider.notifier).clear();
                }
              },
              child: Text(l10n.clearCart),
            ),
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: Center(child: FloatingNotificationCircleButton(size: 40)),
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
              onAction: () => context.push('/market'),
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
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsetsDirectional.only(end: 24),
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
                              .read(cartProvider.notifier)
                              .removeItem(item.id);
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
                                  '${item.unitPrice.toStringAsFixed(0)} ${l10n.egp} ${l10n.each}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _QuantityButton(
                                      icon: Icons.remove_circle_outline,
                                      tooltip: AppLocalizations.of(context)
                                          .decrease,
                                      onPressed: () async {
                                        if (item.quantity <= 1) {
                                          await ref
                                              .read(cartProvider.notifier)
                                              .removeItem(item.id);
                                        } else {
                                          await ref
                                              .read(cartProvider.notifier)
                                              .updateQuantity(
                                                cartItemId: item.id,
                                                quantity: item.quantity - 1,
                                              );
                                        }
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
                                      tooltip: AppLocalizations.of(context)
                                          .increase,
                                      onPressed: () async {
                                        await ref
                                            .read(cartProvider.notifier)
                                            .updateQuantity(
                                              cartItemId: item.id,
                                              quantity: item.quantity + 1,
                                            );
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
                      color: colorScheme.shadow.withValues(alpha: 0.05),
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
                            '${cart.subtotal.toStringAsFixed(0)} ${l10n.egp}',
                      ),
                      if (cart.deliveryFee > 0)
                        _SummaryRow(
                          label: l10n.deliveryFee,
                          value:
                              '${cart.deliveryFee.toStringAsFixed(0)} ${l10n.egp}',
                        ),
                      if (cart.discount > 0)
                        _SummaryRow(
                          label: l10n.discount,
                          value:
                              '-${cart.discount.toStringAsFixed(0)} ${l10n.egp}',
                          color: colorScheme.primary,
                        ),
                      Divider(color: colorScheme.outlineVariant),
                      _SummaryRow(
                        label: l10n.total,
                        value: '${cart.total.toStringAsFixed(0)} ${l10n.egp}',
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
          message: appErrorText(context, e),
          onRetry: () => ref.invalidate(cartProvider),
          retryLabel: l10n.retry,
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Required so the +/- controls stay readable to a screen reader.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return IconButton(
      tooltip: tooltip,
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
