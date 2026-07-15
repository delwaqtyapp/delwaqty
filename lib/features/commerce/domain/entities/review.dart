import 'package:freezed_annotation/freezed_annotation.dart';

part 'review.freezed.dart';
part 'review.g.dart';

@freezed
class Review with _$Review {
  const factory Review({
    required String id,
    required String merchantId,
    required String userId,
    String? userName,
    required double rating,
    String? comment,
    @Default([]) List<String> imageUrls,
    DateTime? createdAt,
  }) = _Review;

  factory Review.fromJson(Map<String, dynamic> json) =>
      _$ReviewFromJson(json);
}
