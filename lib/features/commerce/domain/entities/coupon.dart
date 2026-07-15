import 'package:freezed_annotation/freezed_annotation.dart';

part 'coupon.freezed.dart';
part 'coupon.g.dart';

enum CouponType {
  @JsonValue('percentage')
  percentage,
  @JsonValue('fixed')
  fixed,
  @JsonValue('free_delivery')
  freeDelivery,
}

@freezed
class Coupon with _$Coupon {
  const factory Coupon({
    required String id,
    required String code,
    required CouponType type,
    required double value,
    double? minimumOrder,
    double? maximumDiscount,
    @Default([]) List<String> applicableMerchantIds,
    int? usageLimit,
    int? usedCount,
    DateTime? expiresAt,
    @Default(true) bool isActive,
  }) = _Coupon;

  factory Coupon.fromJson(Map<String, dynamic> json) =>
      _$CouponFromJson(json);
}
