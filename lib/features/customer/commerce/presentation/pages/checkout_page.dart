import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart'
    as commerce;
import 'package:delwaqty/features/customer/commerce/domain/entities/coupon.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/services/payment/paymob_service.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String _paymentMethod = 'card';
  final _addressController = TextEditingController();
  final _couponController = TextEditingController();
  bool _isPlacing = false;

  @override
  void dispose() {
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final cartAsync = ref.watch(_cartFutureProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkout)),
      body: cartAsync.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.emptyCart, style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => context.go('/market'),
                    child: Text(l10n.browseMerchants),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimatedFadeIn(child: _SectionTitle(title: l10n.deliveryAddress)),
              const SizedBox(height: 8),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 100),
                child: TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: l10n.selectDeliveryAddress,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.showAppSnackBar(l10n.addNewAddress),
                  child: Text(l10n.addNewAddress),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 200),
                child: _SectionTitle(title: l10n.paymentMethod),
              ),
              const SizedBox(height: 8),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 300),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'card',
                      label: Text(l10n.creditCard),
                      icon: const Icon(Icons.credit_card),
                    ),
                    ButtonSegment(
                      value: 'cash',
                      label: Text(l10n.cashOnDelivery),
                      icon: const Icon(Icons.payments_outlined),
                    ),
                    ButtonSegment(
                      value: 'wallet',
                      label: Text(l10n.digitalWallet),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (v) =>
                      setState(() => _paymentMethod = v.first),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 400),
                child: _SectionTitle(title: l10n.couponCode),
              ),
              const SizedBox(height: 8),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 500),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        decoration: InputDecoration(
                          hintText: l10n.enterCouponCode,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () async {
                        final code = _couponController.text.trim();
                        if (code.isEmpty) return;
                        final repo = ref.read(couponRepositoryProvider);
                        final coupon = await repo.validateCoupon(
                          code,
                          cart.total,
                        );
                        if (!mounted) return;
                        if (coupon != null) {
                          double discount = 0;
                          switch (coupon.type) {
                            case CouponType.percentage:
                              discount = cart.subtotal * (coupon.value / 100);
                              if (coupon.maximumDiscount != null &&
                                  discount > coupon.maximumDiscount!) {
                                discount = coupon.maximumDiscount!;
                              }
                              break;
                            case CouponType.fixed:
                              discount = coupon.value;
                              break;
                            case CouponType.freeDelivery:
                              discount = cart.deliveryFee;
                              break;
                          }
                          final cartRepo = ref.read(cartRepositoryProvider);
                          await cartRepo.applyCoupon(
                            coupon.code,
                            discount: discount,
                          );
                          ref.invalidate(_cartFutureProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${l10n.couponApplied} -${discount.toStringAsFixed(0)} ${l10n.sar}',
                                ),
                                backgroundColor: colorScheme.primary,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.couponInvalid),
                              backgroundColor: colorScheme.error,
                            ),
                          );
                        }
                      },
                      child: Text(l10n.apply),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 600),
                child: _SectionTitle(title: l10n.orderSummary),
              ),
              const SizedBox(height: 8),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 700),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 800),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isPlacing ? null : () => _placeOrder(cart),
                    child: _isPlacing
                        ? AppLoader.circular(
                            size: 20,
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          )
                        : Text(l10n.placeOrder),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: AppLoader.circular()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(l10n.error, style: textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(_cartFutureProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder(commerce.Cart cart) async {
    final l10n = AppLocalizations.of(context);
    final cs = context.colorScheme;
    setState(() => _isPlacing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final order = await orderRepo.createOrder(
        merchantId: cart.merchantId,
        merchantName: cart.merchantName,
        items: cart.items,
        subtotal: cart.subtotal,
        deliveryFee: cart.deliveryFee,
        discount: cart.discount,
        total: cart.total,
        deliveryAddress: _addressController.text,
        paymentMethod: _paymentMethod,
      );

      if (_paymentMethod != 'cash') {
        final paymentSuccess = await _processPayment(order, cart.total);
        if (!paymentSuccess && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.somethingWentWrong),
              backgroundColor: cs.error,
            ),
          );
          setState(() => _isPlacing = false);
          return;
        }
      }

      await ref.read(cartRepositoryProvider).clearCart();
      ref.invalidate(_cartFutureProvider);

      if (!mounted) return;
      context.go('/market/order-completed/${order.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrong), backgroundColor: cs.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isPlacing = false);
      }
    }
  }

  Future<bool> _processPayment(Order order, double amount) async {
    try {
      final paymobService = ref.read(paymobServiceProvider);
      final auth = Supabase.instance.client.auth.currentUser;

      final authToken = await paymobService.authenticate();
      if (authToken == null) return false;

      final paymobOrderId = await paymobService.createOrder(
        authToken: authToken,
        amountCents: amount,
        merchantOrderId: order.id,
      );
      if (paymobOrderId == null) return false;

      final paymentKey = await paymobService.getPaymentKey(
        authToken: authToken,
        orderId: paymobOrderId,
        amountCents: amount,
        email: auth?.email ?? 'customer@delwaqty.com',
      );
      if (paymentKey == null) return false;

      final paymentUrl = paymobService.getPaymentUrl(paymentKey);
      if (await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.inAppWebView);
      }

      return true;
    } catch (e) {
      debugPrint('Payment processing error: $e');
      return false;
    }
  }
}

final _cartFutureProvider = FutureProvider.autoDispose<commerce.Cart?>((
  ref,
) async {
  final repo = ref.watch(cartRepositoryProvider);
  return repo.getCurrentCart();
});

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
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
    final textTheme = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
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
