import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/commerce/domain/entities/review.dart';

final supabaseReviewDataSourceProvider = Provider<SupabaseReviewDataSource>((
  ref,
) {
  return SupabaseReviewDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseReviewDataSource {
  SupabaseReviewDataSource(this._client);
  final SupabaseClient _client;

  Review _fromRow(Map<String, dynamic> row) => Review(
    id: row['id'] as String,
    merchantId: row['merchant_id'] as String,
    userId: row['user_id'] as String,
    userName: row['user_name'] as String?,
    productId: row['product_id'] as String?,
    orderId: row['order_id'] as String?,
    rating: (row['rating'] as num).toDouble(),
    comment: row['comment'] as String?,
    imageUrls: row['image_urls'] != null
        ? List<String>.from(row['image_urls'] as List)
        : [],
    createdAt: row['created_at'] != null
        ? DateTime.parse(row['created_at'] as String)
        : null,
    updatedAt: row['updated_at'] != null
        ? DateTime.parse(row['updated_at'] as String)
        : null,
  );

  ReviewSummary _summaryFromAgg(Map<String, dynamic> row) {
    final avg = (row['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final total = (row['total_reviews'] as num?)?.toInt() ?? 0;
    return ReviewSummary(averageRating: avg, totalReviews: total);
  }

  Future<List<Review>> getMerchantReviews(String merchantId) async {
    final data = await _client
        .from('reviews')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Review>> getProductReviews(String productId) async {
    final data = await _client
        .from('reviews')
        .select()
        .eq('product_id', productId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<Review?> getReviewById(String id) async {
    final data = await _client
        .from('reviews')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? _fromRow(data) : null;
  }

  Future<Review> createReview({
    required String merchantId,
    required String userId,
    String? productId,
    String? orderId,
    required double rating,
    String? comment,
    List<String>? imageUrls,
  }) async {
    final data = await _client
        .from('reviews')
        .insert({
          'merchant_id': merchantId,
          'user_id': userId,
          'product_id': productId,
          'order_id': orderId,
          'rating': rating.round(),
          'comment': comment,
          'image_urls': imageUrls ?? [],
        })
        .select()
        .single();
    return _fromRow(data);
  }

  Future<Review> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? imageUrls,
  }) async {
    final update = <String, dynamic>{};
    if (rating != null) update['rating'] = rating.round();
    if (comment != null) update['comment'] = comment;
    if (imageUrls != null) update['image_urls'] = imageUrls;
    update['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client
        .from('reviews')
        .update(update)
        .eq('id', reviewId)
        .select()
        .single();
    return _fromRow(data);
  }

  Future<void> deleteReview(String reviewId) async {
    await _client.from('reviews').delete().eq('id', reviewId);
  }

  Future<ReviewSummary> getMerchantRatingSummary(String merchantId) async {
    final data = await _client
        .rpc(
          'get_merchant_rating_summary',
          params: {'p_merchant_id': merchantId},
        )
        .maybeSingle();
    if (data != null) return _summaryFromAgg(data);
    final reviews = await getMerchantReviews(merchantId);
    if (reviews.isEmpty)
      return const ReviewSummary(averageRating: 0, totalReviews: 0);
    final avg =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    return ReviewSummary(averageRating: avg, totalReviews: reviews.length);
  }

  Future<ReviewSummary> getProductRatingSummary(String productId) async {
    final reviews = await getProductReviews(productId);
    if (reviews.isEmpty)
      return const ReviewSummary(averageRating: 0, totalReviews: 0);
    final avg =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    return ReviewSummary(averageRating: avg, totalReviews: reviews.length);
  }

  Stream<Review> watchMerchantReviews(String merchantId) {
    return _client
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false)
        .limit(1)
        .map((rows) => _fromRow(rows.first));
  }
}
