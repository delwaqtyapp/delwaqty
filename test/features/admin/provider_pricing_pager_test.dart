import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/services/admin/provider_pricing_pager.dart';

Map<String, dynamic> _page(int offset, int count, int total) => {
  'items': List.generate(count, (i) => {'id': offset + i}),
  'total': total,
};

void main() {
  group('ProviderPricingPager', () {
    test('appends pages and reports totals', () async {
      final calls = <Completer<Map<String, dynamic>>>[];
      final pager = ProviderPricingPager(
        fetchPage: (offset) {
          final c = Completer<Map<String, dynamic>>();
          calls.add(c);
          return c.future;
        },
      );

      final r = pager.reload();
      calls[0].complete(_page(0, 50, 100));
      await r;
      expect(pager.items.length, 50);
      expect(pager.total, 100);

      final lm = pager.loadMore();
      calls[1].complete(_page(50, 50, 100));
      await lm;
      expect(pager.items.length, 100);
      expect(pager.loadingMore, isFalse);
    });

    test(
      'race: slow page 2, then search (reload), then page 2 resolves stale - '
      'stale resolution neither clobbers items nor sticks Load More disabled',
      () async {
        final calls = <Completer<Map<String, dynamic>>>[];
        final pager = ProviderPricingPager(
          fetchPage: (offset) {
            final c = Completer<Map<String, dynamic>>();
            calls.add(c);
            return c.future;
          },
        );

        // initial load: 50 of 100
        final r1 = pager.reload();
        calls[0].complete(_page(0, 50, 100));
        await r1;
        expect(pager.items.length, 50);

        // slow page 2 in flight
        final lm = pager.loadMore();
        expect(pager.loadingMore, isTrue);

        // user searches -> reload bumps the sequence and resets the flag
        final r2 = pager.reload();
        expect(pager.loading, isTrue);
        expect(pager.loadingMore, isFalse);

        // stale page 2 resolves: must not clobber, must not touch flags
        calls[1].complete(_page(50, 50, 100));
        await lm;
        expect(pager.items.length, 50, reason: 'stale page discarded');
        expect(pager.loadingMore, isFalse);

        // the search's own page resolves
        calls[2].complete(_page(0, 50, 75));
        await r2;
        expect(pager.items.length, 50);
        expect(pager.total, 75);
        expect(pager.loading, isFalse);
        expect(pager.loadingMore, isFalse);

        // Load More still works afterwards
        final lm2 = pager.loadMore();
        calls[3].complete(_page(50, 25, 75));
        await lm2;
        expect(pager.items.length, 75);
        expect(pager.loadingMore, isFalse);
        expect(pager.loadMoreFailed, isFalse);
      },
    );

    test('failed load-more clears its flag and reports failure', () async {
      final calls = <Completer<Map<String, dynamic>>>[];
      final pager = ProviderPricingPager(
        fetchPage: (offset) {
          final c = Completer<Map<String, dynamic>>();
          calls.add(c);
          return c.future;
        },
      );
      final r = pager.reload();
      calls[0].complete(_page(0, 50, 100));
      await r;

      final lm = pager.loadMore();
      calls[1].completeError(Exception('network'));
      await lm;
      expect(pager.loadingMore, isFalse);
      expect(pager.loadMoreFailed, isTrue);
      expect(pager.items.length, 50);
    });
  });
}
