import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/merchant/merchant_module.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/review.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

final _merchantIdProvider = Provider<String>((_) => 'current-merchant-id');

final _reviewsProvider = FutureProvider<List<Review>>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  return repo.getMerchantReviews(merchantId);
});

final _reviewSummaryProvider = FutureProvider<ReviewSummary>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  return repo.getMerchantRatingSummary(merchantId);
});

class MerchantReviewsPage extends ConsumerStatefulWidget {
  const MerchantReviewsPage({super.key});

  @override
  ConsumerState<MerchantReviewsPage> createState() =>
      _MerchantReviewsPageState();
}

class _MerchantReviewsPageState extends ConsumerState<MerchantReviewsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reviewsAsync = ref.watch(_reviewsProvider);
    final summaryAsync = ref.watch(_reviewSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviews),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_reviewsProvider);
              ref.invalidate(_reviewSummaryProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          summaryAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (summary) => _RatingSummaryCard(summary: summary),
          ),
          Expanded(
            child: reviewsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ShimmerCard(height: 140),
                ),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_reviewsProvider),
                ),
              ),
              data: (reviews) {
                if (reviews.isEmpty) {
                  return Center(
                    child: PremiumEmptyState(
                      icon: Icons.rate_review_outlined,
                      title: l10n.noReviewsYet,
                      message: l10n.beTheFirst,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(_reviewsProvider);
                    ref.invalidate(_reviewSummaryProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _ReviewCard(
                          review: review,
                          onReply: (reply) => _saveReply(review, reply),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReply(Review review, String reply) async {
    final repo = ref.read(reviewRepositoryProvider);
    await repo.updateReview(reviewId: review.id, comment: reply);
    ref.invalidate(_reviewsProvider);
    if (mounted) {
      context.showAppSnackBar('Reply saved');
    }
  }
}

class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final total = summary.totalReviews;
    final distribution = [
      summary.fiveStarCount,
      summary.fourStarCount,
      summary.threeStarCount,
      summary.twoStarCount,
      summary.oneStarCount,
    ];
    final maxCount = distribution.isEmpty
        ? 1
        : distribution.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ratingBreakdown,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  summary.averageRating.toStringAsFixed(1),
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.rating,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (i) {
                        final starIndex = 5 - i;
                        return Icon(
                          starIndex <= summary.averageRating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.rating,
                          size: 20,
                        );
                      }),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.basedOnReviews(total),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ...List.generate(5, (i) {
              final stars = 5 - i;
              final count = distribution[i];
              final fraction = maxCount > 0 ? count / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text(
                        '$stars',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    Icon(Icons.star_rounded, size: 14, color: AppColors.rating),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        child: LinearProgressIndicator(
                          value: fraction.toDouble(),
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.rating,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    required this.review,
    required this.onReply,
  });

  final Review review;
  final Function(String) onReply;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late final TextEditingController _replyController;
  bool _showReplyField = false;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(text: widget.review.comment);
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final date = widget.review.createdAt;
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (widget.review.userName ?? 'U')[0].toUpperCase(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.review.userName ?? 'User',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < widget.review.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.rating,
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
            if (widget.review.comment != null &&
                widget.review.comment!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.review.comment!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (!_showReplyField)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showReplyField = true),
                  icon: const Icon(Icons.reply, size: 16),
                  label: Text(
                    'Reply',
                    style: AppTextStyles.labelMedium,
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _showReplyField = false),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.tonal(
                        onPressed: () {
                          widget.onReply(_replyController.text.trim());
                          setState(() => _showReplyField = false);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
