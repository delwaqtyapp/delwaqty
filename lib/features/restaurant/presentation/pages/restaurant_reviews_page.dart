import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/review.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/app_snackbar.dart';
import 'package:delwaqty/shared/widgets/skeleton_loader.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class ReviewsState {
  final List<Review> reviews;
  final bool hasMore;
  final bool isLoadingMore;
  final int offset;

  const ReviewsState({
    this.reviews = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.offset = 0,
  });

  ReviewsState copyWith({
    List<Review>? reviews,
    bool? hasMore,
    bool? isLoadingMore,
    int? offset,
  }) {
    return ReviewsState(
      reviews: reviews ?? this.reviews,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      offset: offset ?? this.offset,
    );
  }
}

class RestaurantReviewsNotifier extends AutoDisposeFamilyAsyncNotifier<ReviewsState, String> {
  static const _limit = 10;

  @override
  FutureOr<ReviewsState> build(String merchantId) async {
    final repo = ref.watch(reviewRepositoryProvider);
    final reviews = await repo.getMerchantReviews(
      merchantId,
      limit: _limit,
      offset: 0,
    );
    return ReviewsState(
      reviews: reviews,
      hasMore: reviews.length >= _limit,
      offset: reviews.length,
    );
  }

  Future<void> loadNextPage() async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.isLoadingMore || !currentState.hasMore) return;

    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final repo = ref.read(reviewRepositoryProvider);
      final reviews = await repo.getMerchantReviews(
        arg,
        limit: _limit,
        offset: currentState.offset,
      );

      final newReviews = [...currentState.reviews, ...reviews];
      state = AsyncValue.data(currentState.copyWith(
        reviews: newReviews,
        hasMore: reviews.length >= _limit,
        isLoadingMore: false,
        offset: currentState.offset + reviews.length,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final restaurantReviewsProvider = AsyncNotifierProvider.autoDispose.family<RestaurantReviewsNotifier, ReviewsState, String>(
  RestaurantReviewsNotifier.new,
);

final _summaryProvider = FutureProvider.family<ReviewSummary, String>((ref, merchantId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getMerchantRatingSummary(merchantId);
});

class RestaurantReviewsPage extends ConsumerStatefulWidget {
  const RestaurantReviewsPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  ConsumerState<RestaurantReviewsPage> createState() => _RestaurantReviewsPageState();
}

class _RestaurantReviewsPageState extends ConsumerState<RestaurantReviewsPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(restaurantReviewsProvider(widget.merchantId).notifier).loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reviewsAsync = ref.watch(restaurantReviewsProvider(widget.merchantId));
    final summaryAsync = ref.watch(_summaryProvider(widget.merchantId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviews)),
      body: Column(
        children: [
          summaryAsync.when(
            data: (summary) => _RatingSummary(summary: summary),
            loading: () => const SkeletonListTile(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(),
          Expanded(
            child: reviewsAsync.when(
              data: (reviewsState) {
                final reviews = reviewsState.reviews;
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
                    ref.invalidate(restaurantReviewsProvider(widget.merchantId));
                    ref.invalidate(_summaryProvider(widget.merchantId));
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: reviews.length + (reviewsState.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == reviews.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final review = reviews[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 60),
                        child: _ReviewTile(review: review),
                      );
                    },
                  ),
                );
              },
              loading: () => const RestaurantReviewsSkeleton(),
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
      backgroundColor: Colors.transparent,
      builder: (context) => _WriteReviewSheet(merchantId: widget.merchantId),
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
                    color: AppColors.rating,
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
                  count > 0 ? AppColors.rating : theme.colorScheme.surfaceContainerHighest,
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
    final l10n = AppLocalizations.of(context);

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
                      review.userName ?? l10n.user,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < review.rating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 14,
                          color: AppColors.rating,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              if (review.createdAt != null)
                Flexible(
                  child: Text(
                    _formatDate(review.createdAt!, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
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

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 30) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return l10n.daysAgo(diff.inDays);
    if (diff.inHours > 0) return l10n.hoursAgo(diff.inHours);
    if (diff.inMinutes > 0) return l10n.minutesAgo(diff.inMinutes);
    return l10n.justNow;
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
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
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
      final repo = ref.read(reviewRepositoryProvider);
      await repo.submitReview(
        merchantId: widget.merchantId,
        userId: '',
        rating: _rating,
        comment: _commentController.text.isNotEmpty ? _commentController.text : null,
      );
      if (mounted) {
        ref.invalidate(restaurantReviewsProvider(widget.merchantId));
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
