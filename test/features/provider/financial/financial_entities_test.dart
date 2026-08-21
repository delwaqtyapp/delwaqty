import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/provider/financial/domain/entities/financial_entities.dart';

void main() {
  group('FinancialSummary.fromJson', () {
    test('parses balances, grace, commission and transactions', () {
      final json = <String, dynamic>{
        'balance': 120.5,
        'grace_limit': 4,
        'grace_used': 1,
        'grace_remaining': 3,
        'commission_rate': 7.0,
        'pending_topups': 2,
        'recent_transactions': [
          <String, dynamic>{
            'id': 't1',
            'type': 'credit',
            'amount': 50.0,
            'description': 'Top-up',
            'balance_after': 170.5,
            'created_at': '2026-08-22T10:00:00.000Z',
          }
        ],
      };
      final s = FinancialSummary.fromJson(json);
      expect(s.balance, 120.5);
      expect(s.graceLimit, 4);
      expect(s.graceRemaining, 3);
      expect(s.commissionRate, 7.0);
      expect(s.pendingTopups, 2);
      expect(s.recentTransactions.length, 1);
      expect(s.recentTransactions.first.amount, 50.0);
    });

    test('handles missing fields with defaults', () {
      final s = FinancialSummary.fromJson(<String, dynamic>{});
      expect(s.balance, 0);
      expect(s.graceLimit, 0);
      expect(s.recentTransactions, isEmpty);
    });
  });

  group('GraceInfo.fromJson', () {
    test('parses limit/used/remaining', () {
      final g = GraceInfo.fromJson(<String, dynamic>{
        'grace_limit': 6,
        'grace_used': 2,
        'grace_remaining': 4,
      });
      expect(g.limit, 6);
      expect(g.used, 2);
      expect(g.remaining, 4);
    });
  });

  group('TopupRequest.fromJson', () {
    test('parses status, amount and dates', () {
      final t = TopupRequest.fromJson(<String, dynamic>{
        'id': 'r1',
        'amount': 100.0,
        'currency': 'SAR',
        'status': 'approved',
        'payment_method': 'bank_transfer',
        'transfer_reference': 'REF123',
        'created_at': '2026-08-22T10:00:00.000Z',
      });
      expect(t.amount, 100.0);
      expect(t.status, 'approved');
      expect(t.transferReference, 'REF123');
    });
  });
}
