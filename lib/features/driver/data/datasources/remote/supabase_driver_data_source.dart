import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_delivery.dart';

final supabaseDriverDataSourceProvider = Provider<SupabaseDriverDataSource>((ref) {
  return SupabaseDriverDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

class SupabaseDriverDataSource {
  SupabaseDriverDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _driversTable = 'drivers';
  static const String _deliveriesTable = 'deliveries';

  DriverProfile _profileFromRow(Map<String, dynamic> row) {
    final statusStr = row['status'] as String? ?? 'offline';
    final status = DriverStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => DriverStatus.offline,
    );
    return DriverProfile(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      vehicleType: row['vehicle_type'] as String?,
      vehiclePlate: row['vehicle_plate'] as String?,
      vehicleColor: row['vehicle_color'] as String?,
      status: status,
      currentLatitude: (row['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (row['current_longitude'] as num?)?.toDouble(),
      totalEarnings: (row['total_earnings'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: row['total_deliveries'] as int? ?? 0,
      rating: (row['rating'] as num?)?.toDouble() ?? 4.5,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  DriverDelivery _deliveryFromRow(Map<String, dynamic> row) {
    return DriverDelivery(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      merchantName: row['merchant_name'] as String? ?? '',
      merchantAddress: row['merchant_address'] as String? ?? '',
      customerName: row['customer_name'] as String? ?? '',
      deliveryAddress: row['delivery_address'] as String? ?? '',
      customerLatitude: (row['customer_latitude'] as num?)?.toDouble(),
      customerLongitude: (row['customer_longitude'] as num?)?.toDouble(),
      status: row['status'] as String? ?? 'pending',
      deliveryFee: (row['delivery_fee'] as num?)?.toDouble(),
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      acceptedAt: row['accepted_at'] != null ? DateTime.parse(row['accepted_at'] as String) : null,
      pickedUpAt: row['picked_up_at'] != null ? DateTime.parse(row['picked_up_at'] as String) : null,
      deliveredAt: row['delivered_at'] != null ? DateTime.parse(row['delivered_at'] as String) : null,
    );
  }

  Future<DriverProfile?> getProfile(String userId) async {
    try {
      final data = await _client
          .from(_driversTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;
      return _profileFromRow(data as Map<String, dynamic>);
    } catch (e, stack) {
      _logger.e('Failed to get driver profile', e, stack);
      rethrow;
    }
  }

  Future<DriverProfile> registerProfile(String userId, {String? vehicleType, String? vehiclePlate, String? vehicleColor}) async {
    try {
      final data = await _client
          .from(_driversTable)
          .upsert({
            'user_id': userId,
            'vehicle_type': vehicleType,
            'vehicle_plate': vehiclePlate,
            'vehicle_color': vehicleColor,
            'status': 'offline',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return _profileFromRow(data as Map<String, dynamic>);
    } catch (e, stack) {
      _logger.e('Failed to register driver', e, stack);
      rethrow;
    }
  }

  Future<void> updateStatus(String profileId, DriverStatus status) async {
    try {
      await _client.from(_driversTable).update({
        'status': status.name,
      }).eq('id', profileId);
    } catch (e, stack) {
      _logger.e('Failed to update driver status', e, stack);
      rethrow;
    }
  }

  Future<void> updateLocation(String profileId, double lat, double lng) async {
    try {
      await _client.from(_driversTable).update({
        'current_latitude': lat,
        'current_longitude': lng,
      }).eq('id', profileId);
    } catch (e, stack) {
      _logger.e('Failed to update location', e, stack);
      rethrow;
    }
  }

  Future<List<DriverDelivery>> getAvailableDeliveries() async {
    try {
      final data = await _client
          .from(_deliveriesTable)
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);
      return (data as List)
          .map((row) => _deliveryFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get available deliveries', e, stack);
      rethrow;
    }
  }

  Future<List<DriverDelivery>> getMyDeliveries(String profileId, {String? status}) async {
    try {
      var query = _client
          .from(_deliveriesTable)
          .select()
          .eq('driver_id', profileId);
      if (status != null) {
        query = query.eq('status', status);
      }
      final data = await query.order('created_at', ascending: false).limit(50);
      return (data as List)
          .map((row) => _deliveryFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get my deliveries', e, stack);
      rethrow;
    }
  }

  Future<void> acceptDelivery(String deliveryId, String profileId) async {
    try {
      await _client.from(_deliveriesTable).update({
        'driver_id': profileId,
        'status': 'accepted',
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', deliveryId);
    } catch (e, stack) {
      _logger.e('Failed to accept delivery', e, stack);
      rethrow;
    }
  }

  Future<void> rejectDelivery(String deliveryId) async {
    try {
      await _client.from(_deliveriesTable).update({
        'status': 'rejected',
      }).eq('id', deliveryId);
    } catch (e, stack) {
      _logger.e('Failed to reject delivery', e, stack);
      rethrow;
    }
  }

  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    try {
      final updates = <String, dynamic>{'status': status};
      if (status == 'picked_up') {
        updates['picked_up_at'] = DateTime.now().toIso8601String();
      } else if (status == 'delivered') {
        updates['delivered_at'] = DateTime.now().toIso8601String();
      }
      await _client.from(_deliveriesTable).update(updates).eq('id', deliveryId);
    } catch (e, stack) {
      _logger.e('Failed to update delivery status', e, stack);
      rethrow;
    }
  }
}
