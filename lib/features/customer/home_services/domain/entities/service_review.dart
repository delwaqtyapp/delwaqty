class ServiceReview {
  const ServiceReview({
    required this.id,
    required this.categoryType,
    this.providerId,
    this.bookingId,
    required this.userName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory ServiceReview.fromJson(Map<String, dynamic> json) {
    return ServiceReview(
      id: json['id'] as String? ?? '',
      categoryType: json['category_type'] as String? ?? '',
      providerId: json['provider_id'] as String?,
      bookingId: json['booking_id'] as String?,
      userName: json['user_name'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String categoryType;
  final String? providerId;
  final String? bookingId;
  final String userName;
  final double rating;
  final String? comment;
  final DateTime? createdAt;
}

class ServiceReviewSummary {
  const ServiceReviewSummary({
    this.averageRating = 0,
    this.totalReviews = 0,
    this.fiveStar = 0,
    this.fourStar = 0,
    this.threeStar = 0,
    this.twoStar = 0,
    this.oneStar = 0,
  });

  factory ServiceReviewSummary.fromJson(Map<String, dynamic> json) {
    return ServiceReviewSummary(
      averageRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      fiveStar: (json['five_star'] as num?)?.toInt() ?? 0,
      fourStar: (json['four_star'] as num?)?.toInt() ?? 0,
      threeStar: (json['three_star'] as num?)?.toInt() ?? 0,
      twoStar: (json['two_star'] as num?)?.toInt() ?? 0,
      oneStar: (json['one_star'] as num?)?.toInt() ?? 0,
    );
  }

  final double averageRating;
  final int totalReviews;
  final int fiveStar;
  final int fourStar;
  final int threeStar;
  final int twoStar;
  final int oneStar;

  int countFor(int stars) => switch (stars) {
        5 => fiveStar,
        4 => fourStar,
        3 => threeStar,
        2 => twoStar,
        _ => oneStar,
      };
}