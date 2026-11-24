import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/domain/repositories/notification_repository.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';

final supabaseNotificationDataSourceProvider =
    Provider<SupabaseNotificationDataSource>((ref) {
      return SupabaseNotificationDataSource(ref.watch(supabaseClientProvider));
    });

class SupabaseNotificationDataSource {
  SupabaseNotificationDataSource(
    this._client, {
    String? Function()? currentUserId,
    this.sessionRetryCount = 5,
    this.sessionRetryDelay = const Duration(milliseconds: 150),
  }) : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);
  final SupabaseClient _client;
  final String? Function() _currentUserId;
  final int sessionRetryCount;
  final Duration sessionRetryDelay;

  /// RLS on notifications is NOT owner-only: admin policies
  /// ('Admins can select/delete notifications') let an admin read and
  /// delete other members' rows in their scope. Every query in this
  /// class - reads AND mutations - therefore carries an explicit
  /// .eq('user_id', currentUserId) filter, so an admin using the app can
  /// never bulk-touch another member's notifications.
  ///
  /// When the session is still restoring, currentUser can be null; in
  /// that case we wait briefly for auth and then throw. We never run a
  /// query without the user filter.
  Future<String> _requireUserId() async {
    for (var attempt = 0; attempt < sessionRetryCount; attempt++) {
      final id = _currentUserId();
      if (id != null && id.isNotEmpty) return id;
      if (attempt + 1 < sessionRetryCount) {
        await Future<void>.delayed(sessionRetryDelay);
      }
    }
    throw StateError(
      'notifications: no signed-in user; refusing to run an unscoped query',
    );
  }

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
    final userId = await _requireUserId();
    var query = _client.from('notifications').select().eq('user_id', userId);

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
      final userId = await _requireUserId();
      final rows = await _client
          .from('notifications')
          .select('id, type, deep_link, data, audience')
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
    final userId = await _requireUserId();
    await _client
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId);
  }

  /// Bulk operations (mark-all-read / clear-all).
  ///
  /// The very first implementation fetched every id and sent them all in
  /// a single `in.(...)` filter, which broke past ~150 notifications
  /// (request URI limits, then PostgREST max-rows). The next one paged a
  /// 200-row window from offset 0 and filtered the app context in Dart,
  /// which broke differently: a window full of rows from other app
  /// contexts looked like "nothing to do" while visible rows sat behind
  /// the barrier.
  ///
  /// This version uses scan-then-mutate: it first pages through the
  /// caller's rows WITHOUT mutating them (offset paging is stable on an
  /// unmutated set, and hidden rows of other contexts can no longer form
  /// a barrier), collecting the ids visible in this app context; then it
  /// mutates the collected ids in small in-filter chunks. The round
  /// repeats until a scan collects nothing visible, which also catches
  /// rows inserted while the operation was running.
  static const int _bulkFetchBatchSize = 200;
  static const int _bulkMutationChunkSize = 50;

  /// Hard caps so a server that keeps returning rows cannot spin the
  /// loop forever (200 fetch batches x 200 rows = 40k notifications
  /// scanned; at most 20 scan rounds). Reaching a cap returns a
  /// structured limit result - it never throws after partial work.
  static const int _bulkMaxBatches = 200;
  static const int _bulkMaxRounds = 20;

  Future<BulkNotificationResult> _bulkVisible({
    required String userId,
    required bool unreadOnly,
    required Future<void> Function(List<String> chunk) mutateChunk,
  }) async {
    var processed = 0;
    var batches = 0;
    try {
      for (var round = 0; round < _bulkMaxRounds; round++) {
        // Phase 1: scan without mutating; offset paging is consistent on
        // this static set.
        final visibleIds = <String>[];
        var offset = 0;
        while (true) {
          if (++batches > _bulkMaxBatches) {
            return BulkNotificationResult(
              completed: false,
              processed: processed,
              limitReached: true,
            );
          }
          var query = _client
              .from('notifications')
              .select('id, type, deep_link, data, audience')
              .eq('user_id', userId);
          if (unreadOnly) {
            query = query.eq('is_read', false);
          }
          final rows = await query
              // Deterministic order: created_at alone ties, and a tie
              // spanning a page boundary could skip or repeat a row.
              .order('created_at', ascending: false)
              .order('id', ascending: false)
              .range(offset, offset + _bulkFetchBatchSize - 1);
          final list = (rows as List).cast<Map<String, dynamic>>();
          for (final r in list) {
            if (NotificationChannels.isRowVisibleInContext(
              r,
              context: NotificationRouteResolver.appContext,
            )) {
              visibleIds.add(r['id'] as String);
            }
          }
          if (list.length < _bulkFetchBatchSize) break;
          offset += _bulkFetchBatchSize;
        }

        if (visibleIds.isEmpty) {
          return BulkNotificationResult(completed: true, processed: processed);
        }

        // Phase 2: mutate the collected ids in bounded chunks. The user
        // filter rides along as defense in depth on top of the RLS
        // policies (which are not owner-only for admins).
        for (var i = 0; i < visibleIds.length; i += _bulkMutationChunkSize) {
          final chunk = visibleIds.sublist(
            i,
            i + _bulkMutationChunkSize > visibleIds.length
                ? visibleIds.length
                : i + _bulkMutationChunkSize,
          );
          await mutateChunk(chunk);
          processed += chunk.length;
        }
        // Next round re-scans from the top; rows handled above no longer
        // match, so a clean round ends the loop.
      }
      return BulkNotificationResult(
        completed: false,
        processed: processed,
        limitReached: true,
      );
    } catch (e) {
      // Partial failure: report how far we got so callers can reload
      // instead of trusting their optimistic local state.
      return BulkNotificationResult(
        completed: false,
        processed: processed,
        error: e,
      );
    }
  }

  Future<BulkNotificationResult> markAllAsRead() async {
    final userId = await _requireUserId();
    final readAt = DateTime.now().toUtc().toIso8601String();
    return _bulkVisible(
      userId: userId,
      unreadOnly: true,
      mutateChunk: (chunk) => _client
          .from('notifications')
          .update({'is_read': true, 'read_at': readAt})
          .eq('user_id', userId)
          .eq('is_read', false)
          .inFilter('id', chunk),
    );
  }

  Future<void> deleteNotification(String id) async {
    final userId = await _requireUserId();
    await _client
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<BulkNotificationResult> clearAll() async {
    final userId = await _requireUserId();
    return _bulkVisible(
      userId: userId,
      unreadOnly: false,
      mutateChunk: (chunk) => _client
          .from('notifications')
          .delete()
          .eq('user_id', userId)
          .inFilter('id', chunk),
    );
  }

  Future<bool> existsByIdempotencyKey(String key) async {
    final userId = await _requireUserId();
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
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
