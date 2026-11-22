import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CashCollectionState', () {
    test('parses the driver_cash_collection_state RPC payload', () {
      final state = CashCollectionState.fromJson({
        'ok': true,
        'ride_id': 'r1',
        'order_id': 'o1',
        'ride_status': 'completed',
        'payment_method': 'cash',
        'payment_status': 'pending',
        'collected': false,
        'amount': 115,
        'currency': 'EGP',
      });
      expect(state.isCash, isTrue);
      expect(state.collected, isFalse);
      expect(state.amount, 115);
      expect(state.orderId, 'o1');
    });
  });

  group('CashCollectionResult', () {
    test('COLLECTED and ALREADY_COLLECTED both mean collected', () {
      expect(
        CashCollectionResult(ok: true, code: 'COLLECTED').collected,
        isTrue,
      );
      expect(
        CashCollectionResult(ok: true, code: 'ALREADY_COLLECTED').collected,
        isTrue,
      );
      expect(
        CashCollectionResult(ok: false, code: 'NOT_FOUND').collected,
        isFalse,
      );
    });
  });

  group('OrderDeliveryRide.rateable', () {
    OrderDeliveryRide ride({
      String status = 'completed',
      String paymentMethod = 'cash',
      String paymentStatus = 'pending',
      DateTime? cashCollectedAt,
    }) => OrderDeliveryRide(
      id: 'r1',
      status: status,
      driverId: 'd1',
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      cashCollectedAt: cashCollectedAt,
    );

    test('cash ride waits for collection', () {
      expect(ride().rateable, isFalse);
      expect(ride(paymentStatus: 'paid').rateable, isTrue);
      expect(ride(cashCollectedAt: DateTime(2026)).rateable, isTrue);
    });

    test('non-cash completion is unchanged', () {
      expect(ride(paymentMethod: 'wallet').rateable, isTrue);
    });

    test('unfinished delivery is never rateable', () {
      expect(
        ride(status: 'inTrip', paymentMethod: 'wallet').rateable,
        isFalse,
      );
    });
  });
}
