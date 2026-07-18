import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/features/search/data/cache/ttl_cache.dart';

void main() {
  group('TtlCache', () {
    test('stores and returns values', () {
      final cache = TtlCache<String, int>();
      cache.put('a', 1);
      expect(cache.get('a'), 1);
      expect(cache.get('missing'), isNull);
    });

    test('expires entries after ttl', () async {
      final cache =
          TtlCache<String, int>(ttl: const Duration(milliseconds: 20));
      cache.put('a', 1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cache.get('a'), isNull);
    });

    test('evicts least-recently-used beyond maxEntries', () {
      final cache = TtlCache<String, int>(maxEntries: 2);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.get('a');
      cache.put('c', 3);
      expect(cache.get('b'), isNull);
      expect(cache.get('a'), 1);
      expect(cache.get('c'), 3);
    });

    test('clear empties the cache', () {
      final cache = TtlCache<String, int>();
      cache.put('a', 1);
      cache.clear();
      expect(cache.length, 0);
    });
  });
}
