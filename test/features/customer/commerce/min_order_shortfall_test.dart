import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/presentation/providers/cart_providers.dart';

void main() {
  group('minOrderShortfall', () {
    test('no minimum -> never blocked', () {
      expect(minOrderShortfall(0, null), isNull);
      expect(minOrderShortfall(0, 0), isNull);
      expect(minOrderShortfall(50, null), isNull);
    });

    test('subtotal below minimum -> remaining amount', () {
      expect(minOrderShortfall(30, 100), 70);
      expect(minOrderShortfall(0, 50), 50);
    });

    test('subtotal at or above minimum -> not blocked', () {
      expect(minOrderShortfall(100, 100), isNull);
      expect(minOrderShortfall(120, 100), isNull);
    });

    test('fractional remaining is preserved', () {
      expect(minOrderShortfall(99.5, 100), closeTo(0.5, 0.001));
    });
  });
}
