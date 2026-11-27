import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/delivery/domain/direct_delivery_validation.dart';

void main() {
  DirectDeliveryError? v({
    String drop = 'Street 1',
    String phone = '01012345678',
    int items = 1,
    String desc = '',
  }) => validateDirectDelivery(
    dropoffText: drop,
    phone: phone,
    itemCount: items,
    description: desc,
  );

  test('valid form passes', () => expect(v(), isNull));
  test('description alone is enough', () {
    expect(v(items: 0, desc: 'two loaves'), isNull);
  });
  test('missing drop-off', () {
    expect(v(drop: '  '), DirectDeliveryError.noDropoff);
  });
  test('missing and malformed phone', () {
    expect(v(phone: ''), DirectDeliveryError.noPhone);
    expect(v(phone: '0212345678'), DirectDeliveryError.badPhone);
    expect(v(phone: '0101234567'), DirectDeliveryError.badPhone);
    expect(v(phone: '010123456789'), DirectDeliveryError.badPhone);
    expect(v(phone: '+201012345678'), isNull);
  });
  test('needs an item or a description', () {
    expect(v(items: 0), DirectDeliveryError.nothingToDeliver);
  });
  test('quantity must be a whole number >= 1', () {
    expect(parseItemQuantity('3'), 3);
    expect(parseItemQuantity('0'), isNull);
    expect(parseItemQuantity('-2'), isNull);
    expect(parseItemQuantity('abc'), isNull);
    expect(parseItemQuantity(''), isNull);
  });
}
