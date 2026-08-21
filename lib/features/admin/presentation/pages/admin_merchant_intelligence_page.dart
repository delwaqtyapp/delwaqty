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

class AdminMerchantIntelligencePage extends ConsumerWidget {
  const AdminMerchantIntelligencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final intelligenceAsync = ref.watch(merchantIntelligenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminMerchantIntelligence),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(merchantIntelligenceProvider),
          ),
        ],
      ),
      body: intelligenceAsync.when(
        loading: () => const Center(child: AppLoaderCircular(),),
        error: (e, _) => Center(
          child: PremiumCard(
            child: PremiumEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.error,
              message: l10n.errorLoading,
              actionLabel: l10n.retry,
              onAction: () => ref.invalidate(merchantIntelligenceProvider),
            ),
          ),
        ),
        data: (intelligence) => _buildContent(context, intelligence, l10n, cs),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MerchantIntelligence data,
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
              l10n.merchantsByType,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 150),
            child: _buildMerchantsByType(context, data.merchantsByType, cs),
          ),
          const SizedBox(height: 24),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 200),
            child: Text(
              l10n.totalMerchants,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildMerchantList(context, data.merchants, l10n, cs),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    MerchantIntelligence data,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _SummaryCard(
              title: l10n.totalMerchants,
              value: data.totalMerchants.toString(),
              icon: Icons.store_outlined,
              color: const Color(0xFF34C759),
              cs: cs,
            ),
            _SummaryCard(
              title: l10n.active,
              value: data.activeMerchants.toString(),
              icon: Icons.check_circle_outline,
              color: const Color(0xFF007AFF),
              cs: cs,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMerchantsByType(
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
        return _TypeChip(
          label: item.type,
          count: item.count,
          cs: cs,
        );
      }).toList(),
    );
  }

  Widget _buildMerchantList(
    BuildContext context,
    List<MerchantInfo> merchants,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    if (merchants.isEmpty) {
      return AnimatedFadeIn(
        child: PremiumCard(
          child: PremiumEmptyState(
            icon: Icons.store_outlined,
            title: l10n.noDataAvailable,
            message: l10n.noDataAvailable,
          ),
        ),
      );
    }
    return Column(
      children: List.generate(merchants.length, (index) {
        final merchant = merchants[index];
        return AnimatedFadeIn(
          delay: Duration(milliseconds: 250 + index * 50),
          child: Padding(
            padding: EdgeInsets.only(bottom: index < merchants.length - 1 ? 8 : 0),
            child: _MerchantInfoTile(
              merchant: merchant,
              l10n: l10n,
              cs: cs,
            ),
          ),
        );
      }),
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
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
            decoration: const BoxDecoration(
              color: AppColors.brandPurple,
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
              color: AppColors.brandLavender,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.brandPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantInfoTile extends StatelessWidget {
  const _MerchantInfoTile({
    required this.merchant,
    required this.l10n,
    required this.cs,
  });

  final MerchantInfo merchant;
  final AppLocalizations l10n;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isActive = merchant.status == 'active' || merchant.status == 'verified';
    final statusColor = isActive ? AppColors.successLight : AppColors.warningLight;
    final stars = merchant.rating.round().clamp(0, 5);

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: AppSpacing.radiusCard,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.store_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.brandLavender,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        merchant.type,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.brandPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        merchant.status,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 14,
                    color: AppColors.rating,
                  );
                }),
              ),
              const SizedBox(height: 2),
              Text(
                '${merchant.totalOrders} ${l10n.orders}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
