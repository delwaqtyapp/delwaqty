import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class AdminReviewsModerationPage extends ConsumerWidget {
  const AdminReviewsModerationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminReviewsModeration),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.merchantReviews),
              Tab(text: l10n.serviceReviews),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(adminMerchantReviewsProvider);
                ref.invalidate(adminServiceReviewsProvider);
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ReviewsList(
              provider: adminMerchantReviewsProvider,
              onDelete: (id) => ref.read(adminServiceProvider).deleteMerchantReview(id),
              emptyIcon: Icons.storefront_outlined,
              titleOf: (r) => [
                '${(r['rating'] as num?)?.toInt() ?? 0} ★',
                if ((r['comment'] as String?)?.trim().isNotEmpty == true)
                  r['comment'] as String
                else
                  l10n.noComment,
              ],
              l10n: l10n,
            ),
            _ReviewsList(
              provider: adminServiceReviewsProvider,
              onDelete: (id) => ref.read(adminServiceProvider).deleteServiceReview(id),
              emptyIcon: Icons.rate_review_outlined,
              titleOf: (r) => [
                '${(r['rating'] as num?)?.toInt() ?? 0} ★ — ${r['category_type']}',
                r['user_name'] as String? ?? '',
                if ((r['comment'] as String?)?.trim().isNotEmpty == true)
                  r['comment'] as String
                else
                  l10n.noComment,
              ],
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsList extends ConsumerWidget {
  const _ReviewsList({
    required this.provider,
    required this.onDelete,
    required this.emptyIcon,
    required this.titleOf,
    required this.l10n,
  });

  final FutureProvider<List<Map<String, dynamic>>> provider;
  final Future<bool> Function(String id) onDelete;
  final IconData emptyIcon;
  final List<String> Function(Map<String, dynamic> review) titleOf;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: async.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => Center(
          child: PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: l10n.errorLoading,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(provider),
          ),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 300,
                  child: PremiumEmptyState(
                    icon: emptyIcon,
                    title: l10n.noReviewsYet,
                    message: l10n.noReviewsYet,
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              final lines = titleOf(review);
              return AnimatedFadeIn(
                delay: Duration(milliseconds: (index % 10) * 40),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.rating,
                      child: Icon(Icons.star_rounded,
                          color: Colors.white, size: 20),
                    ),
                    title: Text(
                      lines.first,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in lines.skip(1))
                          if (line.isNotEmpty)
                            Text(
                              line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ),
                    isThreeLine: lines.length > 2,
                    trailing: IconButton(
                      tooltip: l10n.deleteReviewAction,
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () => _confirmDelete(context, ref, review['id'] as String),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteReviewAction),
        content: Text(l10n.confirmDeleteReview),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final deleted = await onDelete(id);
    ref.invalidate(provider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(deleted ? l10n.deleted : l10n.deleteFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}