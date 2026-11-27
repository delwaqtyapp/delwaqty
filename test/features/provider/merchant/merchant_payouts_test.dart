import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/provider/merchant/data/merchant_payouts_api.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_payouts_page.dart';

void main() {
  group('parsePayoutAmount', () {
    test('accepts positive amounts with up to two decimals', () {
      expect(parsePayoutAmount('100'), 100);
      expect(parsePayoutAmount(' 12.5 '), 12.5);
      expect(parsePayoutAmount('12,25'), 12.25);
    });
    test('rejects zero, negative, junk and sub-cent amounts', () {
      for (final s in ['', '0', '-5', 'abc', '1.234', 'NaN', 'Infinity']) {
        expect(parsePayoutAmount(s), isNull, reason: s);
      }
    });
  });

  group('unwrapPayoutResult', () {
    test('returns the map when ok', () {
      expect(unwrapPayoutResult({'ok': true, 'id': 'x'})['id'], 'x');
    });
    test('throws the server code when refused', () {
      expect(
        () => unwrapPayoutResult({'ok': false, 'code': 'PENDING_EXISTS'}),
        throwsA(
          isA<PayoutException>().having(
            (e) => e.code,
            'code',
            'PENDING_EXISTS',
          ),
        ),
      );
    });
  });

  test('ledger parsing matches the server balance rule', () {
    final l = MerchantLedger.fromResult({
      'ok': true,
      'balance': 300,
      'entries': [
        {
          'entry_type': 'debit',
          'amount': 200,
          'created_at': '2026-11-27T10:00:00Z',
          'description': 'Payout request x',
        },
        {
          'entry_type': 'credit',
          'amount': 500,
          'created_at': '2026-11-26T10:00:00Z',
        },
      ],
    });
    expect(l.balance, 300);
    expect(l.entries.first.isCredit, isFalse);
    expect(l.entries.last.isCredit, isTrue);
    expect(l.entries.last.description, isNull);
  });

  test('payoutErrorKey exposes the server code', () {
    expect(
      payoutErrorKey(PayoutException('AMBIGUOUS_MERCHANT')),
      'AMBIGUOUS_MERCHANT',
    );
    expect(payoutErrorKey(Exception('x')), '');
  });
}
