import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/domain/entities/fare_quote.dart';

final supabaseRideDataSourceProvider = Provider<SupabaseRideDataSource>((ref) {
  return SupabaseRideDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseRideDataSource {
  SupabaseRideDataSource(this._client);

  final SupabaseClient _client;

  static const String _ridesTable = 'rides';
  static const double _avgSpeedKmh = 28.0;

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
      baseFare: (row['base_fare'] as num?)?.toDouble(),
      distanceFare: (row['distance_fare'] as num?)?.toDouble(),
      timeFare: (row['time_fare'] as num?)?.toDouble(),
      surgeMultiplier: (row['surge_multiplier'] as num?)?.toDouble() ?? 1.0,
      discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0.0,
      promoCode: row['promo_code'] as String?,
      paymentMethod: row['payment_method'] as String? ?? 'cash',
      paymentStatus: row['payment_status'] as String? ?? 'pending',
      pickupOtp: row['pickup_otp'] as String?,
      currency: row['currency'] as String? ?? 'EGP',
      distance: (row['distance'] as num?)?.toDouble(),
      estimatedMinutes: (row['estimated_minutes'] as num?)?.toInt(),
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

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.asin(math.min(1.0, math.sqrt(a)));
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  Future<List<FareQuote>> getFareQuotes({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
  }) async {
    final distanceKm = _haversineKm(
      pickupLatitude,
      pickupLongitude,
      dropoffLatitude,
      dropoffLongitude,
    );
    final durationMin = (distanceKm / _avgSpeedKmh) * 60.0;
    final quotes = <FareQuote>[];
    for (final type in RideType.values) {
      final data = await _client.rpc('estimate_fare', params: {
        'p_category': type.name,
        'p_distance_km': distanceKm,
        'p_duration_min': durationMin,
        'p_surge': 1.0,
      });
      final map = Map<String, dynamic>.from(data as Map);
      final eta = 2 + (type.index % 3) * 2;
      quotes.add(FareQuote(
        rideType: type,
        baseFare: (map['base_fare'] as num).toDouble(),
        distanceFare: (map['distance_fare'] as num).toDouble(),
        timeFare: (map['time_fare'] as num).toDouble(),
        surgeMultiplier: (map['surge_multiplier'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
        minimumFare: (map['minimum_fare'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'EGP',
        distanceKm: distanceKm,
        durationMinutes: durationMin,
        etaMinutes: eta,
      ));
    }
    return quotes;
  }

  Future<PromoResult> validatePromo({
    required String code,
    required double fare,
    required String userId,
  }) async {
    final data = await _client.rpc('validate_promo', params: {
      'p_code': code.toUpperCase(),
      'p_user_id': userId,
      'p_fare': fare,
    });
    final map = Map<String, dynamic>.from(data as Map);
    final valid = map['valid'] as bool? ?? false;
    if (!valid) {
      return PromoResult(valid: false, reason: map['reason'] as String?);
    }
    return PromoResult(
      valid: true,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      promoId: map['promo_id'] as String?,
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
    required double fare,
    required FareQuote quote,
    String? promoCode,
    double discountAmount = 0,
    String paymentMethod = 'cash',
  }) async {
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
      'fare': fare,
      'base_fare': quote.baseFare,
      'distance_fare': quote.distanceFare,
      'time_fare': quote.timeFare,
      'surge_multiplier': quote.surgeMultiplier,
      'discount_amount': discountAmount,
      'promo_code': promoCode,
      'payment_method': paymentMethod,
      'distance': quote.distanceKm,
      'estimated_minutes': quote.durationMinutes.ceil(),
      'currency': quote.currency,
    }).select().single();
    return _rideFromRow(data);
  }

  Future<List<NearbyDriver>> findNearbyDrivers({
    required double latitude,
    required double longitude,
    required RideType rideType,
    double radiusKm = 8,
    int limit = 10,
  }) async {
    final data = await _client.rpc('find_nearest_drivers', params: {
      'p_lat': latitude,
      'p_lon': longitude,
      'p_category': rideType.name,
      'p_radius_km': radiusKm,
      'p_limit': limit,
    });
    return (data as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return NearbyDriver(
        driverId: map['driver_id'] as String,
        fullName: map['full_name'] as String? ?? '',
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        distanceKm: (map['distance_km'] as num).toDouble(),
        rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  Future<int> dispatchRide(String rideId) async {
    final data = await _client.rpc('dispatch_ride', params: {
      'p_ride_id': rideId,
    });
    final map = Map<String, dynamic>.from(data as Map);
    return (map['offered'] as num?)?.toInt() ?? 0;
  }

  Stream<Ride> watchRide(String rideId) {
    return _client
        .from(_ridesTable)
        .stream(primaryKey: ['id'])
        .eq('id', rideId)
        .map((rows) => rows.isNotEmpty ? _rideFromRow(rows.first) : null)
        .where((ride) => ride != null)
        .cast<Ride>();
  }

  Future<Ride?> getRide(String rideId) async {
    final data =
        await _client.from(_ridesTable).select().eq('id', rideId).maybeSingle();
    if (data == null) return null;
    return _rideFromRow(data);
  }

  Future<void> cancelRide(String rideId, {String? reason}) async {
    await _client.rpc('cancel_ride_lifecycle', params: {
      'p_ride_id': rideId,
      'p_by': 'rider',
      'p_reason': reason,
    });
  }

  Future<Ride?> getActiveRide(String riderId) async {
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
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return _rideFromRow(data);
  }

  Future<List<Ride>> getRideHistory(String riderId,
      {int limit = 20, int offset = 0}) async {
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
  }

  Future<void> rateRide(String rideId, int rating,
      {String? feedback, double? tip}) async {
    await _client.from(_ridesTable).update({
      'rating': rating,
      'feedback': feedback,
      'tip': tip,
    }).eq('id', rideId);
  }

  Future<void> shareTrip(String rideId) async {
    await _client.from(_ridesTable).update({
      'is_shared_trip': true,
    }).eq('id', rideId);
  }

  Future<void> reportIssue(String rideId, String issue) async {
    final ride = await getRide(rideId);
    await _client.from('complaints').insert({
      'ride_id': rideId,
      'reporter_id': ride?.riderId,
      'category': 'sos',
      'description': issue,
    });
  }
}
