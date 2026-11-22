import 'dart:convert';

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
}
