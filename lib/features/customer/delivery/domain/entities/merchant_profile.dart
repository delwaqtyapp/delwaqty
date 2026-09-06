import 'package:freezed_annotation/freezed_annotation.dart';

part 'merchant_profile.freezed.dart';
part 'merchant_profile.g.dart';

@freezed
abstract class MerchantProfile with _$MerchantProfile {
  const factory MerchantProfile({
    required String id,
    required String merchantId,
    required String userId,
    @Default(['food_delivery']) List<String> serviceTypes,
    @Default(true) bool acceptsDirectDispatch,
    @Default(15) int averagePrepTimeMinutes,
    @Default(5.0) double maxDeliveryRadiusKm,
    @Default(false) bool autoAcceptOrders,
    @Default(true) bool isActive,
    required DateTime createdAt,
  }) = _MerchantProfile;

  factory MerchantProfile.fromJson(Map<String, dynamic> json) =>
      _$MerchantProfileFromJson(json);
}
