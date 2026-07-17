import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_restaurant_settings_data_source.dart';
import 'package:delwaqty/features/restaurant/domain/entities/restaurant_settings.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/restaurant_settings_repository.dart';

class RestaurantSettingsRepositoryImpl implements RestaurantSettingsRepository {
  RestaurantSettingsRepositoryImpl(this._dataSource);
  final SupabaseRestaurantSettingsDataSource _dataSource;

  @override
  Future<RestaurantSettings?> getSettings(String merchantId) async {
    try {
      return await _dataSource.getSettings(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<RestaurantSettings> updateSettings(RestaurantSettings settings) async {
    try {
      return await _dataSource.updateSettings(settings);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
