import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/utils/icon_mapper.dart';
import 'package:delwaqty/data/providers.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/shared/widgets/stat_card.dart';
import 'package:delwaqty/shared/widgets/section_header.dart';
import 'package:delwaqty/shared/widgets/loading_skeleton.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final totalAsync = ref.watch(totalExpensesProvider);
    final byCategoryAsync = ref.watch(expensesByCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(totalExpensesProvider);
          ref.invalidate(expensesByCategoryProvider);
          ref.invalidate(categoriesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.reports,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: totalAsync.when(
                  data: (total) => _buildSummaryCards(
                    context,
                    total,
                    l10n,
                    categoriesAsync.valueOrNull?.length ?? 0,
                  ),
                  loading: () => _buildLoadingCards(context),
                  error: (e, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.categoryBreakdown,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            _CategoryBreakdownSection(
              byCategoryAsync: byCategoryAsync,
              categoriesAsync: categoriesAsync,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: SectionHeader(title: l10n.monthlyTrend),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MonthlyTrendPlaceholder(
                  totalAsync: totalAsync,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    double totalExpenses,
    AppLocalizations l10n,
    int categoryCount,
  ) {
    const totalIncome = 5000.0;
    final balance = totalIncome - totalExpenses;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        StatCard(
          title: l10n.totalIncome,
          value: '\$${totalIncome.toStringAsFixed(2)}',
          icon: Icons.arrow_downward_rounded,
          color: Colors.green,
        ),
        StatCard(
          title: l10n.totalExpenses,
          value: '\$${totalExpenses.toStringAsFixed(2)}',
          icon: Icons.arrow_upward_rounded,
          color: context.colorScheme.error,
        ),
        StatCard(
          title: l10n.balance,
          value: '\$${balance.toStringAsFixed(2)}',
          icon: Icons.account_balance_wallet_rounded,
          color: balance >= 0 ? Colors.green : context.colorScheme.error,
        ),
        StatCard(
          title: l10n.categories,
          value: '$categoryCount',
          icon: Icons.category_rounded,
        ),
      ],
    );
  }

  Widget _buildLoadingCards(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 100)),
            SizedBox(width: 12),
            Expanded(child: SkeletonCard(height: 100)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 100)),
            SizedBox(width: 12),
            Expanded(child: SkeletonCard(height: 100)),
          ],
        ),
      ],
    );
  }
}

class _CategoryBreakdownSection extends StatelessWidget {
  const _CategoryBreakdownSection({
    required this.byCategoryAsync,
    required this.categoriesAsync,
  });

  final AsyncValue<Map<String, double>> byCategoryAsync;
  final AsyncValue<List<Category>> categoriesAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return byCategoryAsync.when(
      data: (byCategory) {
        if (byCategory.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EmptyState(
                icon: Icons.pie_chart_outline_rounded,
                title: l10n.noExpensesYet,
                message: l10n.startTracking,
              ),
            ),
          );
        }

        final categories = categoriesAsync.valueOrNull ?? [];
        final total = byCategory.values.fold<double>(0, (a, b) => a + b);
        final sorted = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = sorted[index];
                final cat = categories.where((c) => c.id == entry.key);
                final category =
                    cat.isNotEmpty ? cat.first : null;
                final ratio = total > 0 ? entry.value / total : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (category != null) ...[
                            Icon(
                              categoryIconFromName(category.icon),
                              size: 18,
                              color: category.categoryColor,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              category?.name ?? entry.key,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '\$${entry.value.toStringAsFixed(2)}',
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(ratio * 100).toStringAsFixed(0)}%',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor:
                              context.colorScheme.surfaceContainerHighest,
                          color: category?.categoryColor ??
                              context.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: sorted.length,
            ),
          ),
        );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, __) => const SkeletonCard(height: 60),
            childCount: 4,
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: e.toString(),
          ),
        ),
      ),
    );
  }
}

class _MonthlyTrendPlaceholder extends StatelessWidget {
  const _MonthlyTrendPlaceholder({required this.totalAsync});

  final AsyncValue<double> totalAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = totalAsync.valueOrNull ?? 0;

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final values = [
      total * 0.7,
      total * 0.85,
      total * 0.6,
      total * 0.95,
      total * 0.8,
      total,
    ];
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.last6Months,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(months.length, (i) {
                final fraction = maxVal > 0 ? values[i] / maxVal : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '\$${(values[i] / 1000).toStringAsFixed(1)}k',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 100 * fraction,
                          decoration: BoxDecoration(
                            color: context.colorScheme.primary
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          months[i],
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
