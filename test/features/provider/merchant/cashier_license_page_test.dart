import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/cashier_license_page.dart';

void main() {
  group('cashierLicenseErrorOf', () {
    test('maps the server error codes', () {
      expect(
        cashierLicenseErrorOf(Exception('TRIAL_ALREADY_USED')),
        CashierLicenseError.trialUsed,
      );
      expect(
        cashierLicenseErrorOf(Exception('PAID_PLANS_REQUIRE_ADMIN')),
        CashierLicenseError.adminOnly,
      );
      expect(
        cashierLicenseErrorOf(Exception('INVALID_DAYS')),
        CashierLicenseError.invalidDays,
      );
      expect(
        cashierLicenseErrorOf(Exception('Not authorized')),
        CashierLicenseError.notAllowed,
      );
      expect(
        cashierLicenseErrorOf(Exception('boom')),
        CashierLicenseError.other,
      );
    });
  });

  group('formatCashierCode', () {
    test('groups 12 digits as 4-4-4', () {
      expect(formatCashierCode('264755798237'), '2647-5579-8237');
      expect(formatCashierCode('2647-5579-8237'), '2647-5579-8237');
    });
    test('leaves other shapes alone', () {
      expect(formatCashierCode('abc'), 'abc');
    });
  });

  test('admin may only issue the paid plans the server accepts', () {
    expect(cashierPaidPlans, [
      'core_monthly',
      'core_quarterly',
      'core_semiannual',
      'core_annual',
      'core_lifetime',
    ]);
  });
}
