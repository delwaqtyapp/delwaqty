import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/review.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/app_snackbar.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

final _reviewsProvider = FutureProvider.family<List<Review>, String>((ref, merchantId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getMerchantReviews(merchantId);
});

final _summaryProvider = FutureProvider.family<ReviewSummary, String>((ref, merchantId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getMerchantRatingSummary(merchantId);
});

class RestaurantReviewsPage extends ConsumerWidget {
  const RestaurantReviewsPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(_reviewsProvider(merchantId));
    final summaryAsync = ref.watch(_summaryProvider(merchantId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviews)),
      body: Column(
        children: [
          summaryAsync.when(
            data: (summary) => _RatingSummary(summary: summary),
            loading: () => const SizedBox(height: 120, child: ShimmerCard()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(),
          Expanded(
            child: reviewsAsync.when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return Center(
                    child: PremiumEmptyState(
                      icon: Icons.reviews_outlined,
                      title: l10n.noReviewsYet,
                      message: l10n.beTheFirst,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(_reviewsProvider(merchantId));
                    ref.invalidate(_summaryProvider(merchantId));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 60),
                        child: _ReviewTile(review: review),
                      );
                    },
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ShimmerCard(height: 80),
                ),
              ),
              error: (_, __) => Center(
                child: ErrorState(message: l10n.errorLoading),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWriteReviewSheet(context),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.writeReview),
      ),
    );
  }

  void _showWriteReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WriteReviewSheet(merchantId: merchantId),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                summary.averageRating.toStringAsFixed(1),
                style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < summary.averageRating.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                    color: Colors.amber,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.basedOnReviews(summary.totalReviews.toString()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _RatingBar(label: '5', count: summary.fiveStarCount, total: summary.totalReviews),
                _RatingBar(label: '4', count: summary.fourStarCount, total: summary.totalReviews),
                _RatingBar(label: '3', count: summary.threeStarCount, total: summary.totalReviews),
                _RatingBar(label: '2', count: summary.twoStarCount, total: summary.totalReviews),
                _RatingBar(label: '1', count: summary.oneStarCount, total: summary.totalReviews),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.label, required this.count, required this.total});

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  count > 0 ? Colors.amber : theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 20,
            child: Text(
              count.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  (review.userName ?? 'U').substring(0, 1).toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName ?? 'User',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < review.rating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 14,
                          color: Colors.amber,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              if (review.createdAt != null)
                Text(
                  _formatDate(review.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 30) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({required this.merchantId});

  final String merchantId;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  double _rating = 5;
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.writeReview,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(l10n.yourRating, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = (i + 1).toDouble()),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < _rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 36,
                    color: Colors.amber,
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
              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.submitReview),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(reviewRepositoryProvider);
      await repo.submitReview(
        merchantId: widget.merchantId,
        userId: '',
        rating: _rating,
        comment: _commentController.text.isNotEmpty ? _commentController.text : null,
      );
      if (mounted) {
        ref.invalidate(_reviewsProvider(widget.merchantId));
        ref.invalidate(_summaryProvider(widget.merchantId));
        AppSnackbar.success(context, message: AppLocalizations.of(context).reviewSubmitted);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, message: AppLocalizations.of(context).error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
