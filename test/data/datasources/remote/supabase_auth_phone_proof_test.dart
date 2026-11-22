import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/data/datasources/remote/supabase_auth_data_source.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

class _Logger extends Mock implements AppLogger {}

void main() {
  test('signup sends the private proof in server hook metadata', () async {
    Map<String, dynamic>? payload;
    final client = SupabaseClient(
      'https://example.invalid',
      'test-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'msg': 'test rejection'}),
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final source = SupabaseAuthDataSource(client, _Logger());
    await expectLater(
      source.signUpWithEmail(
        email: 'phone_201000000001@delwaqty.app',
        password: 'TestOnlyPassword123',
        phone: '+201000000001',
        phoneVerificationChallenge: '00000000-0000-4000-8000-000000000008',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(
      (payload!['data'] as Map)['phone_verification_challenge'],
      '00000000-0000-4000-8000-000000000008',
    );
    expect((payload!['data'] as Map)['phone'], '+201000000001');
    await client.dispose();
  });
}
