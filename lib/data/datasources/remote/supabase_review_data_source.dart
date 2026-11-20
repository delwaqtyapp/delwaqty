import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/review.dart';

final supabaseReviewDataSourceProvider = Provider<SupabaseReviewDataSource>((
  ref,
) {
  return SupabaseReviewDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseReviewDataSource {
  SupabaseReviewDataSource(this._client);
  final SupabaseClient _client;

  DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Review _fromRow(Map<String, dynamic> row) => Review(
    id: row['id'] as String,
    merchantId: row['merchant_id'] as String? ?? '',
    userId: row['user_id'] as String? ?? '',
    userName: row['user_name'] as String?,
    productId: row['product_id'] as String?,
    orderId: row['order_id'] as String?,
    rating: (row['rating'] as num).toDouble(),
    comment: row['comment'] as String?,
    merchantReply: row['merchant_reply'] as String?,
    merchantRepliedAt: _parseDate(row['merchant_replied_at']),
    imageUrls: row['image_urls'] != null
        ? List<String>.from(row['image_urls'] as List)
        : [],
    createdAt: _parseDate(row['created_at']),
    updatedAt: _parseDate(row['updated_at']),
  );

  ReviewSummary _summaryFromReviews(
    List<Review> reviews, {
    double? rpcAvg,
    int? rpcTotal,
  }) {
    var five = 0;
    var four = 0;
    var three = 0;
    var two = 0;
    var one = 0;
    for (final r in reviews) {
      switch (r.rating.round()) {
        case 5:
          five++;
        case 4:
          four++;
        case 3:
          three++;
        case 2:
          two++;
        default:
          one++;
      }
    }
    final avg =
        rpcAvg ??
        (reviews.isEmpty
            ? 0.0
            : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                  reviews.length);
    final total = rpcTotal ?? reviews.length;
    return ReviewSummary(
      averageRating: avg,
      totalReviews: total,
      fiveStarCount: five,
      fourStarCount: four,
      threeStarCount: three,
      twoStarCount: two,
      oneStarCount: one,
    );
  }

  Future<List<Review>> getMerchantReviews(
    String merchantId, {
    int? limit,
    int? offset,
  }) async {
    dynamic query = _client
        .from('reviews')
        .select()
        .eq('merchant_id', merchantId);

    query = query.order('created_at', ascending: false);

    if (offset != null && limit != null) {
      query = query.range(offset, offset + limit - 1);
    } else if (limit != null) {
      query = query.limit(limit);
    }

    final data = await query;
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Review>> getProductReviews(
    String productId, {
    int? limit,
    int? offset,
  }) async {
    dynamic query = _client
        .from('reviews')
        .select()
        .eq('product_id', productId);

    query = query.order('created_at', ascending: false);

    if (offset != null && limit != null) {
      query = query.range(offset, offset + limit - 1);
    } else if (limit != null) {
      query = query.limit(limit);
    }

    final data = await query;
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
        })
        .select()
        .single();
    return _fromRow(data);
  }

  /// Merchant reply to a customer review.
  ///
  /// Deliberately separate from [updateReview]: that method writes the
  /// `comment` column, which is the CUSTOMER'S text. Using it for a
  /// reply overwrote the review itself (and was rejected by RLS anyway,
  /// because reviews_update_own is scoped to the review's author).
  Future<void> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    await _client.rpc(
      'reply_to_merchant_review',
      params: {'p_review_id': reviewId, 'p_reply': reply},
    );
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
    Map<String, dynamic>? data;
    try {
      data = await _client
          .rpc(
            'get_merchant_rating_summary',
            params: {'p_merchant_id': merchantId},
          )
          .maybeSingle();
    } catch (_) {
      data = null;
    }
    List<Review> reviews = const [];
    try {
      reviews = await getMerchantReviews(merchantId);
    } catch (_) {
      reviews = const [];
    }
    if (data != null) {
      final avg = (data['avg_rating'] as num?)?.toDouble() ?? 0.0;
      final total = (data['total_reviews'] as num?)?.toInt() ?? reviews.length;
      return _summaryFromReviews(reviews, rpcAvg: avg, rpcTotal: total);
    }
    return _summaryFromReviews(reviews);
  }

  Future<ReviewSummary> getProductRatingSummary(String productId) async {
    final reviews = await getProductReviews(productId);
    return _summaryFromReviews(reviews);
  }

  /// Emits the most recent review of a merchant, or null when the last
  /// one is deleted.
  ///
  /// The previous version mapped `rows.first` unguarded, so an empty
  /// emission (e.g. the newest review being deleted) threw a StateError
  /// inside the stream and broke the listener.
  Stream<Review?> watchMerchantReviews(String merchantId) {
    return _client
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', merchantId)
        // Newest first, so rows.first is the latest review.
        .order('created_at')
        .limit(1)
        .map((rows) => rows.isEmpty ? null : _fromRow(rows.first));
  }
}
