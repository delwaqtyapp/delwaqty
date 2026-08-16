import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/data/datasources/remote/supabase_notification_data_source.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient httpClient;
  late SupabaseClient supabase;
  late SupabaseNotificationDataSource dataSource;
  late http.Request? capturedRequest;
  List<Map<String, dynamic>> rows = [];

  setUpAll(() {
    registerFallbackValue(http.Request('GET', Uri.parse('https://x')));
  });

  setUp(() {
    httpClient = MockHttpClient();
    supabase = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: httpClient,
    );
    dataSource = SupabaseNotificationDataSource(supabase);
    capturedRequest = null;
    rows = [];

    when(() => httpClient.send(any())).thenAnswer((invocation) async {
      final request = invocation.positionalArguments[0] as http.Request;
      capturedRequest = request;
      final Object body = request.method == 'POST' ? true : rows;
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: request,
      );
    });
  });

  group('SupabaseNotificationDataSource RPCs', () {
    test('registerDeviceToken issues the RPC with device-scoped params',
        () async {
      await dataSource.registerDeviceToken(
        token: 'fcm-token-1',
        platform: 'android',
        deviceId: 'dev-1',
        appVersion: '1.2.0',
      );

      expect(capturedRequest, isNotNull);
      expect(
        capturedRequest!.url.path,
        '/rest/v1/rpc/register_device_token',
      );
      final body =
          jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['p_token'], 'fcm-token-1');
      expect(body['p_platform'], 'android');
      expect(body['p_device_id'], 'dev-1');
      expect(body['p_app_version'], '1.2.0');
    });

    test('registerDeviceToken omits app version when null', () async {
      await dataSource.registerDeviceToken(
        token: 'fcm-token-2',
        platform: 'ios',
        deviceId: 'dev-2',
      );

      final body =
          jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body.containsKey('p_app_version'), isFalse);
    });

    test('refreshTokenHeartbeat issues the RPC', () async {
      await dataSource.refreshTokenHeartbeat(token: 't1', deviceId: 'dev-1');

      expect(
        capturedRequest!.url.path,
        '/rest/v1/rpc/refresh_token_heartbeat',
      );
      final body =
          jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['p_token'], 't1');
      expect(body['p_device_id'], 'dev-1');
    });

    test('deactivateDeviceTokens issues the RPC for the current device',
        () async {
      await dataSource.deactivateDeviceTokens('dev-1');

      expect(
        capturedRequest!.url.path,
        '/rest/v1/rpc/deactivate_device_tokens',
      );
      final body =
          jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['p_device_id'], 'dev-1');
    });
  });

  group('SupabaseNotificationDataSource row mapping', () {
    test('maps priority, sender_id and push_status from rows', () async {
      rows.add({
        'id': 'n1',
        'title': 'SOS',
        'body': 'Emergency',
        'type': 'security',
        'is_read': false,
        'priority': 'high',
        'sender_id': 'admin-1',
        'push_status': 'failed',
        'created_at': '2026-08-15T00:00:00.000Z',
      });

      final notifications = await dataSource.getNotifications();

      expect(notifications, hasLength(1));
      final n = notifications.single;
      expect(n.priority, NotificationPriority.high);
      expect(n.senderId, 'admin-1');
      expect(n.pushStatus, NotificationPushStatus.failed);
    });

    test('defaults priority and push status when absent', () async {
      rows.add({
        'id': 'n1',
        'title': 'Title',
        'body': 'Body',
        'type': 'system',
        'is_read': false,
        'created_at': '2026-08-15T00:00:00.000Z',
      });

      final notifications = await dataSource.getNotifications();

      final n = notifications.single;
      expect(n.priority, NotificationPriority.normal);
      expect(n.pushStatus, NotificationPushStatus.pending);
    });
  });
}
