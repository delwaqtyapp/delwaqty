import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';

class AdminProviderIntelligencePage extends ConsumerWidget {
  const AdminProviderIntelligencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final intelligenceAsync = ref.watch(providerIntelligenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminProviderIntelligence),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(providerIntelligenceProvider),
          ),
        ],
      ),
      body: intelligenceAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => Center(
          child: PremiumCard(
            child: PremiumEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.error,
              message: l10n.errorLoading,
              actionLabel: l10n.retry,
              onAction: () => ref.invalidate(providerIntelligenceProvider),
            ),
          ),
        ),
        data: (intelligence) => _buildContent(context, intelligence, l10n, cs),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ProviderIntelligence data,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedFadeIn(
            child: _buildSummaryCards(context, data, l10n, cs),
          ),
          const SizedBox(height: 24),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 100),
            child: Text(
              l10n.providersByCategory,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 150),
            child: _buildProvidersByCategory(context, data.providersByCategory, cs),
          ),
          const SizedBox(height: 24),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 200),
            child: Text(
              l10n.bookingsByCategory,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 250),
            child: _buildBookingsByCategory(context, data.bookingsByCategory, cs),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    ProviderIntelligence data,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 3;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            _SummaryCard(
              title: l10n.totalUsers,
              value: data.totalProviders.toString(),
              icon: Icons.people_outline_rounded,
              color: const Color(0xFF4A90D9),
              cs: cs,
            ),
            _SummaryCard(
              title: l10n.verified,
              value: data.verifiedProviders.toString(),
              icon: Icons.verified_outlined,
              color: const Color(0xFF34C759),
              cs: cs,
            ),
            _SummaryCard(
              title: l10n.available,
              value: data.availableProviders.toString(),
              icon: Icons.access_time_rounded,
              color: const Color(0xFFFF9500),
              cs: cs,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProvidersByCategory(
    BuildContext context,
    List<TypeCount> items,
    ColorScheme cs,
  ) {
    if (items.isEmpty) {
      return PremiumCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              AppLocalizations.of(context).noDataAvailable,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return _CategoryChip(
          label: item.type,
          count: item.count,
          cs: cs,
        );
      }).toList(),
    );
  }

  Widget _buildBookingsByCategory(
    BuildContext context,
    List<TypeCount> items,
    ColorScheme cs,
  ) {
    if (items.isEmpty) {
      return PremiumCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              AppLocalizations.of(context).noDataAvailable,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return _CategoryChip(
          label: item.type,
          count: item.count,
          cs: cs,
        );
      }).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.cs,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      radius: AppSpacing.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.cs,
  });

  final String label;
  final int count;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: AppSpacing.radiusCard,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.brandTeal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.brandCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.brandCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
