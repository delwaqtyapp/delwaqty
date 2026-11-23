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
    test(
      'registerDeviceToken issues the RPC with device-scoped params',
      () async {
        await dataSource.registerDeviceToken(
          token: 'fcm-token-1',
          platform: 'android',
          deviceId: 'dev-1',
          appVersion: '1.2.0',
        );

        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.url.path, '/rest/v1/rpc/register_device_token');
        final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(body['p_token'], 'fcm-token-1');
        expect(body['p_platform'], 'android');
        expect(body['p_device_id'], 'dev-1');
        expect(body['p_app_version'], '1.2.0');
      },
    );

    test('registerDeviceToken omits app version when null', () async {
      await dataSource.registerDeviceToken(
        token: 'fcm-token-2',
        platform: 'ios',
        deviceId: 'dev-2',
      );

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body.containsKey('p_app_version'), isFalse);
    });

    test('refreshTokenHeartbeat issues the RPC', () async {
      await dataSource.refreshTokenHeartbeat(token: 't1', deviceId: 'dev-1');

      expect(capturedRequest!.url.path, '/rest/v1/rpc/refresh_token_heartbeat');
      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['p_token'], 't1');
      expect(body['p_device_id'], 'dev-1');
    });

    test(
      'deactivateDeviceTokens issues the RPC for the current device',
      () async {
        await dataSource.deactivateDeviceTokens('dev-1');

        expect(
          capturedRequest!.url.path,
          '/rest/v1/rpc/deactivate_device_tokens',
        );
        final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(body['p_device_id'], 'dev-1');
      },
    );
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

    test('maps ota_update rows to NotificationType.otaUpdate (#48)', () async {
      rows.add({
        'id': 'n-ota-1',
        'title': 'Update available',
        'body': '1.0.5 is ready',
        'type': 'ota_update',
        'deep_link': '/settings/about',
        'is_read': false,
        'created_at': '2026-11-22T00:00:00.000Z',
      });

      final notifications = await dataSource.getNotifications();

      expect(notifications, hasLength(1));
      expect(notifications.single.type, NotificationType.otaUpdate);
      expect(notifications.single.deepLink, '/settings/about');
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

  group('bulk operations', () {
    late List<Map<String, dynamic>> serverRows;
    late List<Uri> patchCalls;
    late List<Uri> deleteCalls;

    Set<String> parseInFilter(Uri uri) {
      final raw = uri.queryParameters['id'] ?? '';
      final inner = raw.replaceAll(RegExp(r'^in\.\(|\)$'), '');
      return inner
          .split(',')
          .map((v) => v.trim().replaceAll(RegExp(r'^"|"$'), ''))
          .where((v) => v.isNotEmpty)
          .toSet();
    }

    Map<String, dynamic> unreadRow(
      String id, {
      String type = 'system',
      String audience = 'customer',
    }) => {
      'id': id,
      'type': type,
      'deep_link': null,
      'data': null,
      'audience': audience,
      'is_read': false,
    };

    setUp(() {
      serverRows = [];
      patchCalls = [];
      deleteCalls = [];

      when(() => httpClient.send(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as http.Request;
        final uri = request.url;
        Object body;
        if (request.method == 'GET') {
          Iterable<Map<String, dynamic>> result = serverRows;
          if (uri.queryParameters['is_read'] == 'eq.false') {
            result = result.where((r) => r['is_read'] == false);
          }
          final offset =
              int.tryParse(uri.queryParameters['offset'] ?? '') ?? 0;
          final limit = int.tryParse(uri.queryParameters['limit'] ?? '');
          result = result.skip(offset);
          if (limit != null) result = result.take(limit);
          body = result.toList();
        } else if (request.method == 'PATCH') {
          patchCalls.add(uri);
          final ids = parseInFilter(uri);
          for (final row in serverRows) {
            if (ids.contains(row['id'])) row['is_read'] = true;
          }
          body = <Map<String, dynamic>>[];
        } else if (request.method == 'DELETE') {
          deleteCalls.add(uri);
          final ids = parseInFilter(uri);
          serverRows.removeWhere((r) => ids.contains(r['id']));
          body = <Map<String, dynamic>>[];
        } else {
          body = true;
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(body))),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      });
    });

    test('markAllAsRead marks every unread row across fetch batches', () async {
      for (var i = 0; i < 250; i++) {
        serverRows.add(unreadRow('n-$i'));
      }

      await dataSource.markAllAsRead();

      expect(serverRows.every((r) => r['is_read'] == true), isTrue);
      expect(patchCalls, isNotEmpty);
      for (final call in patchCalls) {
        expect(
          parseInFilter(call).length,
          lessThanOrEqualTo(50),
          reason: 'each update must stay a small in-filter: $call',
        );
      }
      final marked = patchCalls
          .expand(parseInFilter)
          .toSet();
      expect(marked, hasLength(250));
    });

    test('markAllAsRead leaves notifications of other app contexts unread',
        () async {
      serverRows.add(unreadRow('mine-1'));
      serverRows.add(
        unreadRow('admin-1', type: 'admin_management', audience: 'admin'),
      );

      await dataSource.markAllAsRead();

      expect(
        serverRows.singleWhere((r) => r['id'] == 'mine-1')['is_read'],
        isTrue,
      );
      expect(
        serverRows.singleWhere((r) => r['id'] == 'admin-1')['is_read'],
        isFalse,
      );
    });

    test('markAllAsRead with no unread rows issues no update', () async {
      await dataSource.markAllAsRead();
      expect(patchCalls, isEmpty);
    });

    test('clearAll deletes every visible row in bounded chunks', () async {
      for (var i = 0; i < 130; i++) {
        serverRows.add(unreadRow('d-$i'));
      }

      await dataSource.clearAll();

      expect(serverRows, isEmpty);
      expect(deleteCalls, hasLength(3));
      for (final call in deleteCalls) {
        expect(
          parseInFilter(call).length,
          lessThanOrEqualTo(50),
          reason: 'each delete must stay a small in-filter: $call',
        );
      }
    });

    test('clearAll keeps notifications of other app contexts', () async {
      serverRows.add(unreadRow('mine-1'));
      serverRows.add(
        unreadRow('admin-1', type: 'admin_management', audience: 'admin'),
      );

      await dataSource.clearAll();

      expect(serverRows, hasLength(1));
      expect(serverRows.single['id'], 'admin-1');
    });
  });
}
