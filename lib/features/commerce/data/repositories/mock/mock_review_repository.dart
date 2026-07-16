import 'package:delwaqty/features/commerce/domain/entities/review.dart';
import 'package:delwaqty/features/commerce/domain/repositories/review_repository.dart';

class MockReviewRepository implements ReviewRepository {
  final List<Review> _reviews = [];

  @override
  Future<List<Review>> getMerchantReviews(String merchantId) async =>
      _reviews.where((r) => r.merchantId == merchantId).toList();

  @override
  Future<List<Review>> getProductReviews(String productId) async =>
      _reviews.where((r) => r.productId == productId).toList();

  @override
  Future<Review?> getReviewById(String id) async {
    try {
      return _reviews.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Review> submitReview({
    required String merchantId,
    required String userId,
    String? productId,
    String? orderId,
    required double rating,
    String? comment,
    List<String>? imageUrls,
  }) async {
    final review = Review(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      merchantId: merchantId,
      userId: userId,
      productId: productId,
      orderId: orderId,
      rating: rating,
      comment: comment,
      imageUrls: imageUrls ?? [],
      createdAt: DateTime.now(),
    );
    _reviews.add(review);
    return review;
  }

  @override
  Future<Review> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? imageUrls,
  }) async {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index == -1) throw Exception('Review not found');
    final existing = _reviews[index];
    final updated = existing.copyWith(
      rating: rating ?? existing.rating,
      comment: comment ?? existing.comment,
      imageUrls: imageUrls ?? existing.imageUrls,
      updatedAt: DateTime.now(),
    );
    _reviews[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    _reviews.removeWhere((r) => r.id == reviewId);
  }

  @override
  Future<ReviewSummary> getMerchantRatingSummary(String merchantId) async {
    final reviews = await getMerchantReviews(merchantId);
    if (reviews.isEmpty) return const ReviewSummary(averageRating: 0, totalReviews: 0);
    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    return ReviewSummary(averageRating: avg, totalReviews: reviews.length);
  }

  @override
  Future<ReviewSummary> getProductRatingSummary(String productId) async {
    final reviews = await getProductReviews(productId);
    if (reviews.isEmpty) return const ReviewSummary(averageRating: 0, totalReviews: 0);
    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    return ReviewSummary(averageRating: avg, totalReviews: reviews.length);
  }

  @override
  Stream<Review> watchMerchantReviews(String merchantId) {
    return Stream.periodic(const Duration(seconds: 1))
        .where((_) => _reviews.any((r) => r.merchantId == merchantId))
        .map((_) => _reviews.lastWhere((r) => r.merchantId == merchantId));
  }
}
