// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CouponImpl _$$CouponImplFromJson(Map<String, dynamic> json) => _$CouponImpl(
  id: json['id'] as String,
  code: json['code'] as String,
  description: json['description'] as String?,
  type: $enumDecode(_$CouponTypeEnumMap, json['type']),
  value: (json['value'] as num).toDouble(),
  minimumOrder: (json['minimumOrder'] as num?)?.toDouble(),
  maximumDiscount: (json['maximumDiscount'] as num?)?.toDouble(),
  merchantId: json['merchantId'] as String?,
  branchId: json['branchId'] as String?,
  productId: json['productId'] as String?,
  categoryId: json['categoryId'] as String?,
  usageLimit: (json['usageLimit'] as num?)?.toInt(),
  usedCount: (json['usedCount'] as num?)?.toInt(),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  isActive: json['isActive'] as bool? ?? true,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$CouponImplToJson(_$CouponImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'description': instance.description,
      'type': _$CouponTypeEnumMap[instance.type]!,
      'value': instance.value,
      'minimumOrder': instance.minimumOrder,
      'maximumDiscount': instance.maximumDiscount,
      'merchantId': instance.merchantId,
      'branchId': instance.branchId,
      'productId': instance.productId,
      'categoryId': instance.categoryId,
      'usageLimit': instance.usageLimit,
      'usedCount': instance.usedCount,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'isActive': instance.isActive,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$CouponTypeEnumMap = {
  CouponType.percentage: 'percentage',
  CouponType.fixed: 'fixed',
  CouponType.freeDelivery: 'free_delivery',
};
