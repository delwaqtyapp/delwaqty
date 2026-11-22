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
                  'whatsapp_number': '+201555570885',
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
                'whatsapp_number': '+201555570885',
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
}
