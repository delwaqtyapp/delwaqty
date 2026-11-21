import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:math';

import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
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

  // Note: 1 << 32 overflows to 0 in compiled web JS; keep the bound < 2^31.
  static String _newSaleKey() =>
      'pos-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

  Future<void> _completeSale(String merchantId) async {
    if (_cart.isEmpty || _submitting) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);
    try {
      final items = [
        for (final e in _cart.entries) {'product_id': e.key, 'qty': e.value},
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
          content: Text('${l10n.posSaleFailed}: ${appErrorText(context, e)}'),
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
        error: (e, _) => Center(child: Text(appErrorText(context, e))),
        data: (merchantId) => productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(appErrorText(context, e))),
          data: (allProducts) {
            final products = allProducts
                .where((p) => p['is_available'] == true)
                .toList();
            final subtotal = _previewSubtotal(products);
            final narrow = MediaQuery.sizeOf(context).width < 640;
            final productsPane = products.isEmpty
                ? Center(child: Text(l10n.posNoProducts))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          // Fixed tile height: image/monogram area above a
                          // 2-line name, price and stock rows.
                          mainAxisExtent: 210,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, i) => _ProductCard(
                      product: products[i],
                      qty: _cart[products[i]['id']] ?? 0,
                      l10n: l10n,
                      onTap: () {
                        final id = products[i]['id'] as String;
                        final stock =
                            (products[i]['stock_quantity'] as num?)?.toInt() ??
                            0;
                        if ((_cart[id] ?? 0) < stock) {
                          setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
                        }
                      },
                    ),
                  );
            final cartPane = _CartPanel(
              cart: _cart,
              products: products,
              l10n: l10n,
              discountCtrl: _discountCtrl,
              customerCtrl: _customerCtrl,
              paymentMethod: _paymentMethod,
              submitting: _submitting,
              subtotal: subtotal,
              onPaymentChanged: (m) => setState(() => _paymentMethod = m),
              onQtyChanged: (id, qty) => setState(() {
                if (qty <= 0) {
                  _cart.remove(id);
                } else {
                  _cart[id] = qty;
                }
              }),
              onClear: () => setState(_cart.clear),
              onComplete: () => _completeSale(merchantId),
            );
            if (narrow) {
              // Stack cart under products; a side-by-side split leaves the
              // cart unusably narrow on phones.
              return Column(
                children: [
                  Expanded(flex: 3, child: productsPane),
                  const Divider(height: 1),
                  Expanded(flex: 2, child: cartPane),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: productsPane),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: cartPane),
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
    final theme = Theme.of(context);
    final name = (product['name'] ?? '').toString();
    final imageUrl = (product['image_url'] ?? '').toString();
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = (product['stock_quantity'] as num?)?.toInt() ?? 0;
    final soldOut = stock <= 0;
    final monogram = name.trim().isEmpty ? '؟' : name.trim()[0];

    final visual = imageUrl.isNotEmpty
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _MonogramTile(letter: monogram),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _MonogramTile(letter: monogram),
          )
        : _MonogramTile(letter: monogram);

    return Opacity(
      opacity: soldOut ? 0.45 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: soldOut ? null : onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    visual,
                    if (qty > 0)
                      PositionedDirectional(
                        top: 6,
                        start: 6,
                        child: Badge(
                          label: Text('$qty'),
                          backgroundColor: AppColors.brandPurple,
                          textColor: Colors.white,
                        ),
                      ),
                    if (soldOut)
                      PositionedDirectional(
                        bottom: 6,
                        start: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: AppSpacing.borderRadiusMd,
                          ),
                          child: Text(
                            l10n.outOfStock,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${price.toStringAsFixed(2)} ${l10n.currencySymbol}',
                      style: AppTextStyles.price.copyWith(
                        color: AppColors.brandPurple,
                      ),
                    ),
                    Text(
                      '${l10n.quantity}: $stock',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: soldOut
                            ? AppColors.errorLight
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonogramTile extends StatelessWidget {
  const _MonogramTile({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandLavender,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTextStyles.displaySmall.copyWith(
          color: AppColors.brandPurple,
          fontWeight: FontWeight.w800,
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
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    l10n.cart,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: () => onQtyChanged(
                            p['id'] as String,
                            (cart[p['id']] ?? 1) - 1,
                          ),
                        ),
                        Text('${cart[p['id']]}'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                  DropdownMenuItem(
                    value: 'instapay',
                    child: Text(l10n.instapay),
                  ),
                  DropdownMenuItem(
                    value: 'vodafone_cash',
                    child: Text(l10n.posVodafoneCash),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onPaymentChanged(v);
                },
              ),
            ],
          ),
        ),
        // Sticky charge bar: total (22sp price style) + 56dp charge button.
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${subtotal.toStringAsFixed(2)} ${l10n.currencySymbol}',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: lines.isEmpty || submitting ? null : onComplete,
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.point_of_sale_rounded),
                    label: Text(
                      l10n.posCharge,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
