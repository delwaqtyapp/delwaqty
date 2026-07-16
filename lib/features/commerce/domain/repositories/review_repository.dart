import 'package:delwaqty/features/commerce/domain/entities/review.dart';

abstract interface class ReviewRepository {
  Future<List<Review>> getMerchantReviews(String merchantId);
  Future<List<Review>> getProductReviews(String productId);
  Future<Review?> getReviewById(String id);
  Future<Review> submitReview({
    required String merchantId,
    required String userId,
    String? productId,
    String? orderId,
    required double rating,
    String? comment,
    List<String>? imageUrls,
  });
  Future<Review> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? imageUrls,
  });
  Future<void> deleteReview(String reviewId);
  Future<ReviewSummary> getMerchantRatingSummary(String merchantId);
  Future<ReviewSummary> getProductRatingSummary(String productId);
  Stream<Review> watchMerchantReviews(String merchantId);
}
