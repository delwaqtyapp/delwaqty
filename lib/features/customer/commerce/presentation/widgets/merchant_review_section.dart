import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';

/// A review can be submitted once a star rating (1-5) is chosen and no
/// submission is in flight.
bool canSubmitReview({required int rating, required bool submitting}) =>
    !submitting && rating >= 1 && rating <= 5;

/// Post-delivery merchant review card on the order tracking page: stars plus
/// an optional written comment, submitted against the order's merchant.
/// (DriverRatingSection rates the delivery; this rates the food/store.)
class MerchantReviewSection extends ConsumerStatefulWidget {
  const MerchantReviewSection({
    super.key,
    required this.orderId,
    required this.merchantId,
  });

  final String orderId;
  final String merchantId;

  @override
  ConsumerState<MerchantReviewSection> createState() =>
      _MerchantReviewSectionState();
}

class _MerchantReviewSectionState extends ConsumerState<MerchantReviewSection> {
  int _rating = 0;
  bool _submitting = false;
  bool _submitted = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!canSubmitReview(rating: _rating, submitting: _submitting)) return;
    final auth = ref.read(authStateProvider);
    final userId = auth is AuthAuthenticated ? auth.user.id : null;
    if (userId == null) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(reviewRepositoryProvider)
          .submitReview(
            merchantId: widget.merchantId,
            userId: userId,
            orderId: widget.orderId,
            rating: _rating.toDouble(),
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
          );
      if (mounted) setState(() => _submitted = true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.reviewSubmitted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_submitted) {
      return AnimatedFadeIn(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.reviewSubmitted)),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Card(
        key: const ValueKey('merchantReviewCard'),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.rateOrder,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    tooltip: l10n.yourRating,
                    icon: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: star <= _rating ? AppColors.rating : null,
                      size: 36,
                    ),
                    onPressed: () => setState(() => _rating = star),
                  );
                }),
              ),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: l10n.writeReview,
                  labelText: l10n.yourReview,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed:
                    canSubmitReview(rating: _rating, submitting: _submitting)
                    ? _submit
                    : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.submitReview),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
