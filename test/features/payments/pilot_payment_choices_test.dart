import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout offers only the three working pilot payment methods', () {
    final source = File(
      'lib/features/customer/commerce/presentation/pages/checkout_page.dart',
    ).readAsStringSync();
    // The payment selector is a ChoiceChip row gated on
    // `_paymentMethod == '<method>'` (reworked from SegmentedButton in the
    // top-up-history UI branch). The guard is unchanged: exactly the three
    // working pilot methods, no card/wallet.
    final choices = RegExp("_paymentMethod == '([^']+)'")
        .allMatches(source)
        .map((match) => match.group(1))
        .toList();
    expect(choices, ['cash', 'instapay', 'vodafone_cash']);
    expect(source, isNot(contains("_paymentMethod == 'card'")));
    expect(source, isNot(contains("_paymentMethod == 'wallet'")));
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
