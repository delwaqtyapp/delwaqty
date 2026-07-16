import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_delivery_zone_data_source.dart';
import 'package:delwaqty/features/restaurant/domain/entities/delivery_zone.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/delivery_zone_repository.dart';

class DeliveryZoneRepositoryImpl implements DeliveryZoneRepository {
  DeliveryZoneRepositoryImpl(this._dataSource);
  final SupabaseDeliveryZoneDataSource _dataSource;

  @override
  Future<List<DeliveryZone>> getZones(String merchantId) async {
    try { return await _dataSource.getZones(merchantId); }
    catch (e) { throw ServerException(message: e.toString()); }
  }

  @override
  Future<DeliveryZone?> getZoneById(String id) async {
    try { return await _dataSource.getZoneById(id); }
    catch (e) { throw ServerException(message: e.toString()); }
  }

  @override
  Future<DeliveryZone> createZone(DeliveryZone zone) async {
    try { return await _dataSource.createZone(zone); }
    catch (e) { throw ServerException(message: e.toString()); }
  }

  @override
  Future<DeliveryZone> updateZone(DeliveryZone zone) async {
    try { return await _dataSource.updateZone(zone); }
    catch (e) { throw ServerException(message: e.toString()); }
  }

  @override
  Future<void> deleteZone(String id) async {
    try { await _dataSource.deleteZone(id); }
    catch (e) { throw ServerException(message: e.toString()); }
  }
}
