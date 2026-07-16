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

enum CouponStatus {
  @JsonValue('active')
  active,
  @JsonValue('expired')
  expired,
  @JsonValue('used_up')
  usedUp,
  @JsonValue('inactive')
  inactive,
}

@freezed
class Coupon with _$Coupon {
  const factory Coupon({
    required String id,
    required String code,
    String? description,
    required CouponType type,
    required double value,
    double? minimumOrder,
    double? maximumDiscount,
    String? merchantId,
    String? branchId,
    String? productId,
    String? categoryId,
    int? usageLimit,
    int? usedCount,
    DateTime? expiresAt,
    @Default(true) bool isActive,
    DateTime? createdAt,
  }) = _Coupon;

  factory Coupon.fromJson(Map<String, dynamic> json) =>
      _$CouponFromJson(json);
}
