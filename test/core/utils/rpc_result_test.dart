import 'package:delwaqty/core/utils/rpc_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('checkedRpcResult', () {
    test('accepts success, ok and data-only response shapes', () {
      for (final response in [
        {'success': true, 'driver_id': 'driver'},
        {'ok': true, 'ride_id': 'ride'},
        {'balance': 42},
      ]) {
        expect(checkedRpcResult(response, onFailure: Exception.new), response);
      }
    });
    test('rejects logical failures even when HTTP succeeded', () {
      for (final response in [
        {'success': false, 'reason': 'forbidden'},
        {'ok': false, 'code': 'FORBIDDEN'},
        {'error': 'FORBIDDEN'},
        {'success': true, 'ok': false, 'reason': 'conflict'},
      ]) {
        expect(
          () => checkedRpcResult(response, onFailure: Exception.new),
          throwsA(isA<Exception>()),
        );
      }
    });
    test('preserves reason, code or error for classification', () {
      for (final field in ['reason', 'code', 'error']) {
        expect(
          () => checkedRpcResult({
            'ok': false,
            field: 'test_failure',
          }, onFailure: Exception.new),
          throwsA(predicate((e) => e.toString().contains('test_failure'))),
        );
      }
    });
  });
}
