// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CouponImpl _$$CouponImplFromJson(Map<String, dynamic> json) => _$CouponImpl(
  id: json['id'] as String,
  code: json['code'] as String,
  type: $enumDecode(_$CouponTypeEnumMap, json['type']),
  value: (json['value'] as num).toDouble(),
  minimumOrder: (json['minimumOrder'] as num?)?.toDouble(),
  maximumDiscount: (json['maximumDiscount'] as num?)?.toDouble(),
  applicableMerchantIds:
      (json['applicableMerchantIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  usageLimit: (json['usageLimit'] as num?)?.toInt(),
  usedCount: (json['usedCount'] as num?)?.toInt(),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  isActive: json['isActive'] as bool? ?? true,
);

Map<String, dynamic> _$$CouponImplToJson(_$CouponImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'type': _$CouponTypeEnumMap[instance.type]!,
      'value': instance.value,
      'minimumOrder': instance.minimumOrder,
      'maximumDiscount': instance.maximumDiscount,
      'applicableMerchantIds': instance.applicableMerchantIds,
      'usageLimit': instance.usageLimit,
      'usedCount': instance.usedCount,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'isActive': instance.isActive,
    };

const _$CouponTypeEnumMap = {
  CouponType.percentage: 'percentage',
  CouponType.fixed: 'fixed',
  CouponType.freeDelivery: 'free_delivery',
};
