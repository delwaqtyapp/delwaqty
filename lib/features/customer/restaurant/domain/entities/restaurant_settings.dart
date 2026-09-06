import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurant_settings.freezed.dart';
part 'restaurant_settings.g.dart';

@freezed
abstract class RestaurantSettings with _$RestaurantSettings {
  const factory RestaurantSettings({
    required String id,
    required String merchantId,
    @Default(false) bool acceptsReservations,
    @Default(true) bool hasDineIn,
    @Default(true) bool hasTakeaway,
    @Default(true) bool hasDelivery,
    @Default(15) int averagePrepTime,
    @Default(20) int maxOrdersPerHour,
    @Default(false) bool autoAcceptOrders,
    @Default(false) bool printerEnabled,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _RestaurantSettings;

  factory RestaurantSettings.fromJson(Map<String, dynamic> json) =>
      _$RestaurantSettingsFromJson(json);
}
