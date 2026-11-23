import 'package:delwaqty/core/utils/rpc_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/merchant_profile.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_pricing.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';

final supabaseDeliveryDataSourceProvider = Provider<SupabaseDeliveryDataSource>(
  (ref) {
    return SupabaseDeliveryDataSource(ref.watch(supabaseClientProvider));
  },
);

class SupabaseDeliveryDataSource {
  SupabaseDeliveryDataSource(this._client);

  /// Delivery service types the platform currently serves: every type in
  /// the rides.service_type check constraint (000_baseline) except 'ride'
  /// and the retired 'pharmacy_delivery' (the constraint drops it in the
  /// DB cleanup migration). Anything else, including unknown types, must
  /// never surface as an offerable or active delivery on the driver app.
  static const Set<String> supportedDeliveryServiceTypes = {
    'food_delivery',
    'grocery_delivery',
    'marketplace_delivery',
    'courier',
    'package_delivery',
    'document_delivery',
    'flower_delivery',
    'retail_delivery',
  };

  static bool isSupportedDeliveryServiceType(String? serviceType) =>
      supportedDeliveryServiceTypes.contains(serviceType);

  final SupabaseClient _client;

  Map<String, dynamic> _checkRpc(dynamic data) =>
      checkedRpcResult(data, onFailure: DeliveryException.new);

  DeliveryOrder _deliveryFromRow(Map<String, dynamic> row) {
    return DeliveryOrder(
      id: row['id'] as String,
      serviceType: row['service_type'] as String? ?? 'ride',
      merchantId: row['merchant_id'] as String?,
      merchantName: row['merchant_name'] as String?,
      merchantAddress: row['merchant_address'] as String?,
      riderId: row['rider_id'] as String?,
      driverId: row['driver_id'] as String?,
      driverName: row['driver_name'] as String?,
      driverPhone: row['driver_phone'] as String?,
      pickupLatitude: (row['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (row['pickup_longitude'] as num).toDouble(),
      pickupAddress: row['pickup_address'] as String? ?? '',
      pickupNotes: row['pickup_notes'] as String?,
      dropoffLatitude: (row['dropoff_latitude'] as num).toDouble(),
      dropoffLongitude: (row['dropoff_longitude'] as num).toDouble(),
      dropoffAddress: row['dropoff_address'] as String? ?? '',
      dropoffNotes: row['dropoff_notes'] as String?,
      priority: row['priority'] as String? ?? 'standard',
      status: row['status'] as String? ?? 'searching',
      fare: (row['fare'] as num?)?.toDouble(),
      deliveryFee: (row['delivery_fee'] as num?)?.toDouble(),
      currency: row['currency'] as String? ?? 'EGP',
      distance: (row['distance'] as num?)?.toDouble(),
      estimatedMinutes: (row['estimated_minutes'] as num?)?.toInt(),
      itemsSummary: row['items_summary'] as String?,
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      signatureRequired: row['signature_required'] as bool? ?? false,
      otpRequired: row['otp_required'] as bool? ?? true,
      deliveryProofUrl: row['delivery_proof_url'] as String?,
      scheduledAt: row['scheduled_at'] != null
          ? DateTime.parse(row['scheduled_at'] as String)
          : null,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
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
      recipientName: row['recipient_name'] as String?,
      recipientPhone: row['recipient_phone'] as String?,
      pickupOtp: row['pickup_otp'] as String?,
    );
  }

  RideOffer _offerFromRow(Map<String, dynamic> req, Map<String, dynamic> ride) {
    final rideType = RideType.values.firstWhere(
      (t) => t.name == (ride['ride_type'] as String?),
      orElse: () => RideType.motorcycle,
    );
    return RideOffer(
      requestId: req['id'] as String,
      rideId: req['ride_id'] as String,
      driverId: req['driver_id'] as String,
      rideType: rideType,
      pickupLatitude: (ride['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (ride['pickup_longitude'] as num).toDouble(),
      pickupAddress: ride['pickup_address'] as String? ?? '',
      dropoffLatitude: (ride['dropoff_latitude'] as num).toDouble(),
      dropoffLongitude: (ride['dropoff_longitude'] as num).toDouble(),
      dropoffAddress: ride['dropoff_address'] as String? ?? '',
      fare: (ride['fare'] as num?)?.toDouble() ?? 0.0,
      currency: ride['currency'] as String? ?? 'EGP',
      distanceKm: (ride['distance'] as num?)?.toDouble() ?? 0.0,
      pickupDistanceKm: (req['distance_km'] as num?)?.toDouble() ?? 0.0,
      etaMinutes: (req['eta_minutes'] as num?)?.toInt() ?? 0,
      offeredAt: DateTime.parse(req['offered_at'] as String),
      expiresAt: DateTime.parse(req['expires_at'] as String),
    );
  }

  // ── Customer courier request ──

  Future<String> requestCourierDelivery({
    required String riderId,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    String? itemsSummary,
    String? notes,
    String priority = 'standard',
  }) async {
    final data = await _client
        .from('rides')
        .insert({
          'rider_id': riderId,
          'service_type': 'courier',
          'ride_type': 'motorcycle',
          'status': 'searching',
          'pickup_latitude': pickupLatitude,
          'pickup_longitude': pickupLongitude,
          'pickup_address': pickupAddress,
          'dropoff_latitude': dropoffLatitude,
          'dropoff_longitude': dropoffLongitude,
          'dropoff_address': dropoffAddress,
          'items_summary': itemsSummary,
          'dropoff_notes': notes,
          'priority': priority,
        })
        .select()
        .single();
    return data['id'] as String;
  }

  // ── Dispatch ──

  Future<String> dispatchDelivery(
    String rideId, {
    double radiusKm = 10,
    int limit = 5,
  }) async {
    final map = _checkRpc(
      await _client.rpc(
        'dispatch_delivery',
        params: {
          'p_ride_id': rideId,
          'p_radius_km': radiusKm,
          'p_limit': limit,
        },
      ),
    );
    return map['offered_to']?.toString() ?? '0';
  }

  Future<String> acceptDeliveryRequest(String rideId, String driverId) async {
    final map = _checkRpc(
      await _client.rpc(
        'accept_ride_request',
        params: {'p_ride_id': rideId, 'p_driver_id': driverId},
      ),
    );
    return map['otp'] as String? ?? '';
  }

  Future<void> rejectDeliveryRequest(String rideId, String driverId) async {
    _checkRpc(
      await _client.rpc(
        'reject_ride_request',
        params: {'p_ride_id': rideId, 'p_driver_id': driverId},
      ),
    );
  }

  Stream<List<RideOffer>> watchDeliveryOffers(String driverId) {
    return _client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .asyncMap((rows) async {
          final offered = rows.where((r) => r['status'] == 'offered').toList();
          if (offered.isEmpty) return <RideOffer>[];
          final offers = <RideOffer>[];
          for (final req in offered) {
            final expiresAt = DateTime.parse(req['expires_at'] as String);
            if (expiresAt.isBefore(DateTime.now())) continue;
            final rideRow = await _client
                .from('rides')
                .select()
                .eq('id', req['ride_id'] as String)
                .maybeSingle();
            if (rideRow == null) continue;
            if (rideRow['status'] != 'searching') continue;
            if (!isSupportedDeliveryServiceType(
              rideRow['service_type'] as String?,
            )) {
              continue;
            }
            offers.add(_offerFromRow(req, rideRow));
          }
          return offers;
        });
  }

  // ── Lifecycle ──

  Stream<DeliveryOrder?> watchActiveDelivery(String driverId) {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((rows) {
          final active = rows.where((r) {
            final s = r['status'] as String?;
            final st = r['service_type'] as String?;
            return (s == 'matched' || s == 'arrived' || s == 'inTrip') &&
                isSupportedDeliveryServiceType(st);
          }).toList();
          if (active.isEmpty) return null;
          active.sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
          return _deliveryFromRow(active.first);
        });
  }

  Future<DeliveryOrder?> getActiveDelivery(String driverId) async {
    final row = await _client
        .from('rides')
        .select()
        .eq('driver_id', driverId)
        .inFilter('service_type', supportedDeliveryServiceTypes.toList())
        .inFilter('status', ['matched', 'arrived', 'inTrip'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _enrichWithOrderContact(row, _deliveryFromRow(row));
  }

  /// Food orders carry no recipient_* on the ride; the customer's contact
  /// lives on the ordering user, reachable for a driver only through the
  /// scoped driver_order_contacts RPC (migration 224, item 18).
  Future<DeliveryOrder> _enrichWithOrderContact(
    Map<String, dynamic> row,
    DeliveryOrder order,
  ) async {
    final hasPhone = order.recipientPhone?.trim().isNotEmpty == true;
    final orderId = row['order_id'] as String?;
    if (hasPhone || orderId == null) return order;
    try {
      final rows = await _client.rpc('driver_order_contacts');
      for (final c in (rows as List<dynamic>)) {
        final contact = c as Map<String, dynamic>;
        if (contact['order_id'] == orderId) {
          return order.copyWith(
            recipientPhone: contact['phone'] as String? ?? order.recipientPhone,
            recipientName:
                contact['full_name'] as String? ?? order.recipientName,
          );
        }
      }
    } catch (_) {
      // Contact enrichment is best-effort; the order itself already loaded.
    }
    return order;
  }

  Future<DeliveryOrder?> getDeliveryOrderById(String id) async {
    final row = await _client.from('rides').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return _enrichWithOrderContact(row, _deliveryFromRow(row));
  }

  Future<void> driverArrivedAtPickup(String rideId, String driverId) async {
    _checkRpc(
      await _client.rpc(
        'driver_arrive',
        params: {'p_ride_id': rideId, 'p_driver_id': driverId},
      ),
    );
  }

  Future<void> startDelivery(String rideId, String driverId, String otp) async {
    _checkRpc(
      await _client.rpc(
        'start_trip',
        params: {'p_ride_id': rideId, 'p_driver_id': driverId, 'p_otp': otp},
      ),
    );
  }

  Future<double> completeDelivery(
    String rideId,
    String driverId, {
    String? proofUrl,
    String? recipientOtp,
    double? finalDistanceKm,
  }) async {
    final map = _checkRpc(
      await _client.rpc(
        'complete_delivery',
        params: {
          'p_ride_id': rideId,
          'p_driver_id': driverId,
          'p_proof_url': proofUrl,
          'p_recipient_otp': recipientOtp,
          'p_final_distance': finalDistanceKm,
        },
      ),
    );
    return (map['fare'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> cancelDelivery(
    String rideId, {
    String? reason,
    bool byDriver = false,
  }) async {
    _checkRpc(
      await _client.rpc(
        'cancel_ride_lifecycle',
        params: {
          'p_ride_id': rideId,
          // The actor must be explicit: hard-coding 'driver' mis-attributed
          // (or outright rejected) the customer's own cancel action.
          'p_by': byDriver ? 'driver' : 'rider',
          'p_reason': reason,
        },
      ),
    );
  }

  /// Files a custody incident for a delivery whose goods are already with
  /// the driver. The server refuses plain cancellation at that stage.
  Future<void> reportIncident(
    String rideId,
    String kind, {
    String? note,
  }) async {
    _checkRpc(
      await _client.rpc(
        'report_delivery_incident',
        params: {'p_ride_id': rideId, 'p_kind': kind, 'p_note': note},
      ),
    );
  }

  // ── Pricing ──

  Future<DeliveryPricingModel> getDeliveryPricing(String serviceType) async {
    final row = await _client
        .from('delivery_pricing')
        .select()
        .eq('service_type', serviceType)
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) throw DeliveryException('pricing_not_found');
    return DeliveryPricingModel(
      serviceType: row['service_type'] as String,
      baseFee: (row['base_fee'] as num).toDouble(),
      perKm: (row['per_km'] as num).toDouble(),
      perKg: (row['per_kg'] as num?)?.toDouble() ?? 0,
      minimumFee: (row['minimum_fee'] as num).toDouble(),
      priorityMultiplier:
          (row['priority_multiplier'] as num?)?.toDouble() ?? 1.0,
      expressMultiplier: (row['express_multiplier'] as num?)?.toDouble() ?? 1.5,
      currency: row['currency'] as String? ?? 'EGP',
    );
  }

  Future<Map<String, dynamic>> estimateDeliveryFee(
    String serviceType,
    double distanceKm, {
    double weightKg = 1.0,
    String priority = 'standard',
  }) async {
    final map = _checkRpc(
      await _client.rpc(
        'estimate_delivery_fee',
        params: {
          'p_service_type': serviceType,
          'p_distance_km': distanceKm,
          'p_weight_kg': weightKg,
          'p_priority': priority,
        },
      ),
    );
    return Map<String, dynamic>.from(map);
  }

  // ── Driver capabilities ──

  Future<DriverCapability> getDriverCapabilities(String driverId) async {
    // 198: the drivers table no longer exposes raw rows to non-parties;
    // capability/discovery reads go through the safe-column directory view.
    final row = await _client
        .from('driver_directory')
        .select(
          'service_types, accepts_deliveries, max_delivery_distance_km, max_weight_kg',
        )
        .eq('id', driverId)
        .maybeSingle();
    if (row == null) throw DeliveryException('driver_not_found');
    return DriverCapability(
      driverId: driverId,
      serviceTypes: (row['service_types'] as List?)?.cast<String>() ?? ['ride'],
      acceptsDeliveries: row['accepts_deliveries'] as bool? ?? false,
      maxDeliveryDistanceKm:
          (row['max_delivery_distance_km'] as num?)?.toDouble() ?? 15,
      maxWeightKg: (row['max_weight_kg'] as num?)?.toDouble() ?? 20,
    );
  }

  Future<void> updateDriverCapabilities(
    String driverId, {
    required List<String> serviceTypes,
    bool acceptsDeliveries = true,
    double maxDistance = 15,
    double maxWeight = 20,
  }) async {
    _checkRpc(
      await _client.rpc(
        'update_driver_capabilities',
        params: {
          'p_driver_id': driverId,
          'p_service_types': serviceTypes,
          'p_accepts_deliveries': acceptsDeliveries,
          'p_max_delivery_distance': maxDistance,
          'p_max_weight': maxWeight,
        },
      ),
    );
  }

  // ── Merchant profiles ──

  Future<MerchantProfile?> getMerchantProfile(String merchantId) async {
    final row = await _client
        .from('merchant_profiles')
        .select()
        .eq('merchant_id', merchantId)
        .maybeSingle();
    if (row == null) return null;
    return MerchantProfile(
      id: row['id'] as String,
      merchantId: row['merchant_id'] as String,
      userId: row['user_id'] as String,
      serviceTypes:
          (row['service_types'] as List?)?.cast<String>() ?? ['food_delivery'],
      acceptsDirectDispatch: row['accepts_direct_dispatch'] as bool? ?? true,
      averagePrepTimeMinutes: row['average_prep_time_minutes'] as int? ?? 15,
      maxDeliveryRadiusKm:
          (row['max_delivery_radius_km'] as num?)?.toDouble() ?? 5.0,
      autoAcceptOrders: row['auto_accept_orders'] as bool? ?? false,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<void> upsertMerchantProfile({
    required String merchantId,
    required String userId,
    List<String>? serviceTypes,
    int? averagePrepTime,
    double? maxRadius,
  }) async {
    await _client.from('merchant_profiles').upsert({
      'merchant_id': merchantId,
      'user_id': userId,
      'service_types': ?serviceTypes,
      'average_prep_time_minutes': ?averagePrepTime,
      'max_delivery_radius_km': ?maxRadius,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Stats (reuse existing dispatch) ──

  Future<DriverStats> getDashboardStats(String driverId) async {
    final map = _checkRpc(
      await _client.rpc(
        'driver_dashboard_stats',
        params: {'p_driver_id': driverId},
      ),
    );
    return DriverStats(
      todayRides: (map['today_rides'] as num?)?.toInt() ?? 0,
      todayEarnings: (map['today_earnings'] as num?)?.toDouble() ?? 0,
      weekEarnings: (map['week_earnings'] as num?)?.toDouble() ?? 0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      pendingWithdrawals: (map['pending_withdrawals'] as num?)?.toDouble() ?? 0,
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

  // ── Rating ──

  Future<void> rateDelivery(
    String rideId,
    String driverId,
    int stars, {
    String? comment,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw DeliveryException('unauthenticated');
    }
    await _client.from('ride_ratings').upsert({
      'ride_id': rideId,
      'rater_id': uid,
      'ratee_role': 'driver',
      'stars': stars,
      'comment': ?comment,
    }, onConflict: 'ride_id,rater_id');
  }

  // ── Cash handoff (migration 392) ──

  /// What the assigned captain should collect on this delivery. Returns null
  /// when the server hides the ride (not the assigned driver) — the caller
  /// simply does not render the cash card.
  Future<CashCollectionState?> getCashCollectionState(String rideId) async {
    final data = await _client.rpc(
      'driver_cash_collection_state',
      params: {'p_ride_id': rideId},
    );
    final map = Map<String, dynamic>.from(data as Map);
    if (map['ok'] != true) return null;
    return CashCollectionState.fromJson(map);
  }

  /// The captain's "تم التحصيل" tap. The server stamps the ride and the
  /// linked commerce order atomically; a replay answers ALREADY_COLLECTED.
  Future<CashCollectionResult> confirmCashCollection(String rideId) async {
    final data = await _client.rpc(
      'confirm_cash_collection',
      params: {'p_reference_type': 'ride', 'p_reference_id': rideId},
    );
    final map = Map<String, dynamic>.from(data as Map);
    final result = CashCollectionResult.fromJson(map);
    if (!result.ok) {
      throw DeliveryException(result.code);
    }
    return result;
  }

  /// The delivery ride linked to a commerce order (latest non-cancelled),
  /// for the customer's post-collection driver rating.
  /// Realtime stream of the delivery ride linked to a commerce order. The
  /// customer's rating card listens to this, so it unlocks as soon as the
  /// captain's "تم التحصيل" stamp lands — no manual refresh (review #71).
  Stream<OrderDeliveryRide?> watchOrderDeliveryRide(String orderId) {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .map((rows) {
          final eligible =
              rows.where((r) => r['status'] != 'cancelled').toList()..sort(
                (a, b) => (b['created_at'] as String? ?? '').compareTo(
                  a['created_at'] as String? ?? '',
                ),
              );
          if (eligible.isEmpty) return null;
          return OrderDeliveryRide.fromRow(eligible.first);
        });
  }
}

class DeliveryException implements Exception {
  DeliveryException(this.reason);
  final String reason;
  @override
  String toString() => 'DeliveryException($reason)';
}
