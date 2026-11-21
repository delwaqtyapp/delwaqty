import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// In-store cashier (POS): pick products, build a cart, and complete the
/// sale through the server-priced pos_create_sale RPC (migration 201).
/// Pricing, stock decrement and commission all happen server-side; the
/// client-side subtotal below is only a preview.
class MerchantPosPage extends ConsumerStatefulWidget {
  const MerchantPosPage({super.key});

  @override
  ConsumerState<MerchantPosPage> createState() => _MerchantPosPageState();
}

class _MerchantPosPageState extends ConsumerState<MerchantPosPage> {
  /// product_id -> quantity
  final Map<String, int> _cart = {};
  final _discountCtrl = TextEditingController(text: '0');
  final _customerCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  bool _submitting = false;
  String _saleKey = _newSaleKey();

  @override
  void dispose() {
    _discountCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  double _previewSubtotal(List<Map<String, dynamic>> products) {
    var sum = 0.0;
    for (final p in products) {
      final qty = _cart[p['id']] ?? 0;
      if (qty > 0) {
        sum += ((p['price'] as num?)?.toDouble() ?? 0) * qty;
      }
    }
    return sum;
  }

  static String _newSaleKey() =>
      'pos-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

  Future<void> _completeSale(String merchantId) async {
    if (_cart.isEmpty || _submitting) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);
    try {
      final items = [
        for (final e in _cart.entries)
          {'product_id': e.key, 'quantity': e.value},
      ];
      final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
      final res = await Supabase.instance.client.rpc(
        'pos_create_sale',
        params: {
          'p_merchant_id': merchantId,
          'p_items': items,
          'p_discount': discount,
          'p_payment_method': _paymentMethod,
          if (_customerCtrl.text.trim().isNotEmpty)
            'p_customer_name': _customerCtrl.text.trim(),
          'p_idempotency_key': _saleKey,
        },
      );
      if (!mounted) return;
      final total = (res as Map)['total'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.posSaleComplete} — ${l10n.posSaleTotal}: '
            '${(total as num).toStringAsFixed(2)} ${l10n.currencySymbol}',
          ),
          backgroundColor: AppColors.successLight,
        ),
      );
      setState(() {
        _cart.clear();
        _discountCtrl.text = '0';
        _customerCtrl.clear();
        _saleKey = _newSaleKey();
      });
      // Stock changed server-side; refresh the shared products provider.
      ref.invalidate(merchantProductsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.posSaleFailed}: $e'),
          backgroundColor: AppColors.errorLight,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final merchantIdAsync = ref.watch(providerMerchantIdProvider);
    final productsAsync = ref.watch(merchantProductsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.posCashier)),
      body: merchantIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (merchantId) => productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (allProducts) {
            final products = allProducts
                .where((p) => p['is_available'] == true)
                .toList();
            final subtotal = _previewSubtotal(products);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: products.isEmpty
                      ? Center(child: Text(l10n.posNoProducts))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                childAspectRatio: 0.85,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                          itemCount: products.length,
                          itemBuilder: (context, i) =>
                              _ProductCard(
                                product: products[i],
                                qty: _cart[products[i]['id']] ?? 0,
                                l10n: l10n,
                                onTap: () {
                                  final id = products[i]['id'] as String;
                                  final stock =
                                      (products[i]['stock_quantity'] as num?)
                                          ?.toInt() ??
                                      0;
                                  if ((_cart[id] ?? 0) < stock) {
                                    setState(
                                      () => _cart[id] = (_cart[id] ?? 0) + 1,
                                    );
                                  }
                                },
                              ),
                        ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: _CartPanel(
                    cart: _cart,
                    products: products,
                    l10n: l10n,
                    discountCtrl: _discountCtrl,
                    customerCtrl: _customerCtrl,
                    paymentMethod: _paymentMethod,
                    submitting: _submitting,
                    subtotal: subtotal,
                    onPaymentChanged: (m) =>
                        setState(() => _paymentMethod = m),
                    onQtyChanged: (id, qty) => setState(() {
                      if (qty <= 0) {
                        _cart.remove(id);
                      } else {
                        _cart[id] = qty;
                      }
                    }),
                    onClear: () => setState(_cart.clear),
                    onComplete: () => _completeSale(merchantId),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.qty,
    required this.l10n,
    required this.onTap,
  });

  final Map<String, dynamic> product;
  final int qty;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (product['name'] ?? '').toString();
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = (product['stock_quantity'] as num?)?.toInt() ?? 0;
    final soldOut = stock <= 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: soldOut ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${price.toStringAsFixed(2)} ${l10n.currencySymbol}',
                style: const TextStyle(
                  color: AppColors.brandPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                soldOut
                    ? l10n.outOfStock
                    : '${l10n.quantity}: $stock${qty > 0 ? '  •  $qty' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: soldOut ? AppColors.errorLight : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.cart,
    required this.products,
    required this.l10n,
    required this.discountCtrl,
    required this.customerCtrl,
    required this.paymentMethod,
    required this.submitting,
    required this.subtotal,
    required this.onPaymentChanged,
    required this.onQtyChanged,
    required this.onClear,
    required this.onComplete,
  });

  final Map<String, int> cart;
  final List<Map<String, dynamic>> products;
  final AppLocalizations l10n;
  final TextEditingController discountCtrl;
  final TextEditingController customerCtrl;
  final String paymentMethod;
  final bool submitting;
  final double subtotal;
  final ValueChanged<String> onPaymentChanged;
  final void Function(String productId, int qty) onQtyChanged;
  final VoidCallback onClear;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final p in products)
        if ((cart[p['id']] ?? 0) > 0) p,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              l10n.cart,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (lines.isNotEmpty)
              TextButton(onPressed: onClear, child: Text(l10n.clearCart)),
          ],
        ),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text(l10n.posTapToAdd)),
          )
        else
          for (final p in lines)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                (p['name'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${((p['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} '
                '${l10n.currencySymbol}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () =>
                        onQtyChanged(p['id'] as String, (cart[p['id']] ?? 1) - 1),
                  ),
                  Text('${cart[p['id']]}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final stock =
                          (p['stock_quantity'] as num?)?.toInt() ?? 0;
                      final cur = cart[p['id']] ?? 0;
                      if (cur < stock) {
                        onQtyChanged(p['id'] as String, cur + 1);
                      }
                    },
                  ),
                ],
              ),
            ),
        const Divider(height: 24),
        TextField(
          controller: customerCtrl,
          decoration: InputDecoration(
            labelText: l10n.posCustomerNameOptional,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: discountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.discount,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: paymentMethod,
          decoration: InputDecoration(
            labelText: l10n.paymentMethod,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            DropdownMenuItem(value: 'cash', child: Text(l10n.cash)),
            DropdownMenuItem(value: 'instapay', child: Text(l10n.instapay)),
            DropdownMenuItem(
              value: 'vodafone_cash',
              child: Text(l10n.posVodafoneCash),
            ),
          ],
          onChanged: (v) {
            if (v != null) onPaymentChanged(v);
          },
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.subtotal),
            Text(
              '${subtotal.toStringAsFixed(2)} ${l10n.currencySymbol}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: lines.isEmpty || submitting ? null : onComplete,
          icon: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.point_of_sale_rounded),
          label: Text(l10n.posCompleteSale),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}
