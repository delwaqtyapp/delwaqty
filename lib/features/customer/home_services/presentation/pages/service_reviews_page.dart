import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_review.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_review_repository_impl.dart';
import 'package:delwaqty/features/customer/home_services/domain/repositories/service_review_repository.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/rating_stars.dart';
import 'package:delwaqty/shared/widgets/app_snackbar.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';

class ServiceReviewsPage extends ConsumerWidget {
  const ServiceReviewsPage({
    required this.categoryType,
    this.providerId,
    this.providerName,
    super.key,
  });

  final String categoryType;
  final String? providerId;
  final String? providerName;

  ServiceReviewScope get _scope =>
      (categoryType: categoryType, providerId: providerId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = _parseType(categoryType);
    final scope = _scope;
    final summaryAsync = ref.watch(serviceReviewSummaryProvider(scope));
    final myReviewAsync = ref.watch(myServiceReviewProvider(scope));
    final reviewsAsync = ref.watch(serviceReviewsProvider(scope));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.reviews} — ${serviceTypeLabel(type)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (providerName != null)
              Text(
                providerName!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          summaryAsync.when(
            data: (summary) => SummaryCard(summary: summary),
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: AppLoader.circular()),
            ),
            error: (e, _) => ErrorState(
              message: l10n.error,
              onRetry: () =>
                  ref.invalidate(serviceReviewSummaryProvider(scope)),
            ),
          ),
          const SizedBox(height: 16),
          myReviewAsync.when(
            data: (myReview) => _MyReviewCard(
              categoryType: categoryType,
              providerId: providerId,
              myReview: myReview,
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.reviews,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          reviewsAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return _EmptyReviews();
              }
              return Column(
                children: [
                  for (final review in reviews)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReviewCard(review: review),
                    ),
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: AppLoader.circular()),
            ),
            error: (e, _) => ErrorState(
              message: l10n.error,
              onRetry: () => ref.invalidate(serviceReviewsProvider(scope)),
            ),
          ),
        ],
      ),
    );
  }
}

ServiceCategoryType _parseType(String name) {
  for (final type in ServiceCategoryType.values) {
    if (type.name == name) return type;
  }
  return ServiceCategoryType.other;
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({required this.summary, super.key});

  final ServiceReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final maxCount = summary.totalReviews == 0
        ? 1
        : <int>[
            summary.fiveStar,
            summary.fourStar,
            summary.threeStar,
            summary.twoStar,
            summary.oneStar,
          ].reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  summary.totalReviews == 0
                      ? '—'
                      : summary.averageRating.toStringAsFixed(1),
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                RatingStars(rating: summary.averageRating),
                const SizedBox(height: 2),
                Text(
                  l10n.basedOnReviews(summary.totalReviews),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (var stars = 5; stars >= 1; stars--)
                    _buildBar(
                      stars,
                      summary.countFor(stars),
                      maxCount,
                      theme,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(int stars, int count, int maxCount, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$stars',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Icon(Icons.star_rounded, size: 14, color: AppColors.rating),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maxCount == 0 ? 0 : count / maxCount,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: AppColors.rating,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyReviewCard extends ConsumerWidget {
  const _MyReviewCard({
    required this.categoryType,
    required this.providerId,
    required this.myReview,
  });

  final String categoryType;
  final String? providerId;
  final ServiceReview? myReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.yourRating,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (myReview != null)
              Row(
                children: [
                  RatingStars(rating: myReview!.rating, size: 20),
                  const Spacer(),
                  if (myReview!.comment != null &&
                      myReview!.comment!.isNotEmpty)
                    Flexible(
                      child: Text(
                        myReview!.comment!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              )
            else
              Text(l10n.beTheFirst, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: theme.colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => _WriteServiceReviewSheet(
                    categoryType: categoryType,
                    providerId: providerId,
                  ),
                ),
                icon: Icon(
                  myReview != null ? Icons.edit_rounded : Icons.rate_review_rounded,
                ),
                label: Text(myReview != null ? l10n.writeReview : l10n.rateService),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WriteServiceReviewSheet extends ConsumerStatefulWidget {
  const _WriteServiceReviewSheet({
    required this.categoryType,
    this.providerId,
  });

  final String categoryType;
  final String? providerId;

  @override
  ConsumerState<_WriteServiceReviewSheet> createState() =>
      _WriteServiceReviewSheetState();
}

class _WriteServiceReviewSheetState
    extends ConsumerState<_WriteServiceReviewSheet> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.rateService,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              serviceTypeLabel(_parseType(widget.categoryType)),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.yourRating,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      i < _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 36,
                      color: AppColors.rating,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.yourReview,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitReview,
                child: _isSubmitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(l10n.submitReview),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    try {
      final authState = ref.read(authStateProvider);
      final userId = authState is AuthAuthenticated ? authState.user.id : '';
      final userName = authState is AuthAuthenticated
          ? (authState.user.fullName ?? '')
          : '';
      final repo = ref.read(serviceReviewRepositoryProvider);
      final comment = _commentController.text.isNotEmpty
          ? _commentController.text.trim()
          : null;
      await repo.submitServiceReview(
        userId: userId,
        userName: userName,
        categoryType: widget.categoryType,
        providerId: widget.providerId,
        rating: _rating,
        comment: comment,
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final scope = (
          categoryType: widget.categoryType,
          providerId: widget.providerId,
        );
        ref.invalidate(serviceReviewsProvider(scope));
        ref.invalidate(serviceReviewSummaryProvider(scope));
        ref.invalidate(myServiceReviewProvider(scope));
        AppSnackbar.success(context, message: l10n.reviewSubmitted);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          message: AppLocalizations.of(context).error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ServiceReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = review.createdAt;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brandViolet.withValues(alpha: 0.15),
            child: Text(
              review.userName.isEmpty
                  ? '؟'
                  : review.userName.characters.first,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.brandViolet,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                      review.userName.isEmpty
                          ? '—'
                          : review.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (date != null)
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                RatingStars(rating: review.rating, size: 15),
                if (review.comment != null && review.comment!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    review.comment!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noReviewsYet,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.beTheFirst,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}