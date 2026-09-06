import 'package:freezed_annotation/freezed_annotation.dart';

part 'merchant.freezed.dart';
part 'merchant.g.dart';

enum MerchantType {
  @JsonValue('restaurant')
  restaurant,
  @JsonValue('grocery')
  grocery,
  @JsonValue('supermarket')
  supermarket,
  @JsonValue('fruits')
  fruits,
  @JsonValue('meat')
  meat,
  @JsonValue('seafood')
  seafood,
  @JsonValue('pharmacy')
  pharmacy,
  @JsonValue('bakery')
  bakery,
  @JsonValue('sweets')
  sweets,
  @JsonValue('flowers')
  flowers,
  @JsonValue('clothing')
  clothing,
  @JsonValue('shoes')
  shoes,
  @JsonValue('electronics')
  electronics,
  @JsonValue('mobile')
  mobile,
  @JsonValue('furniture')
  furniture,
  @JsonValue('fashion')
  fashion,
  @JsonValue('appliances')
  appliances,
  @JsonValue('home')
  home,
  @JsonValue('cafe')
  cafe,
  @JsonValue('petShop')
  petShop,
  @JsonValue('fitness')
  fitness,
  @JsonValue('gas')
  gas,
  @JsonValue('carwash')
  carwash,
  @JsonValue('other')
  other,
}

@freezed
abstract class Merchant with _$Merchant {
  const factory Merchant({
    required String id,
    required String name,
    required MerchantType type,
    required double latitude,
    required double longitude,
    String? address,
    String? city,
    @Default(0.0) double rating,
    @Default(0) int ratingCount,
    String? imageUrl,
    String? description,
    @Default(false) bool isOpenNow,
    @Default(false) bool isVerified,
    @Default(false) bool isFeatured,
    @Default(false) bool deliveryAvailable,
    @Default(false) bool pickupAvailable,
    int? estimatedDeliveryMinutes,
    double? deliveryFee,
    double? minimumOrder,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Merchant;

  factory Merchant.fromJson(Map<String, dynamic> json) =>
      _$MerchantFromJson(json);
}
