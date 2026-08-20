import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/order_tracking.dart';

final supabaseOrderTrackingDataSourceProvider =
    Provider<SupabaseOrderTrackingDataSource>((ref) {
      return SupabaseOrderTrackingDataSource(ref.watch(supabaseClientProvider));
    });

class SupabaseOrderTrackingDataSource {
  SupabaseOrderTrackingDataSource(this._client);
  final SupabaseClient _client;

  OrderTracking _fromRow(Map<String, dynamic> row) => OrderTracking(
    id: row['id'] as String,
    orderId: row['order_id'] as String,
    status: row['status'] as String,
    estimatedMinutes: row['estimated_minutes'] as int?,
    notes: row['notes'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  Future<List<OrderTracking>> getTracking(String orderId) async {
    final data = await _client
        .from('order_tracking')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<OrderTracking> addTracking(OrderTracking tracking) async {
    final data = await _client
        .from('order_tracking')
        .insert({
          'order_id': tracking.orderId,
          'status': tracking.status,
          'estimated_minutes': tracking.estimatedMinutes,
          'notes': tracking.notes,
        })
        .select()
        .single();
    return _fromRow(data);
  }

  Future<OrderTracking?> getLatestTracking(String orderId) async {
    final data = await _client
        .from('order_tracking')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data != null ? _fromRow(data) : null;
  }
}
