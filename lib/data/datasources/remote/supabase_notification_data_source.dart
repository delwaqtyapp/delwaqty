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
    'ota_update': NotificationType.otaUpdate,
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
    try {
      // RLS scopes rows to the caller; no client-side user filter.
      final rows = await _client
          .from('notifications')
          .select('id, type, deep_link, data, audience')
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

  /// Bulk operations page through the visible rows in small batches.
  ///
  /// The previous implementation fetched every id and sent them all in a
  /// single `in.(...)` filter. PostgREST caps a response at `max_rows`
  /// (1000) and, much sooner, the request URI itself exceeds server limits
  /// once a user has more than ~150 notifications, so "mark all read" and
  /// "delete all" failed silently on any well-used account. Batching keeps
  /// every request small and loops until nothing visible remains.
  static const int _bulkFetchBatchSize = 200;
  static const int _bulkMutationChunkSize = 50;

  /// Hard stop so a server that keeps returning the same rows cannot spin
  /// the loop forever (200 batches x 200 rows = 40k notifications).
  static const int _bulkMaxBatches = 200;

  List<String> _visibleIds(List<dynamic> rows) {
    return rows
        .cast<Map<String, dynamic>>()
        .where(
          (r) => NotificationChannels.isRowVisibleInContext(
            r,
            context: NotificationRouteResolver.appContext,
          ),
        )
        .map((r) => r['id'] as String)
        .toList();
  }

  Future<List<dynamic>> _fetchBulkBatch({required bool unreadOnly}) {
    var query = _client
        .from('notifications')
        .select('id, type, deep_link, data, audience');
    if (unreadOnly) {
      query = query.eq('is_read', false);
    }
    // RLS scopes every row to the caller, so no client-side user filter is
    // needed (and depending on auth.currentUser here made the whole action
    // a silent no-op while the session was still restoring).
    return query
        .order('created_at', ascending: false)
        .range(0, _bulkFetchBatchSize - 1);
  }

  Future<void> markAllAsRead() async {
    for (var batch = 0; batch < _bulkMaxBatches; batch++) {
      final rows = await _fetchBulkBatch(unreadOnly: true);
      final matchingIds = _visibleIds(rows);
      if (matchingIds.isEmpty) return;

      final readAt = DateTime.now().toUtc().toIso8601String();
      for (var i = 0; i < matchingIds.length; i += _bulkMutationChunkSize) {
        final chunk = matchingIds.sublist(
          i,
          i + _bulkMutationChunkSize > matchingIds.length
              ? matchingIds.length
              : i + _bulkMutationChunkSize,
        );
        await _client
            .from('notifications')
            .update({'is_read': true, 'read_at': readAt})
            .eq('is_read', false)
            .inFilter('id', chunk);
      }
      // Marked rows no longer match `is_read = false`, so the next batch
      // moves forward; an empty visible set ends the loop.
    }
    throw StateError(
      'markAllAsRead exceeded the safety limit of $_bulkMaxBatches batches',
    );
  }

  Future<void> deleteNotification(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  Future<void> clearAll() async {
    for (var batch = 0; batch < _bulkMaxBatches; batch++) {
      final rows = await _fetchBulkBatch(unreadOnly: false);
      final matchingIds = _visibleIds(rows);
      if (matchingIds.isEmpty) return;

      for (var i = 0; i < matchingIds.length; i += _bulkMutationChunkSize) {
        final chunk = matchingIds.sublist(
          i,
          i + _bulkMutationChunkSize > matchingIds.length
              ? matchingIds.length
              : i + _bulkMutationChunkSize,
        );
        await _client.from('notifications').delete().inFilter('id', chunk);
      }
      // Deleted rows disappear from the next fetch, so the loop advances
      // until nothing visible remains.
    }
    throw StateError(
      'clearAll exceeded the safety limit of $_bulkMaxBatches batches',
    );
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
