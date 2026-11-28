import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

/// Rows of `delivery_pricing`, read by admins. RLS ("delivery_pricing admin
/// manage") already limits writes to country admins, so no DB change is needed.
final adminDeliveryPricingRowsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final rows = await ref
          .watch(supabaseClientProvider)
          .from('delivery_pricing')
          .select()
          .order('service_type');
      return List<Map<String, dynamic>>.from(rows as List);
    });

/// Validates and parses the edited values. Returns null when invalid.
Map<String, dynamic>? parseDeliveryPricingInput({
  required String baseFee,
  required String perKm,
  required String perKg,
  required String minimumFee,
  required String priorityMultiplier,
  required String expressMultiplier,
  required bool isActive,
}) {
  double? p(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
  final b = p(baseFee);
  final km = p(perKm);
  final kg = p(perKg);
  final mn = p(minimumFee);
  final pr = p(priorityMultiplier);
  final ex = p(expressMultiplier);
  if ([b, km, kg, mn, pr, ex].any((v) => v == null || !v.isFinite)) {
    return null;
  }
  if (b! < 0 || km! < 0 || kg! < 0 || mn! < 0) return null;
  if (pr! < 1 || pr > 5 || ex! < 1 || ex > 5) return null;
  if (b > 99999 || km > 99999 || kg > 99999 || mn > 99999) return null;
  return {
    'base_fee': b,
    'per_km': km,
    'per_kg': kg,
    'minimum_fee': mn,
    'priority_multiplier': pr,
    'express_multiplier': ex,
    'is_active': isActive,
  };
}

class AdminDeliveryPricingPage extends ConsumerWidget {
  const AdminDeliveryPricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(adminDeliveryPricingRowsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDeliveryPricing),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminDeliveryPricingRowsProvider),
          ),
        ],
      ),
      body: rows.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: appErrorText(context, e),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                l10n.adminDeliveryPricingNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final row in list)
              _PricingCard(key: ValueKey(row['service_type']), row: row),
          ],
        ),
      ),
    );
  }
}

class _PricingCard extends ConsumerStatefulWidget {
  const _PricingCard({super.key, required this.row});
  final Map<String, dynamic> row;

  @override
  ConsumerState<_PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends ConsumerState<_PricingCard> {
  late final Map<String, TextEditingController> _c;
  late bool _active;
  bool _saving = false;

  static const _fields = [
    'base_fee',
    'per_km',
    'per_kg',
    'minimum_fee',
    'priority_multiplier',
    'express_multiplier',
  ];

  @override
  void initState() {
    super.initState();
    _c = {
      for (final f in _fields)
        f: TextEditingController(text: '${widget.row[f] ?? 0}'),
    };
    _active = widget.row['is_active'] as bool? ?? true;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _label(AppLocalizations l10n, String f) => switch (f) {
    'base_fee' => l10n.adminPricingBaseFee,
    'per_km' => l10n.adminPricingPerKm,
    'per_kg' => l10n.adminPricingPerKg,
    'minimum_fee' => l10n.adminPricingMinFee,
    'priority_multiplier' => l10n.adminPricingPriorityX,
    _ => l10n.adminPricingExpressX,
  };

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = parseDeliveryPricingInput(
      baseFee: _c['base_fee']!.text,
      perKm: _c['per_km']!.text,
      perKg: _c['per_kg']!.text,
      minimumFee: _c['minimum_fee']!.text,
      priorityMultiplier: _c['priority_multiplier']!.text,
      expressMultiplier: _c['express_multiplier']!.text,
      isActive: _active,
    );
    if (data == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminPricingInvalid)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(supabaseClientProvider)
          .from('delivery_pricing')
          .update({
            ...data,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('service_type', widget.row['service_type'] as String);
      ref.invalidate(adminDeliveryPricingRowsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminPricingSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.row['service_type']} (${widget.row['currency'] ?? 'EGP'})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(l10n.adminPricingActive, style: theme.textTheme.bodySmall),
                Switch(
                  value: _active,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _active = v),
                ),
              ],
            ),
            for (final f in _fields)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _c[f],
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _label(l10n, f),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
