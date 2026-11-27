import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/provider/merchant/domain/cashier_pricing.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/cashier_license_page.dart';

void main() {
  test('owner price list (2026-11-27)', () {
    expect(cashierPlanPriceEgp('core_monthly'), 100);
    expect(cashierPlanPriceEgp('core_quarterly'), 250);
    expect(cashierPlanPriceEgp('core_semiannual'), 450);
    expect(cashierPlanPriceEgp('core_annual'), 1000);
    expect(cashierPlanPriceEgp('core_lifetime'), 2999);
  });

  test('trial has no price and every paid plan has one', () {
    expect(cashierPlanPriceEgp('trial'), isNull);
    for (final p in cashierPaidPlans) {
      expect(cashierPlanPriceEgp(p), isNotNull, reason: p);
    }
  });
}
