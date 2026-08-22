import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/provider/availability/data/datasources/remote/supabase_provider_availability_data_source.dart';

abstract class ProviderAvailabilityRepository {
  Future<Map<String, dynamic>> getAvailability();
  Future<Map<String, dynamic>> setAvailability(bool isOpen);
}

class ProviderAvailabilityRepositoryImpl implements ProviderAvailabilityRepository {
  final ProviderAvailabilityDataSource _source;
  ProviderAvailabilityRepositoryImpl(this._source);

  @override
  Future<Map<String, dynamic>> getAvailability() async {
    try {
      return await _source.getAvailability();
    } catch (e) {
      throw ServerException(message: 'Failed to load availability: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> setAvailability(bool isOpen) async {
    try {
      return await _source.setAvailability(isOpen);
    } catch (e) {
      throw ServerException(message: 'Failed to update availability: $e');
    }
  }
}
