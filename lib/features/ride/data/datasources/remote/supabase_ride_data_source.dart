import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';

final supabaseRideDataSourceProvider = Provider<SupabaseRideDataSource>((ref) {
  return SupabaseRideDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

class SupabaseRideDataSource {
  SupabaseRideDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _ridesTable = 'rides';

  Ride _rideFromRow(Map<String, dynamic> row) {
    final statusStr = row['status'] as String? ?? 'searching';
    final status = RideStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => RideStatus.searching,
    );
    final typeStr = row['ride_type'] as String? ?? 'economy';
    final rideType = RideType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => RideType.economy,
    );
    return Ride(
      id: row['id'] as String,
      riderId: row['rider_id'] as String,
      driverId: row['driver_id'] as String?,
      driverName: row['driver_name'] as String?,
      driverPhone: row['driver_phone'] as String?,
      driverPhoto: row['driver_photo'] as String?,
      vehicleType: row['vehicle_type'] as String?,
      vehiclePlate: row['vehicle_plate'] as String?,
      vehicleColor: row['vehicle_color'] as String?,
      pickupLatitude: (row['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (row['pickup_longitude'] as num).toDouble(),
      pickupAddress: row['pickup_address'] as String? ?? '',
      dropoffLatitude: (row['dropoff_latitude'] as num).toDouble(),
      dropoffLongitude: (row['dropoff_longitude'] as num).toDouble(),
      dropoffAddress: row['dropoff_address'] as String? ?? '',
      rideType: rideType,
      status: status,
      fare: (row['fare'] as num?)?.toDouble(),
      distance: (row['distance'] as num?)?.toDouble(),
      estimatedMinutes: row['estimated_minutes'] as int?,
      driverLatitude: (row['driver_latitude'] as num?)?.toDouble(),
      driverLongitude: (row['driver_longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String),
      matchedAt: row['matched_at'] != null ? DateTime.parse(row['matched_at'] as String) : null,
      arrivedAt: row['arrived_at'] != null ? DateTime.parse(row['arrived_at'] as String) : null,
      startedAt: row['started_at'] != null ? DateTime.parse(row['started_at'] as String) : null,
      completedAt: row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null,
      cancelledAt: row['cancelled_at'] != null ? DateTime.parse(row['cancelled_at'] as String) : null,
      cancellationReason: row['cancellation_reason'] as String?,
      isSharedTrip: row['is_shared_trip'] as bool? ?? false,
      emergencyContactId: row['emergency_contact_id'] as String?,
    );
  }

  Future<Ride> requestRide({
    required String riderId,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    required RideType rideType,
  }) async {
    try {
      final data = await _client.from(_ridesTable).insert({
        'rider_id': riderId,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'pickup_address': pickupAddress,
        'dropoff_latitude': dropoffLatitude,
        'dropoff_longitude': dropoffLongitude,
        'dropoff_address': dropoffAddress,
        'ride_type': rideType.name,
        'status': RideStatus.searching.name,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();
      return _rideFromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to request ride', e, stack);
      return _mockRide(
        riderId: riderId,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        pickupAddress: pickupAddress,
        dropoffLatitude: dropoffLatitude,
        dropoffLongitude: dropoffLongitude,
        dropoffAddress: dropoffAddress,
        rideType: rideType,
      );
    }
  }

  Future<void> cancelRide(String rideId, {String? reason}) async {
    try {
      await _client.from(_ridesTable).update({
        'status': RideStatus.cancelled.name,
        'cancellation_reason': reason,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', rideId);
    } catch (e, stack) {
      _logger.e('Failed to cancel ride', e, stack);
    }
  }

  Future<Ride?> getActiveRide(String riderId) async {
    try {
      final data = await _client
          .from(_ridesTable)
          .select()
          .eq('rider_id', riderId)
          .inFilter('status', [
            RideStatus.searching.name,
            RideStatus.matched.name,
            RideStatus.arrived.name,
            RideStatus.inTrip.name,
          ])
          .order('created_at', ascending: false)
          .maybeSingle();
      if (data == null) return null;
      return _rideFromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to get active ride', e, stack);
      return null;
    }
  }

  Future<List<Ride>> getRideHistory(String riderId, {int limit = 20, int offset = 0}) async {
    try {
      final data = await _client
          .from(_ridesTable)
          .select()
          .eq('rider_id', riderId)
          .inFilter('status', [RideStatus.completed.name, RideStatus.cancelled.name])
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((row) => _rideFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get ride history', e, stack);
      return _mockRideHistory();
    }
  }

  Future<void> rateRide(String rideId, int rating, {String? feedback, double? tip}) async {
    try {
      await _client.from(_ridesTable).update({
        'rating': rating,
        'feedback': feedback,
        'tip': tip,
      }).eq('id', rideId);
    } catch (e, stack) {
      _logger.e('Failed to rate ride', e, stack);
    }
  }

  Future<void> shareTrip(String rideId) async {
    try {
      await _client.from(_ridesTable).update({
        'is_shared_trip': true,
      }).eq('id', rideId);
    } catch (e, stack) {
      _logger.e('Failed to share trip', e, stack);
    }
  }

  Future<void> reportIssue(String rideId, String issue) async {
    try {
      await _client.from('ride_issues').insert({
        'ride_id': rideId,
        'issue': issue,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e, stack) {
      _logger.e('Failed to report issue', e, stack);
    }
  }

  Future<Map<String, double>> getFareEstimate({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required RideType rideType,
  }) async {
    try {
      final data = await _client.rpc('estimate_ride_fare', params: {
        'p_pickup_lat': pickupLatitude,
        'p_pickup_lng': pickupLongitude,
        'p_dropoff_lat': dropoffLatitude,
        'p_dropoff_lng': dropoffLongitude,
        'p_ride_type': rideType.name,
      });
      return {
        'fare': (data['fare'] as num?)?.toDouble() ?? _estimateFareLocally(pickupLatitude, pickupLongitude, dropoffLatitude, dropoffLongitude, rideType),
        'distance': (data['distance'] as num?)?.toDouble() ?? _haversineDistance(pickupLatitude, pickupLongitude, dropoffLatitude, dropoffLongitude),
        'estimatedMinutes': (data['estimated_minutes'] as num?)?.toDouble() ?? 15,
      };
    } catch (e, stack) {
      _logger.e('Failed to get fare estimate from API, using local', e, stack);
      final distance = _haversineDistance(pickupLatitude, pickupLongitude, dropoffLatitude, dropoffLongitude);
      return {
        'fare': _estimateFareLocally(pickupLatitude, pickupLongitude, dropoffLatitude, dropoffLongitude, rideType),
        'distance': distance,
        'estimatedMinutes': (distance / 0.5).ceilToDouble(),
      };
    }
  }

  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = (dLat / 2) * (dLat / 2) +
        _degToRad(lat1) * _degToRad(lat2) * (dLng / 2) * (dLng / 2);
    final c = 2 * _approxAtan(a);
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);

  double _approxAtan(double x) {
    return x < 1.0 ? x / (1.0 + 0.28 * x * x) : 1.5708 - 2.0 / (x + 1.35);
  }

  double _estimateFareLocally(
    double pickupLat,
    double pickupLng,
    double dropoffLat,
    double dropoffLng,
    RideType type,
  ) {
    final distance = _haversineDistance(pickupLat, pickupLng, dropoffLat, dropoffLng);
    double baseFare;
    double perKm;
    switch (type) {
      case RideType.economy:
        baseFare = 5.0;
        perKm = 1.5;
        break;
      case RideType.comfort:
        baseFare = 8.0;
        perKm = 2.5;
        break;
      case RideType.premium:
        baseFare = 12.0;
        perKm = 4.0;
        break;
    }
    return baseFare + (distance * perKm);
  }

  Ride _mockRide({
    required String riderId,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    required RideType rideType,
  }) {
    final distance = _haversineDistance(pickupLatitude, pickupLongitude, dropoffLatitude, dropoffLongitude);
    return Ride(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      riderId: riderId,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupAddress: pickupAddress,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      dropoffAddress: dropoffAddress,
      rideType: rideType,
      fare: _estimateFareLocally(pickupLatitude, pickupLongitude, dropoffLatitude, dropoffLongitude, rideType),
      distance: distance,
      estimatedMinutes: (distance / 0.5).ceil(),
      createdAt: DateTime.now(),
    );
  }

  List<Ride> _mockRideHistory() {
    return [
      Ride(
        id: 'hist-1',
        riderId: 'mock',
        pickupLatitude: 24.7136,
        pickupLongitude: 46.6753,
        pickupAddress: 'King Fahd Road, Riyadh',
        dropoffLatitude: 24.6877,
        dropoffLongitude: 46.7219,
        dropoffAddress: 'Riyadh Gallery Mall',
        status: RideStatus.completed,
        fare: 25.0,
        distance: 8.5,
        estimatedMinutes: 18,
        driverName: 'Ahmed M.',
        driverPhone: '+966501234567',
        vehicleType: 'Toyota Camry',
        vehiclePlate: 'ABC 1234',
        vehicleColor: 'White',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        completedAt: DateTime.now().subtract(const Duration(days: 2, minutes: -20)),
      ),
      Ride(
        id: 'hist-2',
        riderId: 'mock',
        pickupLatitude: 24.7136,
        pickupLongitude: 46.6753,
        pickupAddress: 'Olaya Street, Riyadh',
        dropoffLatitude: 24.6956,
        dropoffLongitude: 46.6833,
        dropoffAddress: 'King Abdullah Financial District',
        rideType: RideType.comfort,
        status: RideStatus.completed,
        fare: 35.0,
        distance: 5.2,
        estimatedMinutes: 12,
        driverName: 'Saud K.',
        driverPhone: '+966509876543',
        vehicleType: 'Hyundai Sonata',
        vehiclePlate: 'XYZ 5678',
        vehicleColor: 'Black',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        completedAt: DateTime.now().subtract(const Duration(days: 5, minutes: -14)),
      ),
    ];
  }
}
