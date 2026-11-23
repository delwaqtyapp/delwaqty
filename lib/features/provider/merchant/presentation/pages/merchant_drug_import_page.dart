import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Browse the shared drug catalog (migration 203) and stock a drug into the
/// pharmacy's own products with its own price and stock via
/// pharmacy_import_drug. Server re-checks ownership and validates inputs.
class MerchantDrugImportPage extends ConsumerStatefulWidget {
  const MerchantDrugImportPage({super.key});

  @override
  ConsumerState<MerchantDrugImportPage> createState() =>
      _MerchantDrugImportPageState();
}

class _MerchantDrugImportPageState
    extends ConsumerState<MerchantDrugImportPage> {
  final _searchCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('drug_catalog')
        .select(
          'id, name_en, name_ar, active_ingredient, dosage_form, strength, category',
        )
        .eq('is_active', true)
        .order('name_en')
        .limit(500);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> drugs) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return drugs;
    return drugs.where((d) {
      final hay = [
        d['name_en'],
        d['name_ar'],
        d['active_ingredient'],
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _importDialog(Map<String, dynamic> drug) async {
    final l10n = AppLocalizations.of(context);
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${drug['name_en']}${drug['strength'] != null ? ' ${drug['strength']}' : ''}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '${l10n.price} (${l10n.currencySymbol})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.quantity,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.drugImportAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final merchantId = await ref.read(providerMerchantIdProvider.future);
      final price = double.tryParse(priceCtrl.text.trim());
      final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('${l10n.drugImportSuccess}: ${drug['name_en']}'),
          backgroundColor: AppColors.successLight,
        ),
      );
      ref.invalidate(merchantProductsProvider);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.drugImportFailed}: ${appErrorText(context, e)}',
          ),
          backgroundColor: AppColors.errorLight,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.drugImportTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.drugImportSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(appErrorText(context, snap.error!)),
                  );
                }
                final drugs = _filtered(snap.data ?? const []);
                if (drugs.isEmpty) {
                  return Center(child: Text(l10n.noResults));
                }
                return ListView.separated(
                  itemCount: drugs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = drugs[i];
                    final subtitle = [
                      d['active_ingredient'],
                      d['strength'],
                      d['dosage_form'],
                    ].whereType<String>().join(' · ');
                    // Stacked layout: the name/subtitle use the full width
                    // and the import action sits on its own line below, so
                    // long drug names are never squeezed beside the button.
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (d['name_en'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            [
                              if ((d['name_ar'] ?? '').toString().isNotEmpty)
                                d['name_ar'],
                              if (subtitle.isNotEmpty) subtitle,
                            ].join(' — '),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FilledButton.tonal(
                              onPressed: () => _importDialog(d),
                              child: Text(l10n.drugImportAction),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
