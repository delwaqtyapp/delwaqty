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
    dataSource = SupabaseNotificationDataSource(
      supabase,
      currentUserId: () => 'user-1',
    );
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
    late List<Uri> getCalls;
    late int requestCount;
    bool endlessVisibleRows = false;
    int failOnPatchNumber = -1;
    int failOnDeleteNumber = -1;

    Set<String> parseInFilter(Uri uri) {
      final raw = uri.queryParameters['id'] ?? '';
      final inner = raw.replaceAll(RegExp(r'^in\.\(|\)$'), '');
      return inner
          .split(',')
          .map((v) => v.trim().replaceAll(RegExp(r'^"|"$'), ''))
          .where((v) => v.isNotEmpty)
          .toSet();
    }

    String? userFilter(Uri uri) {
      final raw = uri.queryParameters['user_id'];
      if (raw != null && raw.startsWith('eq.')) return raw.substring(3);
      return null;
    }

    Map<String, dynamic> unreadRow(
      String id, {
      String type = 'system',
      String audience = 'customer',
      String userId = 'user-1',
      bool isRead = false,
    }) => {
      'id': id,
      'type': type,
      'deep_link': null,
      'data': null,
      'audience': audience,
      'is_read': isRead,
      'user_id': userId,
      'created_at': '2026-11-24T00:00:00.000Z',
    };

    // A tiny in-memory PostgREST: honours the user_id/is_read filters on
    // reads AND mutations, exactly like the real server would.
    setUp(() {
      serverRows = [];
      patchCalls = [];
      deleteCalls = [];
      getCalls = [];
      requestCount = 0;
      endlessVisibleRows = false;
      failOnPatchNumber = -1;
      failOnDeleteNumber = -1;

      when(() => httpClient.send(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as http.Request;
        requestCount++;
        final uri = request.url;
        Object body;
        if (request.method == 'GET') {
          getCalls.add(uri);
          if (endlessVisibleRows) {
            final offset =
                int.tryParse(uri.queryParameters['offset'] ?? '') ?? 0;
            body = List.generate(200, (i) => unreadRow('gen-$offset-$i'));
          } else {
            Iterable<Map<String, dynamic>> result = serverRows;
            final uf = userFilter(uri);
            if (uf != null) {
              result = result.where((r) => r['user_id'] == uf);
            }
            if (uri.queryParameters['is_read'] == 'eq.false') {
              result = result.where((r) => r['is_read'] == false);
            }
            // Honor the deterministic ordering the data source asks
            // for: created_at DESC, id DESC (ties broken by id).
            result = result.toList()
              ..sort((a, b) {
                final byCreated = (b['created_at'] as String).compareTo(
                  a['created_at'] as String,
                );
                if (byCreated != 0) return byCreated;
                return (b['id'] as String).compareTo(a['id'] as String);
              });
            final offset =
                int.tryParse(uri.queryParameters['offset'] ?? '') ?? 0;
            final limit = int.tryParse(uri.queryParameters['limit'] ?? '');
            result = result.skip(offset);
            if (limit != null) result = result.take(limit);
            body = result.toList();
          }
        } else if (request.method == 'PATCH') {
          patchCalls.add(uri);
          if (patchCalls.length == failOnPatchNumber) {
            return http.StreamedResponse(
              Stream.value(utf8.encode('{"message":"boom"}')),
              500,
              headers: {'content-type': 'application/json; charset=utf-8'},
              request: request,
            );
          }
          final ids = parseInFilter(uri);
          final uf = userFilter(uri);
          final onlyUnread = uri.queryParameters['is_read'] == 'eq.false';
          for (final row in serverRows) {
            if (!ids.contains(row['id'])) continue;
            if (uf != null && row['user_id'] != uf) continue;
            if (onlyUnread && row['is_read'] != false) continue;
            row['is_read'] = true;
          }
          body = <Map<String, dynamic>>[];
        } else if (request.method == 'DELETE') {
          deleteCalls.add(uri);
          if (deleteCalls.length == failOnDeleteNumber) {
            return http.StreamedResponse(
              Stream.value(utf8.encode('{"message":"boom"}')),
              500,
              headers: {'content-type': 'application/json; charset=utf-8'},
              request: request,
            );
          }
          final ids = parseInFilter(uri);
          final uf = userFilter(uri);
          serverRows.removeWhere(
            (r) => ids.contains(r['id']) && (uf == null || r['user_id'] == uf),
          );
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

      final result = await dataSource.markAllAsRead();

      expect(result.completed, isTrue);
      expect(result.processed, 250);
      expect(serverRows.every((r) => r['is_read'] == true), isTrue);
      for (final call in patchCalls) {
        expect(
          parseInFilter(call).length,
          lessThanOrEqualTo(50),
          reason: 'each update must stay a small in-filter: $call',
        );
      }
      final marked = patchCalls.expand(parseInFilter).toSet();
      expect(marked, hasLength(250));
    });

    test(
      'markAllAsRead leaves notifications of other app contexts unread',
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
      },
    );

    test('markAllAsRead with no unread rows issues no update', () async {
      await dataSource.markAllAsRead();
      expect(patchCalls, isEmpty);
    });

    test('clearAll deletes every visible row in bounded chunks', () async {
      for (var i = 0; i < 130; i++) {
        serverRows.add(unreadRow('d-$i'));
      }

      final result = await dataSource.clearAll();

      expect(result.completed, isTrue);
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

    test('every bulk read and mutation carries the user_id filter', () async {
      for (var i = 0; i < 75; i++) {
        serverRows.add(unreadRow('s-$i'));
      }

      await dataSource.markAllAsRead();
      await dataSource.clearAll();

      for (final uri in [...getCalls, ...patchCalls, ...deleteCalls]) {
        expect(userFilter(uri), 'user-1', reason: 'unscoped request: $uri');
      }
    });

    test(
      'markAllAsRead scans past a hidden prefix longer than one page',
      () async {
        // 250 hidden rows (other app context) before any visible row: the
        // old fixed-window fetch saw an all-hidden page and stopped.
        for (var i = 0; i < 250; i++) {
          serverRows.add(
            unreadRow('hidden-$i', type: 'admin_management', audience: 'admin'),
          );
        }
        serverRows.add(unreadRow('visible-1'));
        serverRows.add(unreadRow('visible-2'));

        final result = await dataSource.markAllAsRead();

        expect(result.completed, isTrue);
        expect(result.processed, 2);
        expect(
          serverRows
              .where((r) => (r['id'] as String).startsWith('visible-'))
              .every((r) => r['is_read'] == true),
          isTrue,
        );
        expect(
          serverRows
              .where((r) => (r['id'] as String).startsWith('hidden-'))
              .every((r) => r['is_read'] == false),
          isTrue,
        );
      },
    );

    test('clearAll scans past a hidden prefix longer than one page', () async {
      for (var i = 0; i < 250; i++) {
        serverRows.add(
          unreadRow('hidden-$i', type: 'admin_management', audience: 'admin'),
        );
      }
      serverRows.add(unreadRow('visible-1'));
      serverRows.add(unreadRow('visible-2'));

      final result = await dataSource.clearAll();

      expect(result.completed, isTrue);
      expect(result.processed, 2);
      expect(serverRows, hasLength(250));
      expect(
        serverRows.every((r) => (r['id'] as String).startsWith('hidden-')),
        isTrue,
      );
    });

    test(
      'both ops handle visible and hidden rows mixed across pages',
      () async {
        for (var i = 0; i < 450; i++) {
          final hidden = i % 3 == 0;
          serverRows.add(
            hidden
                ? unreadRow('h-$i', type: 'admin_management', audience: 'admin')
                : unreadRow('v-$i'),
          );
        }
        final visibleCount = serverRows
            .where((r) => (r['id'] as String).startsWith('v-'))
            .length;

        final markResult = await dataSource.markAllAsRead();
        expect(markResult.completed, isTrue);
        expect(markResult.processed, visibleCount);
        expect(
          serverRows
              .where((r) => (r['id'] as String).startsWith('v-'))
              .every((r) => r['is_read'] == true),
          isTrue,
        );
        expect(
          serverRows
              .where((r) => (r['id'] as String).startsWith('h-'))
              .every((r) => r['is_read'] == false),
          isTrue,
        );

        final clearResult = await dataSource.clearAll();
        expect(clearResult.completed, isTrue);
        expect(serverRows, hasLength(450 - visibleCount));
        expect(
          serverRows.every((r) => (r['id'] as String).startsWith('h-')),
          isTrue,
        );
      },
    );

    test(
      'an admin session never touches another user\'s same-context rows',
      () async {
        // RLS lets admins select/delete members' rows; the data source
        // must still scope every query to the signed-in user.
        final adminDs = SupabaseNotificationDataSource(
          supabase,
          currentUserId: () => 'admin-1',
        );
        for (var i = 0; i < 3; i++) {
          serverRows.add(unreadRow('admin-n-$i', userId: 'admin-1'));
        }
        for (var i = 0; i < 2; i++) {
          serverRows.add(unreadRow('member-n-$i', userId: 'member-9'));
        }

        final markResult = await adminDs.markAllAsRead();
        expect(markResult.completed, isTrue);
        expect(markResult.processed, 3);
        expect(
          serverRows
              .where((r) => r['user_id'] == 'member-9')
              .every((r) => r['is_read'] == false),
          isTrue,
        );

        final clearResult = await adminDs.clearAll();
        expect(clearResult.completed, isTrue);
        expect(clearResult.processed, 3);
        expect(serverRows, hasLength(2));
        expect(serverRows.every((r) => r['user_id'] == 'member-9'), isTrue);

        for (final uri in [...patchCalls, ...deleteCalls]) {
          expect(userFilter(uri), 'admin-1', reason: 'unscoped mutation: $uri');
        }
      },
    );

    test(
      'equal timestamps across page boundaries: every row is reached',
      () async {
        // 250 rows with identical created_at: without the id tiebreaker a
        // page boundary inside the tie could skip or repeat rows.
        for (var i = 0; i < 250; i++) {
          serverRows.add(unreadRow('tie-${i.toString().padLeft(3, '0')}'));
        }

        final result = await dataSource.markAllAsRead();

        expect(result.completed, isTrue);
        expect(result.processed, 250);
        expect(serverRows.every((r) => r['is_read'] == true), isTrue);
        final marked = patchCalls.expand(parseInFilter).toSet();
        expect(marked, hasLength(250));
      },
    );

    test('markAllAsRead returns partial status when a chunk fails', () async {
      for (var i = 0; i < 120; i++) {
        serverRows.add(unreadRow('p-$i'));
      }
      failOnPatchNumber = 2; // first chunk ok, second explodes

      final result = await dataSource.markAllAsRead();

      expect(result.completed, isFalse);
      expect(result.processed, 50);
      expect(result.error, isNotNull);
    });

    test('clearAll returns partial status when a chunk fails', () async {
      for (var i = 0; i < 120; i++) {
        serverRows.add(unreadRow('p-$i'));
      }
      failOnDeleteNumber = 2;

      final result = await dataSource.clearAll();

      expect(result.completed, isFalse);
      expect(result.processed, 50);
      expect(result.error, isNotNull);
      expect(serverRows, hasLength(70));
    });

    test(
      'a full safety-cap run returns a structured result, never throws',
      () async {
        endlessVisibleRows = true; // server that never runs out of rows

        final result = await dataSource.markAllAsRead();

        expect(result.completed, isFalse);
        expect(result.limitReached, isTrue);
        expect(result.error, isNull);
      },
    );

    test('no signed-in user: throws and never issues a request', () async {
      final anonDs = SupabaseNotificationDataSource(
        supabase,
        currentUserId: () => null,
        sessionRetryCount: 2,
        sessionRetryDelay: const Duration(milliseconds: 1),
      );

      await expectLater(anonDs.markAllAsRead(), throwsStateError);
      await expectLater(anonDs.clearAll(), throwsStateError);
      await expectLater(anonDs.getNotifications(), throwsStateError);
      // getUnreadCount degrades to 0 via its catch, still without any
      // unscoped request.
      expect(await anonDs.getUnreadCount(), 0);
      expect(requestCount, 0);
    });
  });
}
