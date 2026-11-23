import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:math';

import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/merchant/domain/pos_product_lookup.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/barcode_scanner_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';

/// In-store cashier (POS): pick products, build a cart, and complete the
/// sale through the server-priced pos_create_sale RPC (migration 201).
/// Pricing, stock decrement and commission all happen server-side; the
/// client-side subtotal below is only a preview.
class MerchantPosPage extends ConsumerStatefulWidget {
  const MerchantPosPage({super.key});

  @override
  ConsumerState<MerchantPosPage> createState() => _MerchantPosPageState();
}

/// Outcome of a tap/scan add attempt, so scan-to-add reports the truth.
enum _ProductAddResult { added, stockLimited, cancelled }

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
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  /// Every store product, including unavailable ones. Barcode matching runs
  /// against this set so scanning a hidden/unavailable item says exactly
  /// that instead of falling through to catalog import or quick-create.
  List<Map<String, dynamic>> _allProducts = const [];
  String _paymentMethod = 'cash';
  bool _submitting = false;
  String _saleKey = _newSaleKey();

  @override
  void dispose() {
    _discountCtrl.dispose();
    _customerCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int _qtyForProduct(String productId) {
    var sum = 0;
    for (final e in _cart.entries) {
      if (e.key.split('|').first == productId) sum += e.value;
    }
    return sum;
  }

  /// Adds one unit of [product] to the cart. Returns what actually
  /// happened so callers (scan-to-add) report the truth: a cancelled
  /// modifier sheet or a stock limit is NOT an add.
  Future<_ProductAddResult> _onProductTap(Map<String, dynamic> product) async {
    final id = product['id'] as String;
    final stock = (product['stock_quantity'] as num?)?.toInt() ?? 0;
    if (_qtyForProduct(id) >= stock) return _ProductAddResult.stockLimited;
    List<_ModifierGroup> groups;
    try {
      groups = await ref.read(_posModifierGroupsProvider(id).future);
    } catch (_) {
      groups = const [];
    }
    if (!mounted) return _ProductAddResult.cancelled;
    if (groups.isEmpty) {
      setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
      return _ProductAddResult.added;
    }
    final selection = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ModifierSheet(groups: groups),
    );
    if (selection == null || !mounted) return _ProductAddResult.cancelled;
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
    return _ProductAddResult.added;
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

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.errorLight
            : AppColors.successLight,
      ),
    );
  }

  /// Opens the camera scanner and routes the result through [_onBarcode].
  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerPage.show(context);
    if (!mounted || code == null) return;
    await _onBarcode(code);
  }

  /// Handles a scanned or typed barcode in priority order:
  /// 1. exact match in the store's own products -> add to cart;
  /// 2. pharmacy accounts: match in the shared drug catalog -> import with
  ///    the official MoH price pre-filled, then add;
  /// 3. otherwise offer quick product creation with the barcode pre-filled.
  Future<void> _onBarcode(String code) async {
    final l10n = AppLocalizations.of(context);
    final barcode = normalizeBarcode(code);
    if (barcode.isEmpty) return;

    final match = findProductByBarcode(_allProducts, barcode);
    if (match != null) {
      if (match['is_available'] != true) {
        _showSnack(l10n.posErrUnavailable, isError: true);
        return;
      }
      final stock = (match['stock_quantity'] as num?)?.toInt() ?? 0;
      if (stock <= 0) {
        _showSnack(l10n.posErrStock, isError: true);
        return;
      }
      final result = await _onProductTap(match);
      if (!mounted) return;
      switch (result) {
        case _ProductAddResult.added:
          _showSnack('${l10n.posScanAdded}: ${match['name']}', isError: false);
        case _ProductAddResult.stockLimited:
          _showSnack(l10n.posErrStock, isError: true);
        case _ProductAddResult.cancelled:
          break;
      }
      return;
    }

    if (ref.read(providerCategoryProvider) == ProviderCategory.pharmacy) {
      final drug = await _findDrugByBarcode(barcode);
      if (!mounted) return;
      if (drug != null) {
        await _confirmDrugImport(drug, barcode);
        return;
      }
    }

    await _quickAddProduct(barcode);
  }

  /// Barcode lookup into the shared drug catalog (drug_catalog.barcode).
  Future<Map<String, dynamic>?> _findDrugByBarcode(String barcode) async {
    try {
      final rows = await Supabase.instance.client
          .from('drug_catalog')
          .select(
            'id, name_en, name_ar, strength, dosage_form, official_price_egp',
          )
          .eq('is_active', true)
          .eq('barcode', barcode)
          .limit(1);
      final list = (rows as List).cast<Map<String, dynamic>>();
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  /// Pharmacy path: confirm importing a catalog drug scanned at the till.
  /// pharmacy_import_drug is idempotent per store (it returns the existing
  /// product on a duplicate barcode), so a double scan stays safe.
  Future<void> _confirmDrugImport(
    Map<String, dynamic> drug,
    String barcode,
  ) async {
    final l10n = AppLocalizations.of(context);
    final official = (drug['official_price_egp'] as num?)?.toDouble();
    final priceCtrl = TextEditingController(
      text: official != null ? official.toStringAsFixed(2) : '',
    );
    final stockCtrl = TextEditingController(text: '0');
    final nameEn = (drug['name_en'] ?? '').toString();
    final strength = (drug['strength'] ?? '').toString();
    final nameAr = (drug['name_ar'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).posDrugFoundTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$nameEn${strength.isEmpty ? '' : ' $strength'}',
              style: AppTextStyles.titleMedium,
            ),
            if (nameAr.isNotEmpty) Text(nameAr),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    '${AppLocalizations.of(ctx).price} (${AppLocalizations.of(ctx).currencySymbol})',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx).quantity,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx).posDrugImportAdd),
          ),
        ],
      ),
    );
    final priceText = priceCtrl.text.trim();
    final stockText = stockCtrl.text.trim();
    // The dialog route is still animating out and rebuilding its fields;
    // dispose the controllers only after it has fully closed.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        priceCtrl.dispose();
        stockCtrl.dispose();
      }),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final merchantId = await ref.read(providerMerchantIdProvider.future);
      final price = double.tryParse(priceText);
      final stock = int.tryParse(stockText) ?? 0;
      if (price == null || price < 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.drugImportInvalidPrice),
            backgroundColor: AppColors.errorLight,
          ),
        );
        return;
      }
      await Supabase.instance.client.rpc(
        'pharmacy_import_drug',
        params: {
          'p_drug_id': drug['id'],
          'p_merchant_id': merchantId,
          'p_price': price,
          'p_stock': stock,
        },
      );
      if (!mounted) return;
      ref.invalidate(merchantProductsProvider);
      await _addFreshProductByBarcode(merchantId, barcode);
    } catch (e) {
      if (!mounted) return;
      // Lost a race with another till importing the same drug: the unique
      // index rejected the insert (the server also maps this to
      // duplicate:true), so just re-read and add the product that won.
      final msg = e.toString();
      if (msg.contains('products_merchant_barcode_uq') ||
          msg.contains('duplicate key')) {
        try {
          final merchantId = await ref.read(providerMerchantIdProvider.future);
          if (!mounted) return;
          ref.invalidate(merchantProductsProvider);
          await _addFreshProductByBarcode(merchantId, barcode);
        } catch (_) {}
        return;
      }
      _showSnack(
        '${l10n.drugImportFailed}: ${appErrorText(context, e)}',
        isError: true,
      );
    }
  }

  /// Unknown barcode: let the merchant create the product on the spot with
  /// the barcode already attached, then add it to the cart. This is what
  /// makes the cashier usable on day one in a grocery that has no catalog.
  Future<void> _quickAddProduct(String barcode) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10nDialog = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10nDialog.posQuickAddTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10nDialog.barcodeFieldLabel,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(barcode),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10nDialog.productName,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10nDialog.fieldRequired
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '${l10nDialog.price} (${l10nDialog.currencySymbol})',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return l10nDialog.invalidPrice;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10nDialog.quantity,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10nDialog.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(l10nDialog.posQuickAddCreate),
            ),
          ],
        );
      },
    );
    final name = nameCtrl.text.trim();
    final priceText = priceCtrl.text.trim();
    final stockText = stockCtrl.text.trim();
    // The dialog route is still animating out and rebuilding its fields;
    // dispose the controllers only after it has fully closed.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        nameCtrl.dispose();
        priceCtrl.dispose();
        stockCtrl.dispose();
      }),
    );
    if (confirmed != true || !mounted) return;

    try {
      final merchantId = await ref.read(providerMerchantIdProvider.future);
      final repo = ref.read(merchantDashboardRepositoryProvider);
      await repo.createProduct(merchantId, {
        'name': name,
        'description': '',
        'price': double.parse(priceText),
        'category': '',
        'image_url': '',
        'barcode': barcode,
        'stock_quantity': int.tryParse(stockText) ?? 0,
        'is_available': true,
        'is_featured': false,
      });
      if (!mounted) return;
      ref.invalidate(merchantProductsProvider);
      await _addFreshProductByBarcode(merchantId, barcode);
      if (mounted) {
        _showSnack('${l10n.productCreated}: $name', isError: false);
      }
    } catch (e) {
      if (!mounted) return;
      // Lost a race with another till that created the same barcode first:
      // the unique index rejected the insert, so just add theirs.
      final msg = e.toString();
      if (msg.contains('products_merchant_barcode_uq') ||
          msg.contains('duplicate key')) {
        final merchantId = await ref.read(providerMerchantIdProvider.future);
        if (!mounted) return;
        await _addFreshProductByBarcode(merchantId, barcode);
      } else {
        _showSnack(l10n.somethingWentWrong, isError: true);
      }
    }
  }

  /// Re-reads the store's products after a create/import and adds the row
  /// carrying [barcode] to the cart (through the normal tap path so modifier
  /// groups and stock checks still apply).
  Future<void> _addFreshProductByBarcode(
    String merchantId,
    String barcode,
  ) async {
    final repo = ref.read(merchantDashboardRepositoryProvider);
    final fresh = await repo.getMerchantProducts(merchantId);
    if (!mounted) return;
    final product = findProductByBarcode(fresh, barcode);
    if (product == null) return;
    if (product['is_available'] == true) {
      await _onProductTap(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final merchantIdAsync = ref.watch(providerMerchantIdProvider);
    final productsAsync = ref.watch(merchantProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.posCashier),
        actions: [
          IconButton(
            tooltip: l10n.posScanBarcode,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _scanBarcode,
          ),
          IconButton(
            tooltip: l10n.products,
            icon: const Icon(Icons.inventory_2_rounded),
            onPressed: () async {
              // Product & price management stays one tap from the till.
              await context.push('/merchant-dashboard/products');
              if (mounted) ref.invalidate(merchantProductsProvider);
            },
          ),
        ],
      ),
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
            final sellable = allProducts
                .where((p) => p['is_available'] == true)
                .toList();
            _allProducts = allProducts;
            final products = filterProductsForPos(sellable, _searchQuery);
            final subtotal = _previewSubtotal(sellable);
            final narrow = MediaQuery.sizeOf(context).width < 640;
            final productsPane = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  // One box for name search and typed barcodes: submitting an
                  // exact barcode adds the product straight to the cart.
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.posSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _searchQuery = '';
                              }),
                            ),
                          IconButton(
                            tooltip: l10n.posScanBarcode,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: _scanBarcode,
                          ),
                        ],
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    // Scanner, manual sheet and typed submit all funnel
                    // through the same handler. A typed value counts as a
                    // barcode when it matches a product barcode exactly, or
                    // when it is a bare numeric code worth looking up in the
                    // drug catalog / quick-create (a name search stays a
                    // search: onChanged already filters the grid).
                    onSubmitted: (v) {
                      final q = normalizeBarcode(v);
                      if (q.isEmpty) return;
                      final looksLikeCode = RegExp(r'^\d{4,}$').hasMatch(q);
                      if (findProductByBarcode(_allProducts, q) != null ||
                          looksLikeCode) {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                        _onBarcode(q);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: products.isEmpty
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
                        ),
                ),
              ],
            );
            final cartPane = _CartPanel(
              cart: _cart,
              optionLabels: _cartOptionLabel,
              surcharges: _cartSurcharge,
              products: sellable,
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
              // cart unusably narrow on phones. While the keyboard is open
              // the split flips in the cart's favor: discount, customer and
              // payment must stay fully reachable, and the cashier is
              // typing, not browsing the grid.
              final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
              return Column(
                children: [
                  Expanded(flex: keyboardOpen ? 1 : 3, child: productsPane),
                  const Divider(height: 1),
                  Expanded(flex: keyboardOpen ? 3 : 2, child: cartPane),
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
            // Extra bottom clearance keeps the payment dropdown and its popup
            // menu above the shell's floating bottom nav (extendBody: true).
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + kFloatingNavClearance + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.cart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12 + kFloatingNavClearance,
            ),
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
