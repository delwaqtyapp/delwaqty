import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/data/datasources/remote/supabase_auth_data_source.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockAuthResponse extends Mock implements AuthResponse {}

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late MockGoTrueClient auth;
  late MockAppLogger logger;
  late SupabaseAuthDataSource dataSource;
  late List<String> logLines;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = MockSupabaseClient();
    functions = MockFunctionsClient();
    auth = MockGoTrueClient();
    logger = MockAppLogger();
    logLines = <String>[];
    when(() => client.functions).thenReturn(functions);
    when(() => client.auth).thenReturn(auth);
    when(() => logger.e(any(), any(), any())).thenAnswer((inv) {
      logLines.add(inv.positionalArguments.map((a) => '$a').join(' '));
    });
    when(() => logger.e(any())).thenAnswer((inv) {
      logLines.add('${inv.positionalArguments.first}');
    });
    when(() => logger.i(any())).thenAnswer((_) {});
    dataSource = SupabaseAuthDataSource(client, logger);
  });

  void stubInvoke(dynamic answer) {
    when(
      () => functions.invoke('auth-login-identifier', body: any(named: 'body')),
    ).thenAnswer((_) async {
      if (answer is Exception) throw answer;
      return answer as FunctionResponse;
    });
  }

  group('signInWithIdentifier', () {
    test('success adopts the session via setSession and returns it', () async {
      stubInvoke(
        FunctionResponse(
          data: {
            'access_token': 'a',
            'refresh_token': 'r-1',
            'expires_in': 3600,
            'token_type': 'bearer',
          },
          status: 200,
        ),
      );
      final response = MockAuthResponse();
      when(() => auth.setSession('r-1')).thenAnswer((_) async => response);

      final result = await dataSource.signInWithIdentifier(
        identifier: 'SuperAdmin',
        password: 'secret',
      );

      expect(result, same(response));
      verify(() => auth.setSession('r-1')).called(1);
    });

    test('malformed 200 payloads never reach setSession', () async {
      for (final bad in <dynamic>[
        null,
        'not-a-map',
        <String, dynamic>{},
        {'refresh_token': ''},
        {'refresh_token': 42},
      ]) {
        stubInvoke(FunctionResponse(data: bad, status: 200));
        await expectLater(
          dataSource.signInWithIdentifier(identifier: 'u', password: 'p'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Sign in is temporarily unavailable.',
            ),
          ),
        );
      }
      verifyNever(() => auth.setSession(any()));
    });

    test(
      'setSession failure is normalized to the unavailable message',
      () async {
        stubInvoke(
          FunctionResponse(data: {'refresh_token': 'r-1'}, status: 200),
        );
        when(() => auth.setSession('r-1')).thenThrow(Exception('backend text'));

        await expectLater(
          dataSource.signInWithIdentifier(identifier: 'u', password: 'p'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Sign in is temporarily unavailable.',
            ),
          ),
        );
      },
    );

    test('401 and 400 map to the invalid-credentials message', () async {
      for (final status in [400, 401]) {
        stubInvoke(
          FunctionException(
            status: status,
            details: {
              'error': status == 401 ? 'invalid_credentials' : 'bad_request',
            },
          ),
        );
        await expectLater(
          dataSource.signInWithIdentifier(identifier: 'u', password: 'p'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Invalid username or password.',
            ),
          ),
        );
      }
    });

    test('429 maps to the too-many-attempts message', () async {
      stubInvoke(
        FunctionException(status: 429, details: {'error': 'too_many_attempts'}),
      );
      await expectLater(
        dataSource.signInWithIdentifier(identifier: 'u', password: 'p'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Too many attempts. Please try again later.',
          ),
        ),
      );
    });

    test('503 and transport throws map to the unavailable message', () async {
      stubInvoke(
        FunctionException(
          status: 503,
          details: {'error': 'temporarily_unavailable'},
        ),
      );
      await expectLater(
        dataSource.signInWithIdentifier(identifier: 'u', password: 'p'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Sign in is temporarily unavailable.',
          ),
        ),
      );

      stubInvoke(Exception('raw socket detail'));
      await expectLater(
        dataSource.signInWithIdentifier(identifier: 'u', password: 'p'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Sign in is temporarily unavailable.',
          ),
        ),
      );
    });

    test('logs never contain tokens, passwords or raw payloads', () async {
      stubInvoke(FunctionResponse(data: {'refresh_token': 'r-1'}, status: 200));
      when(() => auth.setSession('r-1')).thenThrow(Exception('backend text'));
      await expectLater(
        dataSource.signInWithIdentifier(identifier: 'u', password: 'p-hunter2'),
        throwsA(isA<AuthException>()),
      );
      stubInvoke(Exception('raw socket detail'));
      await expectLater(
        dataSource.signInWithIdentifier(identifier: 'u', password: 'p-hunter2'),
        throwsA(isA<AuthException>()),
      );
      final all = logLines.join('\n');
      expect(all.contains('r-1'), isFalse);
      expect(all.contains('p-hunter2'), isFalse);
      expect(all.contains('backend text'), isFalse);
      expect(all.contains('raw socket detail'), isFalse);
    });
  });
}
