import 'package:delwaqty/features/customer/restaurant/domain/entities/restaurant_settings.dart';

abstract interface class RestaurantSettingsRepository {
  Future<RestaurantSettings?> getSettings(String merchantId);
  Future<RestaurantSettings> updateSettings(RestaurantSettings settings);
}
