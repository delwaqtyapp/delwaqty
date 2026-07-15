import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String _paymentMethod = 'card';
  String _deliveryAddress = '';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Delivery address
          Text(
            'Delivery Address',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'Enter delivery address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            onChanged: (v) => _deliveryAddress = v,
          ),
          const SizedBox(height: 24),

          // Payment method
          Text(
            'Payment Method',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'card', label: Text('Card'), icon: Icon(Icons.credit_card)),
              ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.money)),
              ButtonSegment(value: 'wallet', label: Text('Wallet'), icon: Icon(Icons.account_balance_wallet)),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (v) => setState(() => _paymentMethod = v.first),
          ),
          const SizedBox(height: 24),

          // Coupon
          Text(
            'Coupon Code',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: const InputDecoration(
                    hintText: 'Enter coupon code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () async {
                  final code = _couponController.text.trim();
                  if (code.isEmpty) return;
                  final repo = ref.read(couponRepositoryProvider);
                  final coupon = await repo.validateCoupon(code, 0);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          coupon != null
                              ? 'Coupon applied: ${coupon.value}% off'
                              : 'Invalid coupon',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Place order
          FilledButton(
            onPressed: _isPlacing
                ? null
                : () async {
                    setState(() => _isPlacing = true);
                    final cartRepo = ref.read(cartRepositoryProvider);
                    final cart = await cartRepo.getCurrentCart();
                    if (cart == null || cart.items.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cart is empty')),
                        );
                      }
                      setState(() => _isPlacing = false);
                      return;
                    }

                    final orderRepo = ref.read(orderRepositoryProvider);
                    await orderRepo.createOrder(
                      merchantId: cart.merchantId,
                      items: cart.items,
                      subtotal: cart.subtotal,
                      deliveryFee: cart.deliveryFee,
                      discount: cart.discount,
                      total: cart.total,
                      deliveryAddress: _deliveryAddress,
                      paymentMethod: _paymentMethod,
                    );
                    await cartRepo.clearCart();

                    if (context.mounted) {
                      context.go('/market/orders');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order placed successfully!'),
                        ),
                      );
                    }
                    setState(() => _isPlacing = false);
                  },
            child: _isPlacing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Place Order'),
          ),
        ],
      ),
    );
  }
}
