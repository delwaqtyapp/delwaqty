import 'package:delwaqty/core/utils/rpc_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';

final supabaseDispatchDataSourceProvider = Provider<SupabaseDispatchDataSource>(
  (ref) {
    return SupabaseDispatchDataSource(ref.watch(supabaseClientProvider));
  },
);

class SupabaseDispatchDataSource {
  SupabaseDispatchDataSource(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _checkRpc(dynamic data) =>
      checkedRpcResult(data, onFailure: DispatchException.new);

  Future<bool> getOnline(String driverId) async {
    final result = _checkRpc(
      await _client.rpc('driver_presence', params: {'p_driver_id': driverId}),
    );
    return result['online'] == true;
  }

  /// Flips the whole dispatch precondition set in one atomic call.
  ///
  /// `driver_set_online` (008) only wrote `is_online` + coordinates, but
  /// `dispatch_delivery` selects on `status = 'online' AND is_verified
  /// AND active_vehicle_id IS NOT NULL`. Since nothing else moved `status`
  /// or linked an active vehicle, no driver was ever eligible for an
  /// offer. `driver_set_online_state` (migration 107) updates status,
  /// is_online, active_vehicle_id and the coordinates together.
  Future<void> setOnline(
    String driverId,
    bool online, {
    double? lat,
    double? lng,
  }) async {
    _checkRpc(
      await _client.rpc(
        'driver_set_online_state',
        params: {
          'p_online': online,
          'p_lat': lat,
          'p_lng': lng,
          'p_driver_id': driverId,
        },
      ),
    );
  }

  Future<void> updateLocation(
    String driverId,
    double lat,
    double lng, {
    double? heading,
    double? speed,
  }) async {
    _checkRpc(
      await _client.rpc(
        'driver_update_location',
        params: {
          'p_driver_id': driverId,
          'p_lat': lat,
          'p_lon': lng,
          'p_heading': heading,
          'p_speed': speed,
        },
      ),
    );
  }

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

  Future<String> requestWithdrawal(
    String driverId,
    double amount, {
    String method = 'bank',
  }) async {
    final map = _checkRpc(
      await _client.rpc(
        'request_withdrawal',
        params: {
          'p_driver_id': driverId,
          'p_amount': amount,
          'p_method': method,
        },
      ),
    );
    return map['withdrawal_id'] as String? ?? '';
  }
}

class DispatchException implements Exception {
  DispatchException(this.reason);
  final String reason;
  @override
  String toString() => 'DispatchException($reason)';
}
