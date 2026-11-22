import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout offers only the three working pilot payment methods', () {
    final source = File(
      'lib/features/customer/commerce/presentation/pages/checkout_page.dart',
    ).readAsStringSync();
    final selector = source.substring(
      source.indexOf('SegmentedButton<String>'),
      source.indexOf('selected: {_paymentMethod}'),
    );
    final choices = RegExp("value: '([^']+)'")
        .allMatches(selector)
        .map((match) => match.group(1))
        .toList();
    expect(choices, ['cash', 'instapay', 'vodafone_cash']);
    expect(selector, isNot(contains("value: 'card'")));
    expect(selector, isNot(contains("value: 'wallet'")));
  });

  test('wallet top-up does not advertise card or wallet payment', () {
    final source = File(
      'lib/features/customer/wallet/presentation/pages/wallet_topup_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains("_selectedMethod = 'card'")));
    expect(source, isNot(contains("_selectedMethod = 'wallet'")));
    for (final method in ['cash', 'instapay', 'vodafone_cash']) {
      expect(source, contains("_selectedMethod = '$method'"));
    }
  });
}
