import 'package:delwaqty/features/restaurant/domain/entities/delivery_zone.dart';

abstract interface class DeliveryZoneRepository {
  Future<List<DeliveryZone>> getZones(String merchantId);
  Future<DeliveryZone?> getZoneById(String id);
  Future<DeliveryZone> createZone(DeliveryZone zone);
  Future<DeliveryZone> updateZone(DeliveryZone zone);
  Future<void> deleteZone(String id);
}
