import 'package:freezed_annotation/freezed_annotation.dart';

part 'offer.freezed.dart';
part 'offer.g.dart';

@freezed
class Offer with _$Offer {
  const factory Offer({
    required String id,
    required String merchantId,
    String? branchId,
    String? categoryId,
    required String title,
    String? description,
    @Default('percentage') String discountType,
    required double discountValue,
    @Default(0.0) double minimumOrder,
    double? maximumDiscount,
    @Default([]) List<String> productIds,
    @Default(true) bool isActive,
    @Default(false) bool isAutomatic,
    DateTime? startsAt,
    DateTime? expiresAt,
    required DateTime createdAt,
  }) = _Offer;

  factory Offer.fromJson(Map<String, dynamic> json) => _$OfferFromJson(json);
}
