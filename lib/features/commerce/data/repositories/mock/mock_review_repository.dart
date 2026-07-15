import 'package:delwaqty/features/commerce/domain/entities/review.dart';
import 'package:delwaqty/features/commerce/domain/repositories/review_repository.dart';

class MockReviewRepository implements ReviewRepository {
  final List<Review> _reviews = [];

  @override
  Future<List<Review>> getMerchantReviews(String merchantId) async =>
      _reviews.where((r) => r.merchantId == merchantId).toList();

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
    required double rating,
    String? comment,
  }) async {
    final review = Review(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      merchantId: merchantId,
      userId: 'user_1',
      userName: 'Current User',
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );
    _reviews.add(review);
    return review;
  }
}
