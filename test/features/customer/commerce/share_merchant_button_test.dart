import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/share_merchant_button.dart';

void main() {
  group('composeMerchantShareText', () {
    test('name and app only when there is no address', () {
      expect(
        composeMerchantShareText(merchantName: 'Koshary Ali', appName: 'Delwaqty'),
        'Koshary Ali - Delwaqty',
      );
    });

    test('address appended on a new line when present', () {
      expect(
        composeMerchantShareText(
          merchantName: 'Koshary Ali',
          appName: 'Delwaqty',
          address: '12 Tahrir St, Cairo',
        ),
        'Koshary Ali - Delwaqty\n12 Tahrir St, Cairo',
      );
    });

    test('blank address is treated as missing', () {
      expect(
        composeMerchantShareText(
          merchantName: 'Koshary Ali',
          appName: 'Delwaqty',
          address: '   ',
        ),
        'Koshary Ali - Delwaqty',
      );
    });
  });
}
