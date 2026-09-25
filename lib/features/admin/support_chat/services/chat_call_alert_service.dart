import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/services/push_notification/push_notification_service.dart';
import 'package:delwaqty/services/realtime/realtime_service.dart';

/// Listens (app-wide, not just inside the room page) for NEW incoming voice-call
/// messages on the user's accessible chat rooms and raises a local
/// notification so the admin/customer is alerted even when they are NOT on the
/// open room screen. Tapping the notification deep-links into that room.
class ChatCallAlertService {
  ChatCallAlertService(this._ref, this._realtime, this._logger);

  final Ref _ref;
  final RealtimeService _realtime;
  final AppLogger _logger;

  bool _started = false;
  final Set<String> _notified = {};

  void start() {
    if (_started) return;
    _started = true;

    final client = Supabase.instance.client;
    final meId = client.auth.currentUser?.id;
    if (meId == null) {
      _logger.w('ChatCallAlertService: no auth user, skipping');
      return;
    }

    _realtime.subscribe(
      channelName: 'chat-call-alerts',
      opts: [
        RealtimeChannelFilter(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: const PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'message_type',
            value: 'call',
          ),
          callback: (payload) {
            _onCallInserted(payload.newRecord, meId);
          },
        ),
      ],
      onError: (msg) => _logger.e('ChatCallAlert channel error: $msg'),
    );
  }

  Future<void> _onCallInserted(
    Map<String, dynamic> record,
    String meId,
  ) async {
    try {
      final id = record['id'] as String?;
      if (id == null || _notified.contains(id)) return;
      final senderId = record['sender_id'] as String?;
      if (senderId == null || senderId == meId) return;

      final meta = record['meta_data'];
      final status =
          (meta is Map ? meta['status'] : null) as String? ?? 'ringing';
      if (status != 'ringing') return;

      // Respect the receiver's personal "receive incoming calls" switch.
      final repo = _ref.read(chatRepositoryProvider);
      final canReceive = await repo.canReceiveCalls(meId);
      if (!canReceive) return;

      _notified.add(id);

      final roomId = record['room_id'] as String? ?? '';
      // Also dismiss old entries after a while.
      if (_notified.length > 40) _notified.clear();

      final senderType = record['sender_type'] as String? ?? 'customer';
      final isAdminSender = senderType == 'admin';

      await showChatCallNotification(
        roomId: roomId,
        callerLabel: isAdminSender ? 'الإدارة' : 'عميل',
        message: record['message'] as String? ?? '',
      );
    } catch (e) {
      _logger.e('ChatCallAlert failed to notify', e);
    }
  }

  void dispose() {
    _started = false;
    _notified.clear();
    _realtime.unsubscribe('chat-call-alerts');
  }
}