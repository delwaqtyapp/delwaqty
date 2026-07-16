// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReviewImpl _$$ReviewImplFromJson(Map<String, dynamic> json) => _$ReviewImpl(
  id: json['id'] as String,
  merchantId: json['merchantId'] as String,
  userId: json['userId'] as String,
  userName: json['userName'] as String?,
  productId: json['productId'] as String?,
  orderId: json['orderId'] as String?,
  rating: (json['rating'] as num).toDouble(),
  comment: json['comment'] as String?,
  imageUrls:
      (json['imageUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$ReviewImplToJson(_$ReviewImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'merchantId': instance.merchantId,
      'userId': instance.userId,
      'userName': instance.userName,
      'productId': instance.productId,
      'orderId': instance.orderId,
      'rating': instance.rating,
      'comment': instance.comment,
      'imageUrls': instance.imageUrls,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_$ReviewSummaryImpl _$$ReviewSummaryImplFromJson(Map<String, dynamic> json) =>
    _$ReviewSummaryImpl(
      averageRating: (json['averageRating'] as num).toDouble(),
      totalReviews: (json['totalReviews'] as num).toInt(),
      fiveStarCount: (json['fiveStarCount'] as num?)?.toInt() ?? 0,
      fourStarCount: (json['fourStarCount'] as num?)?.toInt() ?? 0,
      threeStarCount: (json['threeStarCount'] as num?)?.toInt() ?? 0,
      twoStarCount: (json['twoStarCount'] as num?)?.toInt() ?? 0,
      oneStarCount: (json['oneStarCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ReviewSummaryImplToJson(_$ReviewSummaryImpl instance) =>
    <String, dynamic>{
      'averageRating': instance.averageRating,
      'totalReviews': instance.totalReviews,
      'fiveStarCount': instance.fiveStarCount,
      'fourStarCount': instance.fourStarCount,
      'threeStarCount': instance.threeStarCount,
      'twoStarCount': instance.twoStarCount,
      'oneStarCount': instance.oneStarCount,
    };
