import 'package:delwaqty/features/commerce/domain/entities/review.dart';

abstract interface class ReviewRepository {
  Future<List<Review>> getMerchantReviews(String merchantId);
  Future<Review?> getReviewById(String id);
  Future<Review> submitReview({
    required String merchantId,
    required double rating,
    String? comment,
  });
}
