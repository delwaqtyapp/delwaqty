import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_review.dart';

class SupabaseServiceReviewDataSource {
  SupabaseServiceReviewDataSource(this._client);

  final SupabaseClient _client;

  Future<List<ServiceReview>> getServiceReviews(
    String categoryType, {
    String? providerId,
  }) async {
    var query = _client
        .from('service_reviews')
        .select()
        .eq('category_type', categoryType);
    if (providerId != null) {
      query = query.eq('provider_id', providerId);
    }
    final data = await query
        .order('created_at', ascending: false)
        .limit(100);
    return (data as List)
        .map((r) => ServiceReview.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceReviewSummary> getServiceRatingSummary(
    String categoryType, {
    String? providerId,
  }) async {
    if (providerId == null) {
      final data = await _client.rpc(
        'get_service_rating_summary',
        params: {'p_category_type': categoryType},
      );
      if (data == null) return const ServiceReviewSummary();
      return ServiceReviewSummary.fromJson(data as Map<String, dynamic>);
    }
    final reviews = await getServiceReviews(categoryType, providerId: providerId);
    return _summarize(reviews);
  }

  ServiceReviewSummary _summarize(List<ServiceReview> reviews) {
    if (reviews.isEmpty) return const ServiceReviewSummary();
    final total = reviews.length;
    final sum = reviews.fold<double>(0, (acc, r) => acc + r.rating);
    int countOf(int stars) => reviews.where((r) => r.rating.round() == stars).length;
    return ServiceReviewSummary(
      averageRating: double.parse((sum / total).toStringAsFixed(1)),
      totalReviews: total,
      fiveStar: countOf(5),
      fourStar: countOf(4),
      threeStar: countOf(3),
      twoStar: countOf(2),
      oneStar: countOf(1),
    );
  }

  Future<ServiceReview?> getMyServiceReview(
    String categoryType, {
    String? providerId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    var query = _client
        .from('service_reviews')
        .select()
        .eq('category_type', categoryType)
        .eq('user_id', userId);
    if (providerId != null) {
      query = query.eq('provider_id', providerId);
    }
    final data = await query.maybeSingle();
    if (data == null) return null;
    return ServiceReview.fromJson(data);
  }

  Future<void> submitServiceReview({
    required String userId,
    required String userName,
    required String categoryType,
    String? providerId,
    String? bookingId,
    required int rating,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'user_name': userName,
      'category_type': categoryType,
      'rating': rating,
      'comment': comment,
      'provider_id': ?providerId,
      'booking_id': ?bookingId,
    };
    var existingQuery = _client
        .from('service_reviews')
        .select('id')
        .eq('category_type', categoryType)
        .eq('user_id', userId);
    existingQuery = providerId != null
        ? existingQuery.eq('provider_id', providerId)
        : existingQuery.isFilter('provider_id', null);
    final existing = await existingQuery.maybeSingle();
    final reviewId = existing?['id'] as String?;
    if (reviewId != null) {
      await _client
          .from('service_reviews')
          .update({
            'rating': rating,
            'comment': comment,
            'provider_id': ?providerId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', reviewId);
      return;
    }
    await _client.from('service_reviews').insert(payload);
  }
}

final supabaseServiceReviewDataSourceProvider =
    Provider<SupabaseServiceReviewDataSource>(
  (ref) =>
      SupabaseServiceReviewDataSource(ref.watch(supabaseClientProvider)),
);