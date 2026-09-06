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
    final dataType = row['type'] as String? ?? 'system';
    final type = NotificationType.values.firstWhere(
      (t) => t.name == dataType,
      orElse: () => NotificationType.system,
    );

    final data = row['data'] as Map<String, dynamic>?;
    final deepLink = row['deep_link'] as String? ?? data?['deep_link'] as String?;
    final priority = NotificationPriority.values.firstWhere(
      (p) => p.name == (row['priority'] as String? ?? 'normal'),
      orElse: () => NotificationPriority.normal,
    );
    final pushStatus = NotificationPushStatus.values.firstWhere(
      (s) => s.name == (row['push_status'] as String? ?? 'pending'),
      orElse: () => NotificationPushStatus.pending,
    );

    return AppNotification(
      id: row['id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      type: type,
      isRead: row['is_read'] as bool? ?? false,
      deepLink: deepLink,
      idempotencyKey: row['idempotency_key'] as String?,
      readAt: row['read_at'] != null
          ? DateTime.tryParse(row['read_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
      priority: priority,
      senderId: row['sender_id'] as String?,
      pushStatus: pushStatus,
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
        .rpc('get_unread_notification_count', params: {'p_user_id': userId});

    return (data as int?) ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
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

  Future<bool> existsByIdempotencyKey(String key) async {
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('idempotency_key', key)
        .maybeSingle();
    return data != null;
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    required String deviceId,
    String? appVersion,
  }) async {
    await _client.rpc('register_device_token', params: {
      'p_token': token,
      'p_platform': platform,
      'p_device_id': deviceId,
      'p_app_version': ?appVersion,
    });
  }

  Future<void> refreshTokenHeartbeat({
    required String token,
    required String deviceId,
  }) async {
    await _client.rpc('refresh_token_heartbeat', params: {
      'p_token': token,
      'p_device_id': deviceId,
    });
  }

  Future<void> deactivateDeviceTokens(String deviceId) async {
    await _client.rpc('deactivate_device_tokens', params: {
      'p_device_id': deviceId,
    });
  }
}
