import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/restaurant/domain/entities/working_hours.dart';

final supabaseWorkingHoursDataSourceProvider = Provider<SupabaseWorkingHoursDataSource>((ref) {
  return SupabaseWorkingHoursDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseWorkingHoursDataSource {
  SupabaseWorkingHoursDataSource(this._client);
  final SupabaseClient _client;

  WorkingHours _fromRow(Map<String, dynamic> row) => WorkingHours(
    id: row['id'] as String,
    merchantId: row['merchant_id'] as String,
    branchId: row['branch_id'] as String?,
    dayOfWeek: row['day_of_week'] as int,
    openTime: row['open_time'] as String,
    closeTime: row['close_time'] as String,
    isClosed: row['is_closed'] as bool? ?? false,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  Future<List<WorkingHours>> getHours(String merchantId, {String? branchId}) async {
    var query = _client.from('working_hours').select().eq('merchant_id', merchantId);
    if (branchId != null) query = query.eq('branch_id', branchId);
    final data = await query.order('day_of_week');
    return (data as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> setHours(List<WorkingHours> hours) async {
    if (hours.isEmpty) return;
    final merchantId = hours.first.merchantId;
    await _client.from('working_hours').delete().eq('merchant_id', merchantId);
    await _client.from('working_hours').insert(hours.map((h) => {
      'merchant_id': h.merchantId,
      'branch_id': h.branchId,
      'day_of_week': h.dayOfWeek,
      'open_time': h.openTime,
      'close_time': h.closeTime,
      'is_closed': h.isClosed,
    }).toList());
  }

  Future<void> deleteHours(String merchantId, {String? branchId}) async {
    var query = _client.from('working_hours').delete().eq('merchant_id', merchantId);
    if (branchId != null) query = query.eq('branch_id', branchId);
    await query;
  }
}
