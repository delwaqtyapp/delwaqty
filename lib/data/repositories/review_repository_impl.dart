import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/data/datasources/remote/supabase_review_data_source.dart';
import 'package:delwaqty/features/commerce/domain/entities/review.dart';
import 'package:delwaqty/features/commerce/domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  ReviewRepositoryImpl(this._dataSource);
  final SupabaseReviewDataSource _dataSource;

  @override
  Future<List<Review>> getMerchantReviews(
    String merchantId, {
    int? limit,
    int? offset,
  }) async {
    try {
      return await _dataSource.getMerchantReviews(
        merchantId,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Review>> getProductReviews(
    String productId, {
    int? limit,
    int? offset,
  }) async {
    try {
      return await _dataSource.getProductReviews(
        productId,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Review?> getReviewById(String id) async {
    try {
      return await _dataSource.getReviewById(id);
    } catch (e) {
      throw ServerException(message: e.toString());
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
    try {
      return await _dataSource.createReview(
        merchantId: merchantId,
        userId: userId,
        productId: productId,
        orderId: orderId,
        rating: rating,
        comment: comment,
        imageUrls: imageUrls,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Review> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? imageUrls,
  }) async {
    try {
      return await _dataSource.updateReview(
        reviewId: reviewId,
        rating: rating,
        comment: comment,
        imageUrls: imageUrls,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    try {
      await _dataSource.deleteReview(reviewId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ReviewSummary> getMerchantRatingSummary(String merchantId) async {
    try {
      return await _dataSource.getMerchantRatingSummary(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ReviewSummary> getProductRatingSummary(String productId) async {
    try {
      return await _dataSource.getProductRatingSummary(productId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Stream<Review> watchMerchantReviews(String merchantId) {
    return _dataSource.watchMerchantReviews(merchantId);
  }
}
