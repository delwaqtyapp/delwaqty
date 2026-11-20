import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';

final supabaseNotificationDataSourceProvider =
    Provider<SupabaseNotificationDataSource>((ref) {
      return SupabaseNotificationDataSource(ref.watch(supabaseClientProvider));
    });

class SupabaseNotificationDataSource {
  SupabaseNotificationDataSource(this._client);
  final SupabaseClient _client;

  static const Map<String, NotificationType> _dbTypeMap = {
    'system': NotificationType.system,
    'order': NotificationType.order,
    'order_update': NotificationType.order,
    'delivery_update': NotificationType.order,
    'payment': NotificationType.payment,
    'promotion': NotificationType.promotion,
    'service': NotificationType.service,
    'ride_update': NotificationType.service,
    'account': NotificationType.account,
    'security': NotificationType.security,
    'message': NotificationType.message,
    'info': NotificationType.info,
    'warning': NotificationType.warning,
    'success': NotificationType.success,
    'reminder': NotificationType.reminder,
    'reward': NotificationType.reward,
    'chat_reply': NotificationType.chatReply,
    'chat_assigned': NotificationType.chatAssigned,
    'chat_escalated': NotificationType.chatEscalated,
    'chat_closed': NotificationType.chatClosed,
    'complaint': NotificationType.complaint,
    'complaint_note': NotificationType.complaintNote,
    'complaint_escalated': NotificationType.complaintEscalated,
    'complaint_assigned': NotificationType.complaintAssigned,
    'emergency': NotificationType.emergency,
    'emergency_alert': NotificationType.emergencyAlert,
    'emergency_resolved': NotificationType.emergencyResolved,
    'admin_management': NotificationType.adminManagement,
    'moderation': NotificationType.moderation,
    'approval': NotificationType.approval,
    'topup_approved': NotificationType.topupApproved,
    'admin_topup': NotificationType.adminTopup,
    'provider_profile': NotificationType.providerProfile,
  };

  NotificationType _parseNotificationType(String raw) {
    final mapped = _dbTypeMap[raw];
    if (mapped != null) return mapped;
    for (final t in NotificationType.values) {
      if (t.name == raw) return t;
    }
    return NotificationType.system;
  }

  AppNotification _fromRow(Map<String, dynamic> row) {
    final dataType = row['type'] as String? ?? 'system';
    final type = _parseNotificationType(dataType);

    final data = row['data'] as Map<String, dynamic>?;
    final deepLink =
        row['deep_link'] as String? ?? data?['deep_link'] as String?;
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
    if (limit <= 0) return const [];
    var query = _client.from('notifications').select();

    if (unreadOnly == true) {
      query = query.eq('is_read', false);
    }

    final fetchCount = ((offset + limit) * 3).clamp(20, 200);
    final data = await query
        .order('created_at', ascending: false)
        .range(0, fetchCount - 1);

    final filtered = (data as List)
        .cast<Map<String, dynamic>>()
        .where(
          (r) => NotificationChannels.isRowVisibleInContext(
            r,
            context: NotificationRouteResolver.appContext,
          ),
        )
        .toList();

    if (offset >= filtered.length) return const [];
    return filtered.skip(offset).take(limit).map(_fromRow).toList();
  }

  Future<int> getUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final rows = await _client
          .from('notifications')
          .select('id, type, deep_link, data')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .where(
            (r) => NotificationChannels.isRowVisibleInContext(
              r,
              context: NotificationRouteResolver.appContext,
            ),
          )
          .length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(String id) async {
    await _client
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final rows = await _client
        .from('notifications')
        .select('id, type, deep_link, data')
        .eq('user_id', userId)
        .eq('is_read', false);

    final matchingIds = (rows as List)
        .cast<Map<String, dynamic>>()
        .where(
          (r) => NotificationChannels.isRowVisibleInContext(
            r,
            context: NotificationRouteResolver.appContext,
          ),
        )
        .map((r) => r['id'] as String)
        .toList();

    if (matchingIds.isEmpty) return;

    await _client
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .inFilter('id', matchingIds);
  }

  Future<void> deleteNotification(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  Future<void> clearAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final rows = await _client
        .from('notifications')
        .select('id, type, deep_link, data')
        .eq('user_id', userId);

    final matchingIds = (rows as List)
        .cast<Map<String, dynamic>>()
        .where(
          (r) => NotificationChannels.isRowVisibleInContext(
            r,
            context: NotificationRouteResolver.appContext,
          ),
        )
        .map((r) => r['id'] as String)
        .toList();

    if (matchingIds.isEmpty) return;

    await _client
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .inFilter('id', matchingIds);
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
    await _client.rpc(
      'register_device_token',
      params: {
        'p_token': token,
        'p_platform': platform,
        'p_device_id': deviceId,
        'p_app_version': ?appVersion,
      },
    );
  }

  Future<void> refreshTokenHeartbeat({
    required String token,
    required String deviceId,
  }) async {
    await _client.rpc(
      'refresh_token_heartbeat',
      params: {'p_token': token, 'p_device_id': deviceId},
    );
  }

  Future<void> deactivateDeviceTokens(String deviceId) async {
    await _client.rpc(
      'deactivate_device_tokens',
      params: {'p_device_id': deviceId},
    );
  }
}
