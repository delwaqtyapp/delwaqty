import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/admin_router.dart';
import 'package:delwaqty/core/router/app_router.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart' as auth;
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/services/push_notification/push_notification_service.dart';
import 'package:delwaqty/services/realtime/realtime_service.dart';

/// Listens (app-wide, not just inside the room screen) for NEW incoming
/// voice-call messages on the user's accessible chat rooms.
///
/// Responsibilities:
///  * subscribe only once a real authenticated session exists (auth at app
///    startup may not be ready when the provider is first read);
///  * when a ringing call from the peer arrives while the app is NOT already
///    showing that room, navigate straight INTO the room so the in-room
///    incoming-call sheet (accept/decline) appears immediately;
///  * as a fallback, raise a local notification (tap deep-links into the room).
class ChatCallAlertService {
  ChatCallAlertService(this._ref, this._realtime, this._logger);

  final Ref _ref;
  final RealtimeService _realtime;
  final AppLogger _logger;

  bool _listening = false;
  bool _subscribed = false;
  ProviderSubscription<auth.AuthState>? _authSub;
  final Set<String> _handled = {};

  void start() {
    if (_listening) return;
    _listening = true;

    // Wait until a real authenticated session exists, then subscribe. At app
    // cold-start with an existing session Supabase restores it asynchronously,
    // so unconditionally subscribing with a null user would silently no-op.
    _authSub = _ref.listen(authStateProvider, (prev, next) {
      if (next is auth.AuthAuthenticated) {
        _ensureSubscribed(next.user.id);
      }
    });

    final initial = _ref.read(authStateProvider);
    if (initial is auth.AuthAuthenticated) {
      _ensureSubscribed(initial.user.id);
    }
  }

  void _ensureSubscribed(String meId) {
    if (_subscribed) {
      return;
    }
    _subscribed = true;

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
      if (id == null) return;
      if (_handled.contains(id)) return;
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

      _handled.add(id);
      if (_handled.length > 60) _handled.clear();

      final roomId = record['room_id'] as String? ?? '';

      // If this room is not already open, jump into it so the in-room
      // incoming-call sheet (accept/decline) is shown immediately.
      if (roomId.isNotEmpty && !_isRoomOpen(roomId)) {
        _openRoom(roomId);
        return;
      }

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

  bool _isRoomOpen(String roomId) {
    final adminCtx = adminNavigatorKey.currentContext;
    final appCtx = rootNavigatorKey.currentContext;
    final ctx = adminCtx ?? appCtx;
    if (ctx == null) return false;
    try {
      final uri = GoRouter.of(ctx).state.uri.path;
      return uri.contains(roomId);
    } catch (_) {
      return false;
    }
  }

  void _openRoom(String roomId) {
    final adminCtx = adminNavigatorKey.currentContext;
    final appCtx = rootNavigatorKey.currentContext;
    final ctx = adminCtx ?? appCtx;
    if (ctx == null) return;
    final isAdminPanel = _ref.read(isAdminAppProvider);
    final path = isAdminPanel
        ? '/admin/support-chat/room/$roomId'
        : '/support/room/$roomId';
    try {
      GoRouter.of(ctx).push(path);
    } catch (e) {
      _logger.e('ChatCallAlert failed to open room $roomId', e);
    }
  }

  void dispose() {
    _listening = false;
    _authSub?.close();
    _authSub = null;
    _handled.clear();
    if (_subscribed) {
      _subscribed = false;
      _realtime.unsubscribe('chat-call-alerts');
    }
  }
}