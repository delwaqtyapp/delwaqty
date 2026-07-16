import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/restaurant/domain/entities/delivery_zone.dart';

final supabaseDeliveryZoneDataSourceProvider = Provider<SupabaseDeliveryZoneDataSource>((ref) {
  return SupabaseDeliveryZoneDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseDeliveryZoneDataSource {
  SupabaseDeliveryZoneDataSource(this._client);
  final SupabaseClient _client;

  DeliveryZone _fromRow(Map<String, dynamic> row) => DeliveryZone(
    id: row['id'] as String,
    merchantId: row['merchant_id'] as String,
    name: row['name'] as String,
    radiusKm: (row['radius_km'] as num).toDouble(),
    deliveryFee: (row['delivery_fee'] as num? ?? 0).toDouble(),
    minimumOrder: (row['minimum_order'] as num? ?? 0).toDouble(),
    estimatedMinutes: row['estimated_minutes'] as int? ?? 30,
    isActive: row['is_active'] as bool? ?? true,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  Future<List<DeliveryZone>> getZones(String merchantId) async {
    final data = await _client.from('delivery_zones').select().eq('merchant_id', merchantId).order('radius_km');
    return (data as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<DeliveryZone?> getZoneById(String id) async {
    final data = await _client.from('delivery_zones').select().eq('id', id).maybeSingle();
    return data != null ? _fromRow(data) : null;
  }

  Future<DeliveryZone> createZone(DeliveryZone zone) async {
    final data = await _client.from('delivery_zones').insert({
      'merchant_id': zone.merchantId,
      'name': zone.name,
      'radius_km': zone.radiusKm,
      'delivery_fee': zone.deliveryFee,
      'minimum_order': zone.minimumOrder,
      'estimated_minutes': zone.estimatedMinutes,
      'is_active': zone.isActive,
    }).select().single();
    return _fromRow(data);
  }

  Future<DeliveryZone> updateZone(DeliveryZone zone) async {
    final data = await _client.from('delivery_zones').update({
      'name': zone.name,
      'radius_km': zone.radiusKm,
      'delivery_fee': zone.deliveryFee,
      'minimum_order': zone.minimumOrder,
      'estimated_minutes': zone.estimatedMinutes,
      'is_active': zone.isActive,
    }).eq('id', zone.id).select().single();
    return _fromRow(data);
  }

  Future<void> deleteZone(String id) async {
    await _client.from('delivery_zones').delete().eq('id', id);
  }
}
