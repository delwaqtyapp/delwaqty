import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_invoice_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_quote.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_shopping_item.dart';

void main() {
  group('AskAnythingRideState', () {
    test('quoteBaseline is 15 + 5 per extra shop (owner model, #211)', () {
      AskAnythingRideState build(int shops) => AskAnythingRideState(
        rideId: 'r',
        status: 'searching',
        shopCount: shops,
        quoteLocked: false,
        goodsTotal: 0,
        shoppingFinished: false,
      );
      expect(build(1).quoteBaseline, 15);
      expect(build(2).quoteBaseline, 20);
      expect(build(3).quoteBaseline, 25);
      expect(build(10).quoteBaseline, 60);
    });

    test('fromRow reads the migrated columns with safe defaults', () {
      final state = AskAnythingRideState.fromRow(const {
        'id': 'ride-1',
        'courier_shop_count': 3,
        'courier_quote_locked': true,
        'fare': 25.0,
        'courier_shopping_finished': false,
        'courier_goods_total': 40.5,
      });
      expect(state.rideId, 'ride-1');
      expect(state.shopCount, 3);
      expect(state.quoteLocked, isTrue);
      expect(state.fare, 25.0);
      expect(state.quoteBaseline, 25);
      expect(state.shoppingFinished, isFalse);
      expect(state.goodsTotal, 40.5);
    });

    test('fromRow defaults when the migration columns are absent', () {
      final state = AskAnythingRideState.fromRow(const {'id': 'ride-2'});
      expect(state.shopCount, 1);
      expect(state.quoteLocked, isFalse);
      expect(state.fare, isNull);
      expect(state.goodsTotal, 0);
      expect(state.shoppingFinished, isFalse);
    });
  });

  group('CourierQuote', () {
    test('fromRow maps roles and statuses', () {
      final quote = CourierQuote.fromRow(const {
        'id': 'q1',
        'ride_id': 'r1',
        'proposed_by_role': 'driver',
        'amount': 30,
        'note': 'with waiting',
        'status': 'pending',
      });
      expect(quote.isFromDriver, isTrue);
      expect(quote.isPending, isTrue);
      expect(quote.amount, 30);
      expect(quote.note, 'with waiting');

      final counter = CourierQuote.fromRow(const {
        'id': 'q2',
        'ride_id': 'r1',
        'proposed_by_role': 'customer',
        'amount': 20,
        'status': 'accepted',
      });
      expect(counter.isFromDriver, isFalse);
      expect(counter.isPending, isFalse);
    });
  });

  group('CourierInvoiceItem', () {
    test('fromRow maps status helpers', () {
      final pending = CourierInvoiceItem.fromRow(const {
        'id': 'i1',
        'ride_id': 'r1',
        'status': 'pending',
        'shop_name': 'Al Gomhoreya',
        'product_name': 'Paracetamol 500',
        'price': 12.5,
      });
      expect(pending.isPending, isTrue);
      expect(pending.isApproved, isFalse);
      expect(pending.isCancelled, isFalse);

      final approved = CourierInvoiceItem.fromRow(const {
        'id': 'i2',
        'ride_id': 'r1',
        'status': 'approved',
        'price': 7.25,
      });
      expect(approved.isApproved, isTrue);
      expect(approved.price, 7.25);

      final cancelled = CourierInvoiceItem.fromRow(const {
        'id': 'i3',
        'ride_id': 'r1',
        'status': 'cancelled',
        'price': 3,
      });
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isRejected, isFalse);
    });
  });

  group('CourierShoppingItem', () {
    test('toJson omits amount unless the unit is an EGP amount', () {
      const item = CourierShoppingItem(productName: 'Rice 5kg', unit: 'kilo');
      expect(item.toJson(), {'product_name': 'Rice 5kg', 'unit': 'kilo'});

      const amountItem = CourierShoppingItem(
        productName: 'Butcher cut',
        unit: 'amount',
        amountEgp: 100,
      );
      expect(amountItem.toJson(), {
        'product_name': 'Butcher cut',
        'unit': 'amount',
        'amount_egp': 100,
      });
    });
  });
}
