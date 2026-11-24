import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_delivery.dart';

final supabaseDriverDataSourceProvider = Provider<SupabaseDriverDataSource>((
  ref,
) {
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
      // drivers has `earnings_balance`; `total_earnings` exists only as a
      // key inside RPC JSON payloads, never as a column, so the dashboard
      // always rendered EGP 0.
      totalEarnings: (row['earnings_balance'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: row['total_deliveries'] as int? ?? 0,
      rating: (row['rating'] as num?)?.toDouble() ?? 4.5,
      createdAt: DateTime.parse(row['created_at'] as String),
      onboardingCompleted: row['onboarding_completed'] as bool? ?? false,
      onboardingStep: row['onboarding_step'] as int? ?? 0,
      verificationStatus: row['verification_status'] as String? ?? 'pending',
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
      acceptedAt: row['accepted_at'] != null
          ? DateTime.parse(row['accepted_at'] as String)
          : null,
      pickedUpAt: row['picked_up_at'] != null
          ? DateTime.parse(row['picked_up_at'] as String)
          : null,
      deliveredAt: row['delivered_at'] != null
          ? DateTime.parse(row['delivered_at'] as String)
          : null,
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
      return _profileFromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to get driver profile', e, stack);
      rethrow;
    }
  }

  /// Registers the driver through the authoritative RPC.
  ///
  /// The previous implementation upserted `drivers` directly WITHOUT
  /// `full_name` (NOT NULL -> the insert always threw) and never set
  /// `is_verified` or `active_vehicle_id`, so even on success the driver
  /// could never satisfy `dispatch_delivery`'s filter. The RPC
  /// (migration 107) creates or repairs the row, verifies the driver and
  /// links an active vehicle in one transaction.
  Future<DriverProfile> registerProfile(
    String userId, {
    required String fullName,
    String? phone,
    String? vehicleType,
    String? vehiclePlate,
    String? vehicleColor,
  }) async {
    try {
      final res = await _client.rpc(
        'driver_complete_registration',
        params: {
          'p_full_name': fullName,
          'p_phone': phone,
          'p_vehicle_type': vehicleType,
          'p_vehicle_plate': vehiclePlate,
          'p_vehicle_color': vehicleColor,
        },
      );
      final driverId = (res as Map)['driver_id'] as String;
      final data = await _client
          .from(_driversTable)
          .select()
          .eq('id', driverId)
          .single();
      return _profileFromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to register driver', e, stack);
      rethrow;
    }
  }

  Future<void> updateStatus(String profileId, DriverStatus status) async {
    try {
      await _client
          .from(_driversTable)
          .update({'status': status.name})
          .eq('id', profileId);
    } catch (e, stack) {
      _logger.e('Failed to update driver status', e, stack);
      rethrow;
    }
  }

  Future<void> updateLocation(String profileId, double lat, double lng) async {
    try {
      await _client
          .from(_driversTable)
          .update({'current_latitude': lat, 'current_longitude': lng})
          .eq('id', profileId);
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

  Future<List<DriverDelivery>> getMyDeliveries(
    String profileId, {
    String? status,
  }) async {
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
      await _client
          .from(_deliveriesTable)
          .update({
            'driver_id': profileId,
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', deliveryId);
    } catch (e, stack) {
      _logger.e('Failed to accept delivery', e, stack);
      rethrow;
    }
  }

  Future<void> rejectDelivery(String deliveryId) async {
    try {
      await _client
          .from(_deliveriesTable)
          .update({'status': 'rejected'})
          .eq('id', deliveryId);
    } catch (e, stack) {
      _logger.e('Failed to reject delivery', e, stack);
      rethrow;
    }
  }

  // ── Ask-anything courier flow (436) ──
  //
  // The captain's side of the negotiation and the live invoice. All five
  // RPCs answer `{ok: false, reason: CODE}` instead of throwing; the
  // reason is re-thrown so the page can localize it (courierErrorText).

  Map<String, dynamic> _checkCourierRpc(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    if (map['ok'] != true) {
      throw DriverCourierException((map['reason'] ?? 'unknown').toString());
    }
    return map;
  }

  /// Propose the delivery price (the opening quote) or answer the
  /// customer's counter with a new one. Server bounds: 15 + 5 per extra
  /// shop floor, 50000 cap.
  Future<void> proposeCourierQuote(
    String rideId,
    double amount, {
    String? note,
  }) async {
    _checkCourierRpc(
      await _client.rpc(
        'propose_courier_quote',
        params: {'p_ride_id': rideId, 'p_amount': amount, 'p_note': note},
      ),
    );
  }

  /// Answer the customer's pending counter: 'accept' locks the price,
  /// 'reject' reopens the negotiation.
  Future<void> respondCourierQuote(String quoteId, String action) async {
    _checkCourierRpc(
      await _client.rpc(
        'respond_courier_quote',
        params: {'p_quote_id': quoteId, 'p_action': action},
      ),
    );
  }

  /// Record one item at the shop with its real price. The customer must
  /// approve it before it is bought.
  Future<void> addCourierInvoiceItem(
    String rideId, {
    required String shopName,
    required String productName,
    required double price,
    String? unit,
    double? quantity,
    String? receiptPhotoUrl,
  }) async {
    _checkCourierRpc(
      await _client.rpc(
        'add_courier_invoice_item',
        params: {
          'p_ride_id': rideId,
          'p_shop_name': shopName,
          'p_product_name': productName,
          'p_price': price,
          'p_unit': unit,
          'p_quantity': quantity,
          'p_receipt_photo_url': receiptPhotoUrl,
        },
      ),
    );
  }

  /// Cancel a rejected (or still pending) item at the shop so
  /// finish_courier_shopping can lock the goods total.
  Future<void> cancelCourierInvoiceItem(String itemId) async {
    _checkCourierRpc(
      await _client.rpc(
        'cancel_courier_invoice_item',
        params: {'p_item_id': itemId},
      ),
    );
  }

  /// End shopping: allowed only when every item is decided and every
  /// rejected item is cancelled; locks the approved goods total.
  Future<void> finishCourierShopping(String rideId) async {
    _checkCourierRpc(
      await _client.rpc(
        'finish_courier_shopping',
        params: {'p_ride_id': rideId},
      ),
    );
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

/// A 436 courier RPC rejected the operation; [reason] is the server's
/// machine code, localized for the driver by courierErrorText.
class DriverCourierException implements Exception {
  DriverCourierException(this.reason);
  final String reason;
  @override
  String toString() => 'DriverCourierException($reason)';
}
