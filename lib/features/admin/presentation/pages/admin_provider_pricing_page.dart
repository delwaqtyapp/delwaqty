import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Admin editor for home-service provider pricing (migration 397).
/// Provider custom rates and platform-wide category defaults. Writes go
/// through scoped RPCs; the server enforces region scope and audit logging.
class AdminProviderPricingPage extends ConsumerStatefulWidget {
  const AdminProviderPricingPage({super.key});

  @override
  ConsumerState<AdminProviderPricingPage> createState() =>
      _AdminProviderPricingPageState();
}

class _AdminProviderPricingPageState
    extends ConsumerState<AdminProviderPricingPage> {
  String _search = '';
  String? _category;
  bool _saving = false;

  double? _numOrNull(Object? v) => v == null ? null : (v as num).toDouble();

  String _fmt(num? v) =>
      v == null ? '' : v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  String _sourceLabel(AppLocalizations l10n, String? source) {
    switch (source) {
      case 'provider':
        return l10n.providerPricingCustom;
      case 'category':
        return l10n.providerPricingCategoryDefault;
      default:
        return l10n.providerPricingPlatformDefault;
    }
  }

  String _categoryLabel(Map<String, dynamic> row, AppLocalizations l10n) {
    final ar = row['category_name_ar'] as String?;
    if (ar != null && ar.isNotEmpty) return ar;
    return (row['category_type'] as String? ?? '').replaceAll('_', ' ');
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
      if (mounted) {
        ref.invalidate(providerPricingProvider);
        ref.invalidate(categoryPricingProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.providerPricingSaved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.providerPricingFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Map<String, String?>?> _pricingDialog({
    required String title,
    double? hourly,
    double? fixedMin,
    double? fixedMax,
  }) {
    final l10n = AppLocalizations.of(context);
    final hourlyController = TextEditingController(text: _fmt(hourly));
    final minController = TextEditingController(text: _fmt(fixedMin));
    final maxController = TextEditingController(text: _fmt(fixedMax));
    final noteController = TextEditingController();

    InputDecoration fieldDecoration(String label) => InputDecoration(
      labelText: label,
      hintText: l10n.providerPricingLeaveEmpty,
      suffixText: l10n.currencySymbol,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    );

    return showDialog<Map<String, String?>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hourlyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: fieldDecoration(l10n.providerPricingHourly),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: fieldDecoration(l10n.providerPricingFixedMin),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: fieldDecoration(l10n.providerPricingFixedMax),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: l10n.providerPricingNote,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.d20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop({
              'hourly': hourlyController.text.trim(),
              'fixed_min': minController.text.trim(),
              'fixed_max': maxController.text.trim(),
              'note': noteController.text.trim(),
            }),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  double? _parseRate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool _validRates(double? hourly, double? min, double? max) {
    if (hourly != null && (hourly < 0 || hourly > 10000)) return false;
    if (min != null && (min < 0 || min > 100000)) return false;
    if (max != null && (max < 0 || max > 100000)) return false;
    if (min != null && max != null && min > max) return false;
    return true;
  }

  Future<void> _editProvider(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final result = await _pricingDialog(
      title: '${l10n.providerPricingEditTitle}: ${row['name'] ?? ''}',
      hourly: _numOrNull(row['hourly_rate']),
      fixedMin: _numOrNull(row['fixed_price_min']),
      fixedMax: _numOrNull(row['fixed_price_max']),
    );
    if (result == null || !mounted) return;
    final hourly = _parseRate(result['hourly']);
    final min = _parseRate(result['fixed_min']);
    final max = _parseRate(result['fixed_max']);
    // Blank means "clear this override"; a non-blank value that does not
    // parse is an input error, not a clear.
    final invalid = [
      result['hourly'],
      result['fixed_min'],
      result['fixed_max'],
    ].any((v) => v != null && v.isNotEmpty && double.tryParse(v) == null);
    if (invalid || !_validRates(hourly, min, max)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.providerPricingInvalidInput)));
      return;
    }
    // Explicit intended triple: blank fields are cleared via p_clear_fields
    // so a partial edit never wipes its siblings server-side.
    final clearFields = <String>[
      if ((result['hourly'] ?? '').isEmpty) 'hourly_rate',
      if ((result['fixed_min'] ?? '').isEmpty) 'fixed_price_min',
      if ((result['fixed_max'] ?? '').isEmpty) 'fixed_price_max',
    ];
    await _save(() async {
      final client = ref.read(supabaseClientProvider);
      await client.rpc(
        'admin_set_provider_pricing',
        params: {
          'p_provider_id': row['provider_id'],
          'p_hourly_rate': hourly,
          'p_fixed_price_min': min,
          'p_fixed_price_max': max,
          'p_clear_fields': clearFields,
          'p_note': (result['note']?.isEmpty ?? true) ? null : result['note'],
        },
      );
    });
  }

  Future<void> _editCategory(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final result = await _pricingDialog(
      title:
          '${l10n.providerPricingEditTitle}: ${row['name_ar'] ?? row['name_en'] ?? row['category_type']}',
      hourly: _numOrNull(row['hourly_rate']),
      fixedMin: _numOrNull(row['fixed_price_min']),
      fixedMax: _numOrNull(row['fixed_price_max']),
    );
    if (result == null || !mounted) return;
    final hourly = _parseRate(result['hourly']);
    final min = _parseRate(result['fixed_min']);
    final max = _parseRate(result['fixed_max']);
    if (!_validRates(hourly, min, max)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.providerPricingFailed)));
      return;
    }
    await _save(() async {
      final client = ref.read(supabaseClientProvider);
      await client.rpc(
        'admin_set_category_pricing',
        params: {
          'p_category_type': row['category_type'],
          'p_hourly_rate': hourly,
          'p_fixed_price_min': min,
          'p_fixed_price_max': max,
          'p_note': (result['note']?.isEmpty ?? true) ? null : result['note'],
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminProviderPricing),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.providerPricingTabProviders),
              Tab(text: l10n.providerPricingTabCategories),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l10n.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(providerPricingProvider);
                ref.invalidate(categoryPricingProvider);
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [_buildProvidersTab(l10n), _buildCategoriesTab(l10n)],
        ),
      ),
    );
  }

  Widget _buildProvidersTab(AppLocalizations l10n) {
    final categoriesAsync = ref.watch(categoryPricingProvider);
    final providersAsync = ref.watch(
      providerPricingProvider((
        search: _search.isEmpty ? null : _search,
        category: _category,
      )),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.providerPricingSearchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
        ),
        categoriesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (data) {
            final items = (data['items'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (items.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: DropdownButtonFormField<String?>(
                initialValue: _category,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.providerPricingAllCategories),
                  ),
                  for (final c in items)
                    DropdownMenuItem<String?>(
                      value: c['category_type'] as String?,
                      child: Text(
                        (c['name_ar'] as String?)?.isNotEmpty == true
                            ? c['name_ar'] as String
                            : (c['name_en'] as String? ??
                                  c['category_type'] as String),
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
            );
          },
        ),
        Expanded(
          child: providersAsync.when(
            loading: () => const Center(child: AppLoaderCircular()),
            error: (e, _) => Center(
              child: PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.error,
                message: l10n.errorLoading,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(providerPricingProvider),
              ),
            ),
            data: (data) {
              final items = (data['items'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
              if (items.isEmpty) {
                return Center(
                  child: PremiumEmptyState(
                    icon: Icons.handyman_outlined,
                    title: l10n.adminProviderPricing,
                    message: l10n.providerPricingEmpty,
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) => _providerTile(items[i], l10n),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _providerTile(Map<String, dynamic> row, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveHourly = _numOrNull(row['effective_hourly_rate']);
    final fixedMin = _numOrNull(row['effective_fixed_price_min']);
    final fixedMax = _numOrNull(row['effective_fixed_price_max']);
    final region = row['region_label'] as String?;

    return AnimatedFadeIn(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row['name'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      _categoryLabel(row, l10n),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              if (region != null && region.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    region,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_fmt(effectiveHourly)} ${l10n.currencySymbol}${l10n.perHour}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          _sourceLabel(l10n, row['hourly_source'] as String?),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (fixedMin != null || fixedMax != null)
                          Text(
                            '${_fmt(fixedMin)} - ${_fmt(fixedMax)} ${l10n.currencySymbol}',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else
                          Text(
                            l10n.providerPricingNoFixed,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.providerPricingEditTitle,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.edit_outlined, color: scheme.primary),
                    onPressed: _saving ? null : () => _editProvider(row),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesTab(AppLocalizations l10n) {
    final categoriesAsync = ref.watch(categoryPricingProvider);
    return categoriesAsync.when(
      loading: () => const Center(child: AppLoaderCircular()),
      error: (e, _) => Center(
        child: PremiumEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.error,
          message: l10n.errorLoading,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(categoryPricingProvider),
        ),
      ),
      data: (data) {
        final canEdit = data['can_edit'] == true;
        final items = (data['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!canEdit)
              AnimatedFadeIn(
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.providerPricingReadOnlyHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            for (final row in items) _categoryTile(row, l10n, canEdit),
          ],
        );
      },
    );
  }

  Widget _categoryTile(
    Map<String, dynamic> row,
    AppLocalizations l10n,
    bool canEdit,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final hourly = _numOrNull(row['hourly_rate']);
    final fixedMin = _numOrNull(row['fixed_price_min']);
    final fixedMax = _numOrNull(row['fixed_price_max']);
    final name = (row['name_ar'] as String?)?.isNotEmpty == true
        ? row['name_ar'] as String
        : (row['name_en'] as String? ?? row['category_type'] as String);

    return AnimatedFadeIn(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            hourly != null
                ? '${_fmt(hourly)} ${l10n.currencySymbol}${l10n.perHour}'
                : l10n.providerPricingPlatformDefault,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fixedMin != null || fixedMax != null)
                Text(
                  '${_fmt(fixedMin)} - ${_fmt(fixedMax)} ${l10n.currencySymbol}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              IconButton(
                tooltip: l10n.providerPricingEditTitle,
                icon: Icon(
                  canEdit ? Icons.edit_outlined : Icons.lock_outline,
                  color: canEdit ? scheme.primary : scheme.outline,
                ),
                onPressed: canEdit && !_saving
                    ? () => _editCategory(row)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
