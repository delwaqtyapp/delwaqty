import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_overview.dart';

class AdminOverviewDataSource {
  AdminOverviewDataSource({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<AdminOverviewStats> fetchStats() async {
    try {
      final results = await Future.wait([
        _count('users'),
        _merchantCount(),
        _count('orders'),
        _count('drivers'),
        _count('service_bookings'),
      ]);
      return AdminOverviewStats(
        users: results[0],
        merchants: results[1],
        orders: results[2],
        drivers: results[3],
        serviceBookings: results[4],
      );
    } catch (e) {
      throw Exception('Failed to load overview stats: $e');
    }
  }

  Future<int> _count(String table) async {
    final response = await _supabase.from(table).select().count();
    return response.count;
  }

  Future<int> _merchantCount() async {
    // 449 app switch: base-table SELECT on merchants is 450 territory.
    // admin_dashboard_metrics is ANALYTICS_VIEW-gated and returns ZEROS
    // without it (372), so admins lacking the permission fall back to the
    // scope-aware listing count: the number is always real, never a
    // silent 0.
    final allowed = await _supabase.rpc(
      'admin_has_permission',
      params: {'p_permission': 'ANALYTICS_VIEW'},
    );
    if (allowed == true) {
      final metrics = await _supabase.rpc('admin_dashboard_metrics') as Map;
      return (metrics['totalMerchants'] as num?)?.toInt() ?? 0;
    }
    final rows = await _supabase.rpc(
      'admin_list_merchants',
      params: {'p_search': null, 'p_status': null},
    );
    return (rows as List).length;
  }
}
