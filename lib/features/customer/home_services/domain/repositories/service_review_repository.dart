import 'package:delwaqty/features/customer/home_services/domain/entities/service_review.dart';

typedef ServiceReviewScope = ({String categoryType, String? providerId});

abstract class ServiceReviewRepository {
  Future<List<ServiceReview>> getServiceReviews(
    String categoryType, {
    String? providerId,
  });

  Future<ServiceReviewSummary> getServiceRatingSummary(
    String categoryType, {
    String? providerId,
  });

  Future<ServiceReview?> getMyServiceReview(
    String categoryType, {
    String? providerId,
  });

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