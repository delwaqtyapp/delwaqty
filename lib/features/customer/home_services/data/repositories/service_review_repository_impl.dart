import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/customer/home_services/data/datasources/supabase_service_review_data_source.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_review.dart';
import 'package:delwaqty/features/customer/home_services/domain/repositories/service_review_repository.dart';

class ServiceReviewRepositoryImpl implements ServiceReviewRepository {
  ServiceReviewRepositoryImpl(this._dataSource);

  final SupabaseServiceReviewDataSource _dataSource;

  @override
  Future<List<ServiceReview>> getServiceReviews(
    String categoryType, {
    String? providerId,
  }) async {
    try {
      return await _dataSource.getServiceReviews(
        categoryType,
        providerId: providerId,
      );
    } catch (e) {
      throw ServerException(message: 'getServiceReviews failed: $e');
    }
  }

  @override
  Future<ServiceReviewSummary> getServiceRatingSummary(
    String categoryType, {
    String? providerId,
  }) async {
    try {
      return await _dataSource.getServiceRatingSummary(
        categoryType,
        providerId: providerId,
      );
    } catch (e) {
      throw ServerException(message: 'getServiceRatingSummary failed: $e');
    }
  }

  @override
  Future<ServiceReview?> getMyServiceReview(
    String categoryType, {
    String? providerId,
  }) async {
    try {
      return await _dataSource.getMyServiceReview(
        categoryType,
        providerId: providerId,
      );
    } catch (e) {
      throw ServerException(message: 'getMyServiceReview failed: $e');
    }
  }

  @override
  Future<void> submitServiceReview({
    required String userId,
    required String userName,
    required String categoryType,
    String? providerId,
    String? bookingId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _dataSource.submitServiceReview(
        userId: userId,
        userName: userName,
        categoryType: categoryType,
        providerId: providerId,
        bookingId: bookingId,
        rating: rating,
        comment: comment,
      );
    } catch (e) {
      throw ServerException(message: 'submitServiceReview failed: $e');
    }
  }
}

final serviceReviewRepositoryImplProvider =
    Provider<ServiceReviewRepositoryImpl>(
  (ref) => ServiceReviewRepositoryImpl(
    ref.watch(supabaseServiceReviewDataSourceProvider),
  ),
);

final serviceReviewRepositoryProvider = Provider<ServiceReviewRepository>(
  (ref) => ref.watch(serviceReviewRepositoryImplProvider),
);

final serviceReviewsProvider = FutureProvider.family<List<ServiceReview>,
    ServiceReviewScope>(
  (ref, scope) => ref
      .watch(serviceReviewRepositoryProvider)
      .getServiceReviews(scope.categoryType, providerId: scope.providerId),
);

final serviceReviewSummaryProvider =
    FutureProvider.family<ServiceReviewSummary, ServiceReviewScope>(
  (ref, scope) => ref
      .watch(serviceReviewRepositoryProvider)
      .getServiceRatingSummary(scope.categoryType, providerId: scope.providerId),
);

final myServiceReviewProvider =
    FutureProvider.family<ServiceReview?, ServiceReviewScope>(
  (ref, scope) => ref
      .watch(serviceReviewRepositoryProvider)
      .getMyServiceReview(scope.categoryType, providerId: scope.providerId),
);