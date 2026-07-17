import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';

final supabaseNotificationDataSourceProvider =
    Provider<SupabaseNotificationDataSource>((ref) {
      return SupabaseNotificationDataSource(ref.watch(supabaseClientProvider));
    });

class SupabaseNotificationDataSource {
  SupabaseNotificationDataSource(this._client);
  final SupabaseClient _client;

  AppNotification _fromRow(Map<String, dynamic> row) {
    final dataType = row['type'] as String? ?? 'info';
    final type = NotificationType.values.firstWhere(
      (t) => t.name == dataType,
      orElse: () => NotificationType.info,
    );

    final data = row['data'] as Map<String, dynamic>?;
    final deepLink = data?['deep_link'] as String?;

    return AppNotification(
      id: row['id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      type: type,
      isRead: row['is_read'] as bool? ?? false,
      deepLink: deepLink,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<List<AppNotification>> getNotifications({
    bool? unreadOnly,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client.from('notifications').select();

    if (unreadOnly == true) {
      query = query.eq('is_read', false);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final data = await _client
        .from('notifications')
        .select('id')
        .eq('is_read', false)
        .eq('user_id', userId);

    return (data as List).length;
  }

  Future<void> markAsRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  Future<void> clearAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('notifications').delete().eq('user_id', userId);
  }
}
