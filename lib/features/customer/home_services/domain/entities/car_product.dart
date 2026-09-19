import 'package:freezed_annotation/freezed_annotation.dart';

part 'car_product.freezed.dart';
part 'car_product.g.dart';

@freezed
abstract class CarProduct with _$CarProduct {
  const factory CarProduct({
    required String id,
    required String sellerId,
    String? driverId,
    String? merchantId,
    @Default('car') String category,
    String? make,
    String? model,
    int? year,
    String? color,
    @Default(4) int seats,
    String? photoUrl,
    required String city,
    @Default(0) double price,
    String? description,
    @Default(true) bool isAvailable,
    @Default(false) bool isVerified,
    double? latitude,
    double? longitude,
    required DateTime createdAt,
  }) = _CarProduct;

  factory CarProduct.fromJson(Map<String, dynamic> json) =>
      _$CarProductFromJson(json);
}
