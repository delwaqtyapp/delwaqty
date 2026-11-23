import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/services/domain/provider_service_info.dart';
import 'package:delwaqty/features/provider/services/presentation/providers/provider_service_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

/// "My services and prices" for home services, teachers and doctors.
/// Read only: prices are set by the admin team.
class ProviderServicesPage extends ConsumerWidget {
  const ProviderServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(providerProfileProvider);
    final async = ref.watch(providerServiceInfoProvider);
    String t(ProviderLabel k) => profile.label(k, l10n);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t(ProviderLabel.myServicesTitle)),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(providerServiceInfoProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [ShimmerCard(), SizedBox(height: 12), ShimmerCard()],
        ),
        error: (e, _) => Center(
          child: PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: l10n.errorLoading,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(providerServiceInfoProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.handyman_outlined,
                title: t(ProviderLabel.myServicesTitle),
                message: t(ProviderLabel.emptyServices),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              kBottomNavigationBarHeight + 72,
            ),
            children: [
              _InfoBanner(text: l10n.provPricesAdminManaged),
              const SizedBox(height: AppSpacing.md),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ServiceInfoCard(item: item, l10n: l10n),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusServiceCard),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: cs.onSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// One service row with its admin-managed prices.
class ServiceInfoCard extends StatelessWidget {
  const ServiceInfoCard({super.key, required this.item, required this.l10n});

  final ProviderServiceInfo item;
  final AppLocalizations l10n;

  String _money(double v) {
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '$s ${l10n.egp}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = <(String, String)>[
      if (item.hourlyRate != null)
        (l10n.provHourlyRate, _money(item.hourlyRate!)),
      if (item.fixedPriceMin != null || item.fixedPriceMax != null)
        (
          l10n.provFixedPrice,
          [
            if (item.fixedPriceMin != null) _money(item.fixedPriceMin!),
            if (item.fixedPriceMax != null) _money(item.fixedPriceMax!),
          ].join(' - '),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.d20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name.isEmpty ? item.categoryType : item.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (item.isAvailable ? Colors.green : Colors.grey)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.d20),
                ),
                child: Text(
                  item.isAvailable ? l10n.available : l10n.unavailable,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.description, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              l10n.provPriceNotSet,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(r.$1, style: theme.textTheme.bodyMedium),
                    Text(
                      r.$2,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in item.tags)
                  Chip(
                    label: Text(tag, style: theme.textTheme.labelSmall),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
