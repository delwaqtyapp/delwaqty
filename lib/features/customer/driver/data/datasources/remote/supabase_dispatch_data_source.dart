import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';

final supabaseDispatchDataSourceProvider =
    Provider<SupabaseDispatchDataSource>((ref) {
  return SupabaseDispatchDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseDispatchDataSource {
  SupabaseDispatchDataSource(this._client);

  final SupabaseClient _client;

  static const String _rides = 'rides';
  static const String _requests = 'ride_requests';

  Map<String, dynamic> _checkRpc(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    if (map['success'] == false) {
      throw DispatchException(map['reason'] as String? ?? 'unknown');
    }
    return map;
  }

  Ride _rideFromRow(Map<String, dynamic> row) {
    final status = RideStatus.values.firstWhere(
      (s) => s.name == (row['status'] as String?),
      orElse: () => RideStatus.searching,
    );
    final rideType = RideType.values.firstWhere(
      (t) => t.name == (row['ride_type'] as String?),
      orElse: () => RideType.economy,
    );
    return Ride(
      id: row['id'] as String,
      riderId: row['rider_id'] as String,
      driverId: row['driver_id'] as String?,
      driverName: row['driver_name'] as String?,
      driverPhone: row['driver_phone'] as String?,
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
      matchedAt: row['matched_at'] != null
          ? DateTime.parse(row['matched_at'] as String)
          : null,
      arrivedAt: row['arrived_at'] != null
          ? DateTime.parse(row['arrived_at'] as String)
          : null,
      startedAt: row['started_at'] != null
          ? DateTime.parse(row['started_at'] as String)
          : null,
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : null,
      cancelledAt: row['cancelled_at'] != null
          ? DateTime.parse(row['cancelled_at'] as String)
          : null,
      cancellationReason: row['cancellation_reason'] as String?,
    );
  }

  Future<String> registerRideDriver({
    required String fullName,
    required String phone,
    required RideType category,
    required String make,
    required String model,
    required String color,
    required String plate,
    int seats = 4,
  }) async {
    final map = _checkRpc(await _client.rpc('register_ride_driver', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_category': category.name,
      'p_make': make,
      'p_model': model,
      'p_color': color,
      'p_plate': plate,
      'p_seats': seats,
    }));
    return map['driver_id'] as String;
  }

  Future<void> setOnline(
    String driverId,
    bool online, {
    double? lat,
    double? lng,
  }) async {
    _checkRpc(await _client.rpc('driver_set_online', params: {
      'p_driver_id': driverId,
      'p_online': online,
      'p_lat': lat,
      'p_lon': lng,
    }));
  }

  Future<void> updateLocation(
    String driverId,
    double lat,
    double lng, {
    double? heading,
    double? speed,
  }) async {
    _checkRpc(await _client.rpc('driver_update_location', params: {
      'p_driver_id': driverId,
      'p_lat': lat,
      'p_lon': lng,
      'p_heading': heading,
      'p_speed': speed,
    }));
  }

  Stream<List<RideOffer>> watchOffers(String driverId) {
    return _client
        .from(_requests)
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .asyncMap((rows) async {
      final offered = rows
          .where((r) => r['status'] == 'offered')
          .toList();
      if (offered.isEmpty) return <RideOffer>[];
      final offers = <RideOffer>[];
      for (final req in offered) {
        final expiresAt = DateTime.parse(req['expires_at'] as String);
        if (expiresAt.isBefore(DateTime.now())) continue;
        final rideRow = await _client
            .from(_rides)
            .select()
            .eq('id', req['ride_id'] as String)
            .maybeSingle();
        if (rideRow == null) continue;
        if (rideRow['status'] != 'searching') continue;
        final rideType = RideType.values.firstWhere(
          (t) => t.name == (rideRow['ride_type'] as String?),
          orElse: () => RideType.economy,
        );
        offers.add(RideOffer(
          requestId: req['id'] as String,
          rideId: req['ride_id'] as String,
          driverId: driverId,
          rideType: rideType,
          pickupLatitude: (rideRow['pickup_latitude'] as num).toDouble(),
          pickupLongitude: (rideRow['pickup_longitude'] as num).toDouble(),
          pickupAddress: rideRow['pickup_address'] as String? ?? '',
          dropoffLatitude: (rideRow['dropoff_latitude'] as num).toDouble(),
          dropoffLongitude: (rideRow['dropoff_longitude'] as num).toDouble(),
          dropoffAddress: rideRow['dropoff_address'] as String? ?? '',
          fare: (rideRow['fare'] as num?)?.toDouble() ?? 0.0,
          currency: rideRow['currency'] as String? ?? 'EGP',
          distanceKm: (rideRow['distance'] as num?)?.toDouble() ?? 0.0,
          pickupDistanceKm: (req['distance_km'] as num?)?.toDouble() ?? 0.0,
          etaMinutes: (req['eta_minutes'] as num?)?.toInt() ?? 0,
          offeredAt: DateTime.parse(req['offered_at'] as String),
          expiresAt: expiresAt,
        ));
      }
      return offers;
    });
  }

  Future<String> acceptOffer(String rideId, String driverId) async {
    final map = _checkRpc(await _client.rpc('accept_ride_request', params: {
      'p_ride_id': rideId,
      'p_driver_id': driverId,
    }));
    return map['otp'] as String? ?? '';
  }

  Future<void> rejectOffer(String rideId, String driverId) async {
    _checkRpc(await _client.rpc('reject_ride_request', params: {
      'p_ride_id': rideId,
      'p_driver_id': driverId,
    }));
  }

  Stream<Ride?> watchActiveDriverRide(String driverId) {
    return _client
        .from(_rides)
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((rows) {
      final active = rows.where((r) {
        final s = r['status'] as String?;
        return s == 'matched' || s == 'arrived' || s == 'inTrip';
      }).toList();
      if (active.isEmpty) return null;
      active.sort((a, b) => (b['created_at'] as String)
          .compareTo(a['created_at'] as String));
      return _rideFromRow(active.first);
    });
  }

  Future<Ride?> getActiveDriverRide(String driverId) async {
    final rows = await _client
        .from(_rides)
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', ['matched', 'arrived', 'inTrip'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (rows == null) return null;
    return _rideFromRow(rows);
  }

  Future<void> arriveAtPickup(String rideId, String driverId) async {
    _checkRpc(await _client.rpc('driver_arrive', params: {
      'p_ride_id': rideId,
      'p_driver_id': driverId,
    }));
  }

  Future<void> startTrip(String rideId, String driverId, String otp) async {
    _checkRpc(await _client.rpc('start_trip', params: {
      'p_ride_id': rideId,
      'p_driver_id': driverId,
      'p_otp': otp,
    }));
  }

  Future<double> completeTrip(
    String rideId,
    String driverId, {
    double? finalDistanceKm,
  }) async {
    final map = _checkRpc(await _client.rpc('complete_trip', params: {
      'p_ride_id': rideId,
      'p_driver_id': driverId,
      'p_final_distance': finalDistanceKm,
    }));
    return (map['fare'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> cancelAsDriver(String rideId, {String? reason}) async {
    _checkRpc(await _client.rpc('cancel_ride_lifecycle', params: {
      'p_ride_id': rideId,
      'p_by': 'driver',
      'p_reason': reason,
    }));
  }

  Future<void> ratePassenger(
    String rideId,
    String driverId,
    int stars, {
    String? comment,
  }) async {
    _checkRpc(await _client.rpc('rate_passenger', params: {
      'p_ride_id': rideId,
      'p_driver_id': driverId,
      'p_stars': stars,
      'p_comment': comment,
    }));
  }

  Future<DriverStats> getDashboardStats(String driverId) async {
    final map = _checkRpc(await _client.rpc('driver_dashboard_stats', params: {
      'p_driver_id': driverId,
    }));
    return DriverStats(
      todayRides: (map['today_rides'] as num?)?.toInt() ?? 0,
      todayEarnings: (map['today_earnings'] as num?)?.toDouble() ?? 0,
      weekEarnings: (map['week_earnings'] as num?)?.toDouble() ?? 0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      pendingWithdrawals:
          (map['pending_withdrawals'] as num?)?.toDouble() ?? 0,
      totalTrips: (map['total_trips'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      acceptanceRate: (map['acceptance_rate'] as num?)?.toDouble() ?? 100,
      currency: 'EGP',
    );
  }

  Future<List<DriverEarning>> getEarnings(
    String driverId, {
    int limit = 30,
  }) async {
    final rows = await _client
        .from('driver_earnings')
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) {
      final row = Map<String, dynamic>.from(r as Map);
      return DriverEarning(
        id: row['id'] as String,
        type: row['type'] as String? ?? 'trip',
        amount: (row['amount'] as num).toDouble(),
        currency: row['currency'] as String? ?? 'EGP',
        rideId: row['ride_id'] as String?,
        description: row['description'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  Future<String> requestWithdrawal(
    String driverId,
    double amount, {
    String method = 'bank',
  }) async {
    final map = _checkRpc(await _client.rpc('request_withdrawal', params: {
      'p_driver_id': driverId,
      'p_amount': amount,
      'p_method': method,
    }));
    return map['withdrawal_id'] as String? ?? '';
  }
}

class DispatchException implements Exception {
  DispatchException(this.reason);
  final String reason;
  @override
  String toString() => 'DispatchException($reason)';
}
