import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/provider/pricing/presentation/providers/provider_pricing_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Read-only view of the provider's own pricing (migration 397).
/// Rates are admin-managed; this page never offers editing.
class ProviderPricingPage extends ConsumerWidget {
  const ProviderPricingPage({super.key});

  double? _numOrNull(Object? v) => v == null ? null : (v as num).toDouble();

  String _fmt(num? v) =>
      v == null ? '' : v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pricingAsync = ref.watch(providerMyPricingProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.providerMyPricing),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(providerMyPricingProvider),
          ),
        ],
      ),
      body: pricingAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => Center(
          child: PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: l10n.errorLoading,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(providerMyPricingProvider),
          ),
        ),
        data: (data) {
          final items = (data['items'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (items.isEmpty) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.payments_outlined,
                title: l10n.providerMyPricing,
                message: l10n.providerMyPricingEmpty,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimatedFadeIn(
                child: Card(
                  color: scheme.surfaceContainerHighest,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.providerMyPricingAdminNote,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              for (final row in items) _pricingCard(context, row, l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _pricingCard(
    BuildContext context,
    Map<String, dynamic> row,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final categoryName =
        (row['category_name_ar'] as String?)?.isNotEmpty == true
        ? row['category_name_ar'] as String
        : (row['category_name_en'] as String? ??
              (row['category_type'] as String? ?? '').replaceAll('_', ' '));
    final hourly = _numOrNull(row['effective_hourly_rate']);
    final fixedMin = _numOrNull(row['effective_fixed_price_min']);
    final fixedMax = _numOrNull(row['effective_fixed_price_max']);
    final hourlySource = row['hourly_source'] as String?;
    final sourceLabel = switch (hourlySource) {
      'provider' => l10n.providerPricingCustom,
      'category' => l10n.providerPricingCategoryDefault,
      _ => l10n.providerPricingPlatformDefault,
    };

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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      categoryName,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_fmt(hourly)} ${l10n.currencySymbol}/${l10n.perHour}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(sourceLabel, style: Theme.of(context).textTheme.labelSmall),
              if (fixedMin != null || fixedMax != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l10n.providerPricingFixedMin}: ${_fmt(fixedMin)} - ${_fmt(fixedMax)} ${l10n.currencySymbol}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
