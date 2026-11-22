import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';

/// Read-only stream for customer delivery tracking. The shared SQL relation
/// is still called rides; passenger ride booking is not supported.
final deliveryTripStreamProvider = StreamProvider.family<Ride, String>((
  ref,
  id,
) {
  return DeliveryTripTrackingSource(ref.watch(supabaseClientProvider))
      .watchRide(id);
});

class DeliveryTripTrackingSource {
  DeliveryTripTrackingSource(this._client);
  final SupabaseClient _client;
  static const _ridesTable = 'rides';
  Ride _rideFromRow(Map<String, dynamic> row) {
    final statusStr = row['status'] as String? ?? 'searching';
    final status = RideStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => RideStatus.searching,
    );
    final typeStr = row['ride_type'] as String? ?? 'motorcycle';
    final rideType = RideType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => RideType.motorcycle,
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
      cashCollectedAt: row['cash_collected_at'] != null
          ? DateTime.parse(row['cash_collected_at'] as String)
          : null,
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
      isSharedTrip: row['is_shared_trip'] as bool? ?? false,
      emergencyContactId: row['emergency_contact_id'] as String?,
    );
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
}
