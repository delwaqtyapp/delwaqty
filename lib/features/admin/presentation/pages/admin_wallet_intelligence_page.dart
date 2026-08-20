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

class AdminWalletIntelligencePage extends ConsumerWidget {
  const AdminWalletIntelligencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final intelligenceAsync = ref.watch(walletIntelligenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminWalletIntelligence),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(walletIntelligenceProvider),
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
              onAction: () => ref.invalidate(walletIntelligenceProvider),
            ),
          ),
        ),
        data: (intelligence) => _buildContent(context, intelligence, l10n, cs),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WalletIntelligence data,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedFadeIn(
            child: _buildWalletStats(context, data, l10n, cs),
          ),
          const SizedBox(height: 24),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 100),
            child: Text(
              l10n.transactions,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 150),
            child: _buildTransactionsByType(context, data.transactionsByType, l10n, cs),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletStats(
    BuildContext context,
    WalletIntelligence data,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
            ? 4
            : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            _SummaryCard(
              title: l10n.wallet,
              value: data.walletCount.toString(),
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFFAF52DE),
              cs: cs,
            ),
            _SummaryCard(
              title: l10n.transactions,
              value: data.totalTransactions.toString(),
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF4A90D9),
              cs: cs,
            ),
            _SummaryCard(
              title: l10n.totalLiability,
              value: '${l10n.currencySymbol} ${data.totalLiability.toStringAsFixed(0)}',
              icon: Icons.account_balance_outlined,
              color: const Color(0xFFFF3B30),
              cs: cs,
            ),
            _SummaryCard(
              title: l10n.availableBalance,
              value: '${l10n.currencySymbol} ${data.avgBalance.toStringAsFixed(0)}',
              icon: Icons.savings_outlined,
              color: const Color(0xFF34C759),
              cs: cs,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionsByType(
    BuildContext context,
    List<TypeCount> items,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    if (items.isEmpty) {
      return AnimatedFadeIn(
        child: PremiumCard(
          child: PremiumEmptyState(
            icon: Icons.receipt_long_rounded,
            title: l10n.noDataAvailable,
            message: l10n.noDataAvailable,
          ),
        ),
      );
    }
    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return AnimatedFadeIn(
          delay: Duration(milliseconds: 200 + index * 50),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index < items.length - 1 ? 8 : 0,
            ),
            child: _TransactionTypeTile(
              type: item.type,
              count: item.count,
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

class _TransactionTypeTile extends StatelessWidget {
  const _TransactionTypeTile({
    required this.type,
    required this.count,
    required this.l10n,
    required this.cs,
  });

  final String type;
  final int count;
  final AppLocalizations l10n;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: AppSpacing.radiusCard,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brandPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: AppColors.brandPurple,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.brandLavender,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.labelMedium.copyWith(
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
