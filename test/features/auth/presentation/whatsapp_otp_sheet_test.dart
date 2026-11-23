import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/_shared/auth/presentation/widgets/whatsapp_otp_sheet.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void main() {
  testWidgets('Arabic mobile sheet scrolls without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _fakeClient(status: 'pending');
    await _openSheet(tester, client, locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/whatsapp_otp_ar.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets(
    'no manual code grants verification; only webhook status closes sheet',
    (tester) async {
      var status = 'pending';
      final calls = <String>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          calls.add(request.url.path);
          final data = request.url.path.endsWith('request_whatsapp_otp')
              ? {
                  'ok': true,
                  'otp_code': '123456',
                  'challenge': '00000000-0000-4000-8000-000000000008',
                  'whatsapp_number': '+201000000099',
                }
              : {'ok': true, 'status': status};
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => WhatsAppOtpSheet(
                      phone: '+201000000001',
                      client: client,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(WhatsAppOtpSheet), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(result, isNull);
      expect(calls.any((p) => p.endsWith('verify_whatsapp_otp')), isFalse);
      status = 'verified';
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(result, '00000000-0000-4000-8000-000000000008');
      expect(find.byType(WhatsAppOtpSheet), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      client.dispose();
    },
  );
  testWidgets(
    'resend discards a stale verified response for the prior challenge',
    (tester) async {
      final oldReply = Completer<http.Response>();
      http.Request? oldRequest;
      var generation = 0;
      const first = '00000000-0000-4000-8000-000000000001';
      const second = '00000000-0000-4000-8000-000000000002';
      String? result;
      final client = SupabaseClient(
        'https://example.invalid',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('request_whatsapp_otp')) {
            generation++;
            return http.Response(
              jsonEncode({
                'ok': true,
                'otp_code': '123456',
                'challenge': generation == 1 ? first : second,
                'whatsapp_number': '+201000000099',
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['p_challenge'] == first) {
            oldRequest = request;
            return oldReply.future;
          }
          expect(body['p_challenge'], second);
          return http.Response(
            jsonEncode({'ok': true, 'status': 'verified'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('open'),
                onPressed: () async {
                  result = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => WhatsAppOtpSheet(
                      phone: '+201000000001',
                      client: client,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(oldRequest, isNotNull);
      await tester.tap(find.text('Resend Code'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      oldReply.complete(
        http.Response(
          jsonEncode({'ok': true, 'status': 'verified'}),
          200,
          headers: {'content-type': 'application/json'},
          request: oldRequest,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(result, isNull);
      expect(find.byType(WhatsAppOtpSheet), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(result, second);
      await tester.pumpWidget(const SizedBox.shrink());
      client.dispose();
    },
  );

  testWidgets('copy button copies the code and shows copied feedback', (
    tester,
  ) async {
    final client = _fakeClient(status: 'pending');
    await _openSheet(tester, client);
    expect(find.textContaining('1 2 3 4 5 6'), findsOneWidget);
    expect(find.textContaining('Code expires in'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy code'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.text('Code copied'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('manual check while pending explains it is not confirmed yet', (
    tester,
  ) async {
    final client = _fakeClient(status: 'pending');
    await _openSheet(tester, client);
    await tester.tap(find.text("I've sent it - check now"));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Not confirmed yet'), findsOneWidget);
    expect(find.byType(WhatsAppOtpSheet), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('expiry flips to expired state and Get a new code re-requests', (
    tester,
  ) async {
    var generation = 0;
    final client = SupabaseClient(
      'https://example.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('request_whatsapp_otp')) {
          generation++;
          return http.Response(
            jsonEncode({
              'ok': true,
              'otp_code': '123456',
              'challenge': '00000000-0000-4000-8000-00000000000$generation',
              'whatsapp_number': '+201000000099',
              'expires_in_seconds': generation == 1 ? 2 : 600,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode({'ok': true, 'status': 'pending'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await _openSheet(tester, client);
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Code expired'), findsOneWidget);
    expect(find.text('Get a new code'), findsOneWidget);
    await tester.tap(find.text('Get a new code'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(generation, 2);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    expect(find.text('Code expired'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}

SupabaseClient _fakeClient({required String status}) {
  return SupabaseClient(
    'https://example.invalid',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final data = request.url.path.endsWith('request_whatsapp_otp')
          ? {
              'ok': true,
              'otp_code': '123456',
              'challenge': '00000000-0000-4000-8000-000000000008',
              'whatsapp_number': '+201000000099',
              'expires_in_seconds': 600,
            }
          : {'ok': true, 'status': status};
      return http.Response(
        jsonEncode(data),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
}

Future<void> _openSheet(
  WidgetTester tester,
  SupabaseClient client, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => WhatsAppOtpSheet(
                  phone: '+201000000001',
                  client: client,
                  now: tester.binding.clock.now,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}
