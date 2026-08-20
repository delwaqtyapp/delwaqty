import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/location_tracking/domain/entities/location_update.dart';

class SupabaseLocationDataSource {
  final SupabaseClient _client;

  SupabaseLocationDataSource(this._client);

  Future<List<LocationUpdate>> getUserLocations(String userId, {int limit = 50}) async {
    final rows = await _client
        .from('location_updates')
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .limit(limit);
    return rows.map((r) => LocationUpdate.fromJson(r)).toList();
  }

  Future<List<LocationUpdate>> getActiveDrivers() async {
    final sixHoursAgo = DateTime.now().subtract(const Duration(hours: 6)).toIso8601String();
    final rows = await _client
        .from('location_updates')
        .select()
        .gte('recorded_at', sixHoursAgo)
        .eq('is_moving', true)
        .order('recorded_at', ascending: false);
    return rows.map((r) => LocationUpdate.fromJson(r)).toList();
  }

  Future<LocationUpdate?> getLatestLocation(String userId) async {
    final rows = await _client
        .from('location_updates')
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return LocationUpdate.fromJson(rows.first);
  }

  Future<void> upsertLocation(LocationUpdate location) async {
    await _client.from('location_updates').insert(location.toJson());
  }

  Stream<LocationUpdate> locationStream(String userId) {
    return _client
        .from('location_updates')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.map((r) => LocationUpdate.fromJson(r)).toList())
        .expand((list) => list);
  }
}
