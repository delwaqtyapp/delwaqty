import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/data/refund_requests_api.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/refund_request_section.dart';

Order _order({
  OrderStatus status = OrderStatus.delivered,
  PaymentStatus pay = PaymentStatus.paid,
  Duration age = const Duration(days: 1),
}) => Order(
  id: 'o1',
  merchantId: 'm1',
  merchantName: 'm',
  status: status,
  paymentStatus: pay,
  subtotal: 100,
  total: 100,
  createdAt: DateTime.now().subtract(age),
);

RefundRequest _req(String status) =>
    RefundRequest(id: 'r1', orderId: 'o1', status: status, amount: 100);

void main() {
  group('canRequestRefund', () {
    test('delivered, paid, inside the window, no live request', () {
      expect(canRequestRefund(_order(), null), isTrue);
    });
    test('blocked when not delivered, not paid or too old', () {
      expect(
        canRequestRefund(_order(status: OrderStatus.pending), null),
        isFalse,
      );
      expect(
        canRequestRefund(_order(pay: PaymentStatus.pending), null),
        isFalse,
      );
      expect(
        canRequestRefund(_order(pay: PaymentStatus.refunded), null),
        isFalse,
      );
      expect(
        canRequestRefund(_order(age: const Duration(days: 15)), null),
        isFalse,
      );
    });
    test(
      'a pending or approved request blocks, a rejected one allows retry',
      () {
        expect(canRequestRefund(_order(), _req('pending')), isFalse);
        expect(canRequestRefund(_order(), _req('approved')), isFalse);
        expect(canRequestRefund(_order(), _req('rejected')), isTrue);
      },
    );
  });

  group('unwrapRefundResult', () {
    test('returns the map when ok', () {
      expect(unwrapRefundResult({'ok': true, 'code': 'OK'})['code'], 'OK');
    });
    test('throws the server code when refused', () {
      expect(
        () => unwrapRefundResult({'ok': false, 'code': 'WINDOW_EXPIRED'}),
        throwsA(
          isA<RefundException>().having(
            (e) => e.code,
            'code',
            'WINDOW_EXPIRED',
          ),
        ),
      );
    });
  });

  test('reason codes match the server check constraint', () {
    expect(refundReasonCodes, [
      'missing_item',
      'wrong_item',
      'quality',
      'late',
      'damaged',
      'other',
    ]);
  });
}
