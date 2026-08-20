import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/features/customer/search/data/cache/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('runs only the last action within the window', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 30));
      var count = 0;
      var last = 0;
      for (var i = 1; i <= 3; i++) {
        debouncer.run(() {
          count++;
          last = i;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(count, 1);
      expect(last, 3);
    });

    test('cancel prevents execution', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 20));
      var ran = false;
      debouncer.run(() => ran = true);
      debouncer.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(ran, isFalse);
    });
  });
}
