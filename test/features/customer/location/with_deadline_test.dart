import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';

void main() {
  test('a call that never answers resolves to the fallback', () async {
    final never = Completer<String>().future;
    final result = await withDeadline<String>(
      never,
      const Duration(milliseconds: 50),
      'fallback',
    );
    expect(result, 'fallback');
  });

  test('a fast answer is returned as is', () async {
    expect(
      await withDeadline<String>(
        Future.value('ok'),
        const Duration(seconds: 1),
        'fallback',
      ),
      'ok',
    );
  });

  test('an error resolves to the fallback instead of throwing', () async {
    expect(
      await withDeadline<String>(
        Future<String>.error(Exception('x')),
        const Duration(seconds: 1),
        'fallback',
      ),
      'fallback',
    );
  });

  test('the whole request is capped at 30 seconds', () {
    expect(locationRequestCap, const Duration(seconds: 30));
  });
}
