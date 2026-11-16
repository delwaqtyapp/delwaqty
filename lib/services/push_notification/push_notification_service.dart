import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/active_navigator.dart';
import 'package:delwaqty/core/router/admin_router.dart';
import 'package:delwaqty/driver/app_router.dart';
import 'package:delwaqty/provider/app_router.dart';
import 'package:delwaqty/core/router/app_router.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/services/push_notification/device_identity.dart';
import 'package:delwaqty/services/realtime/realtime_channel_constants.dart';
import 'package:delwaqty/services/realtime/realtime_service.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(
    ref,
    ref.watch(loggerProvider),
    ref.watch(realtimeServiceProvider),
  );
});

const _notificationChannelId = 'delwaqty_notifications';
const _notificationChannelName = 'Delwaqty Notifications';
const _notificationChannelDescription =
    'Order updates, delivery tracking and service alerts';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
  await _initLocalNotifications();
  await _showNotification(message);
}

Future<void> _initLocalNotifications() async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _localNotifications.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (details) {
      if (details.payload == null) return;
      try {
        final data = jsonDecode(details.payload!) as Map<String, dynamic>;
        _handleNotificationTap(data);
      } catch (_) {}
    },
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _notificationChannelId,
          _notificationChannelName,
          description: _notificationChannelDescription,
          importance: Importance.high,
        ),
      );
}

Future<void> _showNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;
  await _showLocalNotification(
    title: notification.title,
    body: notification.body,
    payload: jsonEncode(message.data),
  );
}

Future<void> _showLocalNotification({
  String? title,
  String? body,
  String? payload,
}) async {
  if (title == null && body == null) return;
  await _localNotifications.show(
    id: (title ?? body).hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: _notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: payload,
  );
}

/// Raised app-wide when a NEW incoming voice-call message arrives on any of the
/// current user's rooms (used by ChatCallAlertService). The notification tap
/// deep-links into that chat room.
Future<void> showChatCallNotification({
  required String roomId,
  required String callerLabel,
  required String message,
  String? title,
  String? body,
}) async {
  try {
    await _initLocalNotifications();
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title ?? 'Incoming voice call',
      body:
          body ??
          '$callerLabel — ${message.isEmpty ? 'Tap to answer' : message}',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          _notificationChannelName,
          channelDescription: _notificationChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode({'chat_room_id': roomId}),
    );
  } catch (e) {
    debugPrint('Failed to show chat call notification: $e');
  }
}

void _handleNotificationTap(Map<String, dynamic> data) {
  final chatRoomId = data['chat_room_id'] as String?;
  if (chatRoomId != null && chatRoomId.isNotEmpty) {
    // Resolve the ACTIVE flavor navigator: rootNavigatorKey only exists
    // in the customer app, so notification taps were dead in admin,
    // driver and provider.
    final anyContext = rootNavigatorKey.currentContext ??
        adminNavigatorKey.currentContext ??
        driverRootNavigatorKey.currentContext ??
        providerRootNavigatorKey.currentContext;
    if (anyContext == null) return;
    final flavor =
        ProviderScope.containerOf(anyContext).read(appFlavorProvider);
    final context = activeNavigatorContext(flavor);
    if (context == null) return;
    final isAdminPanel =
        ProviderScope.containerOf(context).read(isAdminAppProvider);
    final path = isAdminPanel
        ? '/admin/support-chat/room/$chatRoomId'
        : '/support/room/$chatRoomId';
    GoRouter.of(context).push(path);
    return;
  }

  final payload = NotificationPayload.fromMap(data);
  final deepLink = NotificationRouteResolver.safePayload(payload);
  final anyContext = rootNavigatorKey.currentContext ??
      adminNavigatorKey.currentContext ??
      driverRootNavigatorKey.currentContext ??
      providerRootNavigatorKey.currentContext;
  if (anyContext == null) return;

  final flavor = ProviderScope.containerOf(anyContext).read(appFlavorProvider);
  final activeContext = activeNavigatorContext(flavor);
  if (activeContext == null) return;
  final context = activeContext;
  final router = GoRouter.of(context);
  router.push(deepLink);

  if (payload.notificationId != null) {
    _markNotificationRead(payload.notificationId!, context: context);
  }
}

Future<void> _markNotificationRead(
  String notificationId, {
  BuildContext? context,
}) async {
  try {
    final client = Supabase.instance.client;
    await client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
    if (context != null && context.mounted) {
      final container = ProviderScope.containerOf(context);
      container.invalidate(unreadCountProvider);
      container.invalidate(unreadCountStreamProvider);
      container.invalidate(notificationsProvider);
    }
  } catch (e) {
    debugPrint('Failed to mark notification read: $e');
  }
}

class PushNotificationService {
  PushNotificationService(this._ref, this._logger, this._realtime);

  final Ref _ref;
  final AppLogger _logger;
  final RealtimeService _realtime;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _lastToken;
  String? _deviceId;
  Timer? _heartbeat;
  bool _localAndFcmReady = false;
  String? _boundUserId;

  void Function(Map<String, dynamic> record)? onRealtimeNotification;

  Future<void> initialize() async {
    try {
      if (!_localAndFcmReady) {
        await _initLocalNotifications();
        _deviceId ??= await DeviceIdentity.getOrCreate();

        final settings = await _messaging.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          _lastToken = await _messaging.getToken();

          _messaging.onTokenRefresh.listen((token) {
            _lastToken = token;
            _saveToken(token);
          });

          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
          FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

          final initialMessage = await _messaging.getInitialMessage();
          if (initialMessage != null) {
            _handleBackgroundMessage(initialMessage);
          }
        } else {
          _logger.i('Push notification permission denied');
        }

        _localAndFcmReady = true;
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && _boundUserId != currentUser.id) {
        _setupRealtimeNotifications();

        final token = _lastToken ?? await _messaging.getToken();
        if (token != null) {
          _lastToken = token;
          await _saveToken(token);
        }

        _startHeartbeat();
        _boundUserId = currentUser.id;
        _logger.i('Push notifications bound to user ${currentUser.id}');
      }
    } catch (e) {
      _logger.e('Failed to initialize push notifications', e);
    }
  }

  void _setupRealtimeNotifications() {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      _realtime.unsubscribe(RealtimeChannels.inAppNotifications);

      _realtime.subscribe(
        channelName: RealtimeChannels.inAppNotifications,
        opts: [
          RealtimeChannelFilter(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final record = payload.newRecord;
              final title = record['title'] as String?;
              final body = record['body'] as String?;
              if (title == null && body == null) return;

              final recordUserId = record['user_id'] as String?;
              final isOwn = recordUserId == userId;
              if (!isOwn) return;

              _logger.i('Realtime notification: $title');
              final notificationPayload = jsonEncode({
                if (record['id'] != null) 'notification_id': record['id'],
                if (record['type'] != null) 'type': record['type'],
                if (record['deep_link'] != null)
                  'deep_link': record['deep_link'],
              });
              _showLocalNotification(
                title: title,
                body: body,
                payload: notificationPayload,
              );
              _ref.invalidate(unreadCountProvider);
              _ref.invalidate(unreadCountStreamProvider);
              _ref.invalidate(notificationsProvider);
              onRealtimeNotification?.call(record);
            },
          ),
        ],
        onError: (msg) => _logger.e('Notification channel error: $msg'),
      );
    } catch (e) {
      _logger.e('Failed to setup realtime notifications', e);
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      final deviceId = _deviceId ?? await DeviceIdentity.getOrCreate();
      _deviceId = deviceId;

      await client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': _platformName(),
        'p_device_id': deviceId,
      });

      _logger.i('Push notification token saved');
    } catch (e) {
      _logger.e('Failed to save push token', e);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) async {
      final token = _lastToken;
      if (token == null) return;
      try {
        final client = Supabase.instance.client;
        final deviceId = _deviceId ?? await DeviceIdentity.getOrCreate();
        _deviceId = deviceId;
        await client.rpc('refresh_token_heartbeat', params: {
          'p_token': token,
          'p_device_id': deviceId,
        });
      } catch (e) {
        _logger.e('Failed to refresh push heartbeat', e);
      }
    });
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'android';
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _logger.i('Foreground message: ${message.notification?.title}');
    _showNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    _logger.i('Opened message: ${message.notification?.title}');
    final payload = NotificationPayload.fromMap(message.data);
    final deepLink = NotificationRouteResolver.safePayload(payload);

    final anyCtx = rootNavigatorKey.currentContext ??
        adminNavigatorKey.currentContext ??
        driverRootNavigatorKey.currentContext ??
        providerRootNavigatorKey.currentContext;
    BuildContext? navContext;
    if (anyCtx != null) {
      final flavor = ProviderScope.containerOf(anyCtx).read(appFlavorProvider);
      navContext = activeNavigatorContext(flavor);
      if (navContext == null) return;
      GoRouter.of(navContext).push(deepLink);
    }

    if (payload.notificationId != null) {
      _markNotificationRead(payload.notificationId!, context: navContext);
    }
  }

  Future<void> deactivateTokensOnLogout() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        final deviceId = _deviceId ?? await DeviceIdentity.getOrCreate();
        _deviceId = deviceId;
        await client.rpc('deactivate_device_tokens', params: {
          'p_device_id': deviceId,
        });
      }

      _heartbeat?.cancel();
      _heartbeat = null;
      await _realtime.unsubscribeAll();
      _lastToken = null;
      _boundUserId = null;

      _logger.i('Tokens deactivated on logout');
    } catch (e) {
      _logger.e('Failed to deactivate tokens on logout', e);
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      _logger.e('Failed to subscribe to topic: $topic', e);
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      _logger.e('Failed to unsubscribe from topic: $topic', e);
    }
  }

  void dispose() {
    _heartbeat?.cancel();
  }
}
