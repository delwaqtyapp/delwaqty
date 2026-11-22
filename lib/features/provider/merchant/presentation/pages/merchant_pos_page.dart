import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:math';

import 'package:delwaqty/shared/widgets/error_state.dart';
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
  /// line key -> quantity. Key is the bare product id for plain lines, or
  /// 'productId|sortedOptionId1,sortedOptionId2,...' for lines with
  /// modifiers, so the same product with different options stays separate.
  final Map<String, int> _cart = {};
  final Map<String, List<String>> _cartOptionIds = {};
  final Map<String, String> _cartOptionLabel = {};
  final Map<String, double> _cartSurcharge = {};
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

  int _qtyForProduct(String productId) {
    var sum = 0;
    for (final e in _cart.entries) {
      if (e.key.split('|').first == productId) sum += e.value;
    }
    return sum;
  }

  Future<void> _onProductTap(Map<String, dynamic> product) async {
    final id = product['id'] as String;
    final stock = (product['stock_quantity'] as num?)?.toInt() ?? 0;
    if (_qtyForProduct(id) >= stock) return;
    List<_ModifierGroup> groups;
    try {
      groups = await ref.read(_posModifierGroupsProvider(id).future);
    } catch (_) {
      groups = const [];
    }
    if (!mounted) return;
    if (groups.isEmpty) {
      setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
      return;
    }
    final selection = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ModifierSheet(groups: groups),
    );
    if (selection == null || !mounted) return;
    final sorted = [...selection]..sort();
    final key = '$id|${sorted.join(',')}';
    var surcharge = 0.0;
    final labels = <String>[];
    for (final g in groups) {
      for (final o in g.options) {
        if (sorted.contains(o.id)) {
          surcharge += o.priceAdjustment;
          labels.add(o.displayName);
        }
      }
    }
    setState(() {
      _cart[key] = (_cart[key] ?? 0) + 1;
      _cartOptionIds[key] = sorted;
      _cartOptionLabel[key] = labels.join(', ');
      _cartSurcharge[key] = surcharge;
    });
  }

  double _previewSubtotal(List<Map<String, dynamic>> products) {
    final byId = {for (final p in products) p['id'] as String: p};
    var sum = 0.0;
    for (final e in _cart.entries) {
      final product = byId[e.key.split('|').first];
      if (product == null) continue;
      final unit =
          ((product['price'] as num?)?.toDouble() ?? 0) +
          (_cartSurcharge[e.key] ?? 0);
      sum += unit * e.value;
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
        for (final e in _cart.entries)
          {
            'product_id': e.key.split('|').first,
            'qty': e.value,
            if ((_cartOptionIds[e.key] ?? const []).isNotEmpty)
              'modifier_option_ids': _cartOptionIds[e.key],
          },
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
        _cartOptionIds.clear();
        _cartOptionLabel.clear();
        _cartSurcharge.clear();
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
          content: Text(
            '${l10n.posSaleFailed}: ${posSaleErrorText(context, e)}',
          ),
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
        error: (e, _) => ErrorState(
          message: appErrorText(context, e),
          retryLabel: AppLocalizations.of(context).errorRetryCta,
          onRetry: () => ref.invalidate(providerMerchantIdProvider),
        ),
        data: (merchantId) => productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: appErrorText(context, e),
            retryLabel: AppLocalizations.of(context).errorRetryCta,
            onRetry: () => ref.invalidate(merchantProductsProvider),
          ),
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
                      qty: _qtyForProduct(products[i]['id'] as String),
                      l10n: l10n,
                      onTap: () => _onProductTap(products[i]),
                    ),
                  );
            final cartPane = _CartPanel(
              cart: _cart,
              optionLabels: _cartOptionLabel,
              surcharges: _cartSurcharge,
              products: products,
              l10n: l10n,
              discountCtrl: _discountCtrl,
              customerCtrl: _customerCtrl,
              paymentMethod: _paymentMethod,
              submitting: _submitting,
              subtotal: subtotal,
              onPaymentChanged: (m) => setState(() => _paymentMethod = m),
              onQtyChanged: (lineKey, qty) => setState(() {
                if (qty <= 0) {
                  _cart.remove(lineKey);
                  _cartOptionIds.remove(lineKey);
                  _cartOptionLabel.remove(lineKey);
                  _cartSurcharge.remove(lineKey);
                } else {
                  _cart[lineKey] = qty;
                }
              }),
              onClear: () => setState(() {
                _cart.clear();
                _cartOptionIds.clear();
                _cartOptionLabel.clear();
                _cartSurcharge.clear();
              }),
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
    required this.optionLabels,
    required this.surcharges,
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
  final Map<String, String> optionLabels;
  final Map<String, double> surcharges;
  final List<Map<String, dynamic>> products;
  final AppLocalizations l10n;
  final TextEditingController discountCtrl;
  final TextEditingController customerCtrl;
  final String paymentMethod;
  final bool submitting;
  final double subtotal;
  final ValueChanged<String> onPaymentChanged;
  final void Function(String lineKey, int qty) onQtyChanged;
  final VoidCallback onClear;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final p in products) p['id'] as String: p};
    final lines = [
      for (final e in cart.entries)
        if (e.value > 0 && byId.containsKey(e.key.split('|').first)) e,
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
                for (final line in lines)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      (byId[line.key.split('|').first]!['name'] ?? '')
                          .toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${(((byId[line.key.split('|').first]!['price'] as num?)?.toDouble() ?? 0) + (surcharges[line.key] ?? 0)).toStringAsFixed(2)} '
                      '${l10n.currencySymbol}'
                      '${(optionLabels[line.key] ?? '').isEmpty ? '' : ' · ${optionLabels[line.key]}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                          onPressed: () =>
                              onQtyChanged(line.key, (cart[line.key] ?? 1) - 1),
                        ),
                        Text('${cart[line.key]}'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: () {
                            final p = byId[line.key.split('|').first]!;
                            final stock =
                                (p['stock_quantity'] as num?)?.toInt() ?? 0;
                            final cur = cart[line.key] ?? 0;
                            if (cur < stock) {
                              onQtyChanged(line.key, cur + 1);
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

/// Modifier option for the POS picker (product_modifier_options).
class _ModifierOption {
  const _ModifierOption({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.priceAdjustment,
  });

  final String id;
  final String name;
  final String nameAr;
  final double priceAdjustment;

  String get displayName => nameAr.isNotEmpty ? nameAr : name;
}

/// Modifier group with its options (product_modifier_groups).
class _ModifierGroup {
  const _ModifierGroup({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.isRequired,
    required this.maxSelections,
    required this.options,
  });

  final String id;
  final String name;
  final String nameAr;
  final bool isRequired;

  /// 0 or null means unlimited.
  final int maxSelections;
  final List<_ModifierOption> options;

  String get displayName => nameAr.isNotEmpty ? nameAr : name;
}

/// Lazily fetched modifier groups (+ options) per product for the POS picker.
final _posModifierGroupsProvider =
    FutureProvider.family<List<_ModifierGroup>, String>((ref, productId) async {
      final client = Supabase.instance.client;
      final groups = await client
          .from('product_modifier_groups')
          .select('id, name, name_ar, is_required, max_selections, sort_order')
          .eq('product_id', productId)
          .order('sort_order');
      final groupRows = (groups as List).cast<Map<String, dynamic>>();
      if (groupRows.isEmpty) return const [];
      final groupIds = [for (final g in groupRows) g['id'] as String];
      final options = await client
          .from('product_modifier_options')
          .select('id, group_id, name, name_ar, price_adjustment, sort_order')
          .inFilter('group_id', groupIds)
          .order('sort_order');
      final optionRows = (options as List).cast<Map<String, dynamic>>();
      return [
        for (final g in groupRows)
          _ModifierGroup(
            id: g['id'] as String,
            name: (g['name'] ?? '').toString(),
            nameAr: (g['name_ar'] ?? '').toString(),
            isRequired: g['is_required'] == true,
            maxSelections: (g['max_selections'] as num?)?.toInt() ?? 0,
            options: [
              for (final o in optionRows)
                if (o['group_id'] == g['id'])
                  _ModifierOption(
                    id: o['id'] as String,
                    name: (o['name'] ?? '').toString(),
                    nameAr: (o['name_ar'] ?? '').toString(),
                    priceAdjustment:
                        (o['price_adjustment'] as num?)?.toDouble() ?? 0,
                  ),
            ],
          ),
      ];
    });

/// Bottom sheet to pick modifier options before adding a product to the cart.
/// Returns the selected option ids, or null when cancelled. Required groups
/// must have at least one pick before the confirm button enables.
class _ModifierSheet extends StatefulWidget {
  const _ModifierSheet({required this.groups});

  final List<_ModifierGroup> groups;

  @override
  State<_ModifierSheet> createState() => _ModifierSheetState();
}

class _ModifierSheetState extends State<_ModifierSheet> {
  final Map<String, Set<String>> _selected = {};

  bool get _valid {
    for (final g in widget.groups) {
      if (g.isRequired && (_selected[g.id] ?? const {}).isEmpty) return false;
    }
    return true;
  }

  void _toggle(_ModifierGroup g, _ModifierOption o) {
    setState(() {
      final sel = _selected.putIfAbsent(g.id, () => <String>{});
      if (g.maxSelections == 1) {
        // Radio behavior for single-choice groups.
        if (sel.contains(o.id) && !g.isRequired) {
          sel.clear();
        } else {
          sel
            ..clear()
            ..add(o.id);
        }
      } else if (sel.contains(o.id)) {
        sel.remove(o.id);
      } else if (g.maxSelections <= 0 || sel.length < g.maxSelections) {
        sel.add(o.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final g in widget.groups) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.displayName,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  if (g.isRequired)
                    Text(
                      l10n.posModifierRequired,
                      style: const TextStyle(color: AppColors.errorLight),
                    ),
                ],
              ),
              for (final o in g.options)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: (_selected[g.id] ?? const {}).contains(o.id),
                  onChanged: (_) => _toggle(g, o),
                  title: Text(o.displayName),
                  subtitle: o.priceAdjustment == 0
                      ? null
                      : Text(
                          '+${o.priceAdjustment.toStringAsFixed(2)} '
                          '${l10n.currencySymbol}',
                        ),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid
                    ? () {
                        final ids = <String>[
                          for (final sel in _selected.values) ...sel,
                        ];
                        Navigator.of(context).pop(ids);
                      }
                    : null,
                child: Text(l10n.posModifierConfirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps pos_create_sale server error codes to readable localized messages.
String posSaleErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  final msg = error.toString();
  if (msg.contains('REQUIRED_MODIFIER_MISSING')) {
    return l10n.posErrModifierRequired;
  }
  if (msg.contains('MODIFIER_MAX_EXCEEDED')) return l10n.posErrModifierMax;
  if (msg.contains('INVALID_MODIFIER') || msg.contains('TOO_MANY_MODIFIERS')) {
    return l10n.posErrModifierInvalid;
  }
  if (msg.contains('INSUFFICIENT_STOCK')) return l10n.posErrStock;
  if (msg.contains('PRODUCT_UNAVAILABLE')) return l10n.posErrUnavailable;
  if (msg.contains('INVALID_QTY') || msg.contains('INVALID_QUANTITY')) {
    return l10n.posErrInvalidQty;
  }
  return appErrorText(context, error);
}
