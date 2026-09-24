import 'package:delwaqty/features/customer/home_services/domain/entities/service_review.dart';

abstract class ServiceReviewRepository {
  Future<List<ServiceReview>> getServiceReviews(String categoryType);

  Future<ServiceReviewSummary> getServiceRatingSummary(String categoryType);

  Future<ServiceReview?> getMyServiceReview(String categoryType);

  Future<void> submitServiceReview({
    required String userId,
    required String userName,
    required String categoryType,
    String? providerId,
    String? bookingId,
    required int rating,
    String? comment,
  });
}