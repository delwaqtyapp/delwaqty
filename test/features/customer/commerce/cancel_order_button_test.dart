import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/cancel_order_button.dart';

void main() {
  group('canCustomerCancel', () {
    test('only before the merchant starts preparing', () {
      expect(canCustomerCancel(OrderStatus.pending), isTrue);
      expect(canCustomerCancel(OrderStatus.confirmed), isTrue);
      for (final s in [
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.pickedUp,
        OrderStatus.inTransit,
        OrderStatus.delivered,
        OrderStatus.cancelled,
      ]) {
        expect(canCustomerCancel(s), isFalse, reason: s.name);
      }
    });
  });

  group('cancelOrderErrorOf', () {
    test('maps the cancel_order refusal codes', () {
      expect(
        cancelOrderErrorOf(Exception('cancel_order refused: OUT_FOR_DELIVERY')),
        CancelOrderError.outForDelivery,
      );
      expect(
        cancelOrderErrorOf(Exception('cancel_order refused: NOT_CANCELLABLE')),
        CancelOrderError.notCancellable,
      );
      expect(
        cancelOrderErrorOf(Exception('cancel_order refused: FORBIDDEN')),
        CancelOrderError.forbidden,
      );
      expect(cancelOrderErrorOf(Exception('boom')), CancelOrderError.other);
    });
  });

  test('cancel reason codes are stable and unknown text passes through', () {
    expect(cancelReasonCodes, ['changed_mind', 'wrong_address', 'other']);
  });
}
