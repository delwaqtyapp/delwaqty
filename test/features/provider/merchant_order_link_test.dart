import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_order.dart';

void main() {
  test('legacy order defaults to no linked delivery', () {
    final o = MerchantOrder(
      id: 'o',
      customerId: 'c',
      totalAmount: 65,
      status: 'ready',
      createdAt: DateTime(2026),
    );
    expect(o.hasLinkedDelivery, isFalse);
  });
  test('linked delivery is retained by serialization and copy', () {
    final o = MerchantOrder(
      id: 'o',
      customerId: 'c',
      driverId: 'd',
      hasLinkedDelivery: true,
      totalAmount: 65,
      status: 'ready',
      createdAt: DateTime(2026),
    );
    expect(MerchantOrder.fromJson(o.toJson()).hasLinkedDelivery, isTrue);
    expect(o.copyWith(status: 'delivering').hasLinkedDelivery, isTrue);
  });
}
