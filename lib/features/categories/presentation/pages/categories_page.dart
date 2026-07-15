import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/utils/icon_mapper.dart';
import 'package:delwaqty/data/providers.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/shared/widgets/loading_skeleton.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categories),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/categories/add'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
        },
        child: categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return EmptyState(
                icon: Icons.category_rounded,
                title: l10n.noCategories,
                message: l10n.noCategoriesMessage,
                actionLabel: l10n.addCategory,
                onAction: () => context.push('/categories/add'),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryCard(
                  category: category,
                  onTap: () => context.push('/categories/add', extra: category),
                );
              },
            );
          },
          loading: () => GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: 6,
            itemBuilder: (_, __) => const SkeletonCard(height: 140),
          ),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: e.toString(),
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(categoriesProvider),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/categories/add'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final iconData = categoryIconFromName(category.icon);
    final progress = category.budget > 0
        ? (category.spent / category.budget).clamp(0.0, 1.0)
        : 0.0;
    final remaining = category.budget - category.spent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, size: 22, color: category.categoryColor),
            ),
            const SizedBox(height: 10),
            Text(
              category.name,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (category.budget > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: progress > 0.9
                      ? colorScheme.error
                      : category.categoryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '\$${category.spent.toStringAsFixed(0)} / \$${category.budget.toStringAsFixed(0)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              Text(
                '\$${category.spent.toStringAsFixed(0)}',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: category.categoryColor,
                ),
              ),
            const Spacer(),
            if (category.budget > 0)
              Text(
                '${remaining >= 0 ? l10n.remaining : l10n.overBudget}: \$${remaining.abs().toStringAsFixed(0)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: remaining >= 0 ? Colors.green : colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
