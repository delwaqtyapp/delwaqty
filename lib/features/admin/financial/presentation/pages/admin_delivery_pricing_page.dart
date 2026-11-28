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

/// True for the owner and country-level admins, the only roles RLS lets write
/// `delivery_pricing`. Regional admins can read but not edit.
final adminCanEditDeliveryPricingProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;
  try {
    final res = await client.rpc(
      '_is_country_admin_uid',
      params: {'p_uid': uid},
    );
    return res == true;
  } catch (_) {
    return false;
  }
});

/// Thrown when an update touched no row (RLS denied the write).
class DeliveryPricingNotSavedException implements Exception {
  const DeliveryPricingNotSavedException();
}

/// Writes one pricing row. Throws [DeliveryPricingNotSavedException] when no
/// row was updated: RLS hides rows the caller may not write, so a denied
/// write returns an empty list instead of an error.
typedef DeliveryPricingSaver = Future<Map<String, dynamic>> Function(
  String serviceType,
  Map<String, dynamic> data,
);

final deliveryPricingSaverProvider = Provider<DeliveryPricingSaver>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (serviceType, data) async {
    // updated_at is set by the database, not the device clock.
    final updated = await client
        .from('delivery_pricing')
        .update(data)
        .eq('service_type', serviceType)
        .select();
    final rows = updated as List;
    if (rows.isEmpty) throw const DeliveryPricingNotSavedException();
    return Map<String, dynamic>.from(rows.first as Map);
  };
});

/// Maps Arabic-Indic and Persian digits to ASCII and resolves the decimal
/// separator. A comma or Arabic comma counts as a decimal point only when it
/// is the single separator with 1-2 digits after it ("1,5"). Anything else
/// ("1,500", "1,5,5", "1.5,5") returns null so a typo never changes the price.
String? normalizePricingNumber(String v) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final r in v.trim().runes) {
    final ch = String.fromCharCode(r);
    final ai = arabic.indexOf(ch);
    final pi = persian.indexOf(ch);
    if (ai >= 0) {
      b.write(ai);
    } else if (pi >= 0) {
      b.write(pi);
    } else if (ch == '٫') {
      b.write('.');
    } else if (ch == '،') {
      b.write(',');
    } else {
      b.write(ch);
    }
  }
  final t = b.toString();
  final commas = ','.allMatches(t).length;
  if (commas == 0) return t;
  if (commas > 1 || t.contains('.')) return null;
  final trailing = t.length - t.indexOf(',') - 1;
  if (trailing < 1 || trailing > 2) return null;
  return t.replaceFirst(',', '.');
}

const double kMaxPricingFee = 500;
const double kMaxPricingPerUnit = 50;
const double kMaxPricingMultiplier = 3;

/// Fare for [km] and [kg] at standard priority, same formula as the server.
double sampleDeliveryFare(
  Map<String, dynamic> p, {
  double km = 5,
  double kg = 1,
}) {
  final fee =
      (p['base_fee'] as double) +
      (p['per_km'] as double) * km +
      (p['per_kg'] as double) * kg;
  final min = p['minimum_fee'] as double;
  return double.parse((fee < min ? min : fee).toStringAsFixed(2));
}

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
  double? p(String v) {
    final n = normalizePricingNumber(v);
    return n == null ? null : double.tryParse(n);
  }

  final b = p(baseFee);
  final km = p(perKm);
  final kg = p(perKg);
  final mn = p(minimumFee);
  final pr = p(priorityMultiplier);
  final ex = p(expressMultiplier);
  if ([b, km, kg, mn, pr, ex].any((v) => v == null || !v.isFinite)) {
    return null;
  }
  if (b! < 0 || b > kMaxPricingFee || mn! < 0 || mn > kMaxPricingFee) {
    return null;
  }
  if (km! < 0 ||
      km > kMaxPricingPerUnit ||
      kg! < 0 ||
      kg > kMaxPricingPerUnit) {
    return null;
  }
  if (pr! < 1 ||
      pr > kMaxPricingMultiplier ||
      ex! < 1 ||
      ex > kMaxPricingMultiplier) {
    return null;
  }
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
    final canEdit =
        ref.watch(adminCanEditDeliveryPricingProvider).value ?? false;
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
            if (!canEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  l10n.adminPricingReadOnly,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            for (final row in list)
              _PricingCard(
                key: ValueKey(row['service_type']),
                row: row,
                canEdit: canEdit,
              ),
          ],
        ),
      ),
    );
  }
}

class _PricingCard extends ConsumerStatefulWidget {
  const _PricingCard({super.key, required this.row, required this.canEdit});
  final Map<String, dynamic> row;
  final bool canEdit;

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
    final service = widget.row['service_type'] as String;
    final fare = sampleDeliveryFare(data).toStringAsFixed(2);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminPricingConfirmTitle(service)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.adminPricingConfirmSample(fare)),
            const SizedBox(height: 8),
            Text(l10n.adminPricingConfirmNewOnly),
            if (!_active) ...[
              const SizedBox(height: 8),
              Text(l10n.adminPricingConfirmOff),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(deliveryPricingSaverProvider)(service, data);
      if (mounted) {
        for (final f in _fields) {
          _c[f]!.text = '${saved[f] ?? 0}';
        }
        setState(() => _active = saved['is_active'] as bool? ?? _active);
      }
      ref.invalidate(adminDeliveryPricingRowsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminPricingSaved)));
    } on DeliveryPricingNotSavedException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminPricingNotSaved)),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
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
            if (!_active)
              Text(
                l10n.adminPricingDisableWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            for (final f in _fields)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _c[f],
                  enabled: widget.canEdit && !_saving,
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
                onPressed: (widget.canEdit && !_saving) ? _save : null,
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
