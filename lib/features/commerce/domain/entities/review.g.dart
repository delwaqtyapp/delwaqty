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
  rating: (json['rating'] as num).toDouble(),
  comment: json['comment'] as String?,
  imageUrls:
      (json['imageUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$ReviewImplToJson(_$ReviewImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'merchantId': instance.merchantId,
      'userId': instance.userId,
      'userName': instance.userName,
      'rating': instance.rating,
      'comment': instance.comment,
      'imageUrls': instance.imageUrls,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
