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
        _count('merchants'),
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
}