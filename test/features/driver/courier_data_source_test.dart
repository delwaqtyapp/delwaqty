import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/driver/data/datasources/remote/supabase_driver_data_source.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

SupabaseDriverDataSource _source(
  Map<String, dynamic> Function(String fn, Map<String, dynamic> params)
  responder,
  List<(String, Map<String, dynamic>)> calls,
) {
  return SupabaseDriverDataSource(
    SupabaseClient('https://proj.supabase.co', 'anon-key'),
    AppLogger(),
    rpcCaller: (fn, params) async {
      calls.add((fn, params));
      return responder(fn, params);
    },
  );
}

void main() {
  group('driver courier RPC contract', () {
    test('proposeCourierQuote sends the exact 436 params', () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final source = _source((fn, params) => {'ok': true}, calls);

      await source.proposeCourierQuote('ride-1', 25.5, note: 'waiting time');

      expect(calls, hasLength(1));
      expect(calls.single.$1, 'propose_courier_quote');
      expect(calls.single.$2, {
        'p_ride_id': 'ride-1',
        'p_amount': 25.5,
        'p_note': 'waiting time',
      });
    });

    test('respondCourierQuote sends quote id and action', () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final source = _source((fn, params) => {'ok': true}, calls);

      await source.respondCourierQuote('q-9', 'accept');

      expect(calls.single.$1, 'respond_courier_quote');
      expect(calls.single.$2, {'p_quote_id': 'q-9', 'p_action': 'accept'});
    });

    test(
      'addCourierInvoiceItem passes money and units through exactly',
      () async {
        final calls = <(String, Map<String, dynamic>)>[];
        final source = _source((fn, params) => {'ok': true}, calls);

        await source.addCourierInvoiceItem(
          'ride-1',
          shopName: 'Seif Pharmacy',
          productName: 'Paracetamol 500',
          price: 55.50,
          unit: 'piece',
          quantity: 2,
          receiptPhotoUrl: 'https://proj.supabase.co/storage/v1/r.jpg',
        );

        expect(calls.single.$1, 'add_courier_invoice_item');
        expect(calls.single.$2, {
          'p_ride_id': 'ride-1',
          'p_shop_name': 'Seif Pharmacy',
          'p_product_name': 'Paracetamol 500',
          'p_price': 55.50,
          'p_unit': 'piece',
          'p_quantity': 2,
          'p_receipt_photo_url': 'https://proj.supabase.co/storage/v1/r.jpg',
        });
      },
    );

    test('cancel and finish send their ids', () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final source = _source((fn, params) => {'ok': true}, calls);

      await source.cancelCourierInvoiceItem('item-7');
      await source.finishCourierShopping('ride-1');

      expect(calls[0].$1, 'cancel_courier_invoice_item');
      expect(calls[0].$2, {'p_item_id': 'item-7'});
      expect(calls[1].$1, 'finish_courier_shopping');
      expect(calls[1].$2, {'p_ride_id': 'ride-1'});
    });

    test('ok:false throws DriverCourierException with the server reason', () {
      final calls = <(String, Map<String, dynamic>)>[];
      final source = _source(
        (fn, params) => {'ok': false, 'reason': 'BELOW_BASELINE'},
        calls,
      );

      expect(
        () => source.proposeCourierQuote('ride-1', 10),
        throwsA(
          isA<DriverCourierException>().having(
            (e) => e.reason,
            'reason',
            'BELOW_BASELINE',
          ),
        ),
      );
    });

    test('a missing reason still throws, never silently succeeds', () {
      final calls = <(String, Map<String, dynamic>)>[];
      final source = _source((fn, params) => {'ok': false}, calls);

      expect(
        () => source.finishCourierShopping('ride-1'),
        throwsA(
          isA<DriverCourierException>().having(
            (e) => e.reason,
            'reason',
            'unknown',
          ),
        ),
      );
    });
  });
}
