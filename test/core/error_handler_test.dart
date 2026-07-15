import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/errors/error_handler.dart';
import 'package:delwaqty/core/errors/failures.dart';
import 'package:delwaqty/core/errors/exceptions.dart';

void main() {
  group('handleException', () {
    test('converts ServerException to ServerFailure', () {
      const exception = ServerException(message: 'Server error');
      final failure = handleException(exception);
      expect(failure, isA<ServerFailure>());
      expect(
        failure.whenOrNull(server: (m) => m),
        'Server error',
      );
    });

    test('converts CacheException to CacheFailure', () {
      const exception = CacheException(message: 'Cache error');
      final failure = handleException(exception);
      expect(failure, isA<CacheFailure>());
    });

    test('converts NetworkException to NetworkFailure', () {
      const exception = NetworkException(message: 'No connection');
      final failure = handleException(exception);
      expect(failure, isA<NetworkFailure>());
    });

    test('converts AuthException to AuthFailure', () {
      const exception = AuthException(message: 'Unauthorized');
      final failure = handleException(exception);
      expect(failure, isA<AuthFailure>());
    });

    test('converts UnexpectedException to UnexpectedFailure', () {
      const exception = UnexpectedException(message: 'Unknown');
      final failure = handleException(exception);
      expect(failure, isA<UnexpectedFailure>());
    });

    test('converts unknown error to UnexpectedFailure', () {
      final failure = handleException(Exception('random'));
      expect(failure, isA<UnexpectedFailure>());
    });
  });
}
