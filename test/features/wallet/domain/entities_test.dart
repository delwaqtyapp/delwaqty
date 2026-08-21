import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/wallet/domain/entities/wallet_balance.dart';
import 'package:delwaqty/features/customer/wallet/domain/entities/wallet_transaction.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  group('TransactionType', () {
    test('enum has all values', () {
      expect(TransactionType.values.length, 5);
      expect(TransactionType.topup.name, 'topup');
      expect(TransactionType.payment.name, 'payment');
      expect(TransactionType.refund.name, 'refund');
      expect(TransactionType.withdrawal.name, 'withdrawal');
      expect(TransactionType.transfer.name, 'transfer');
    });
  });

  group('WalletBalance', () {
    test('fromJson creates WalletBalance from JSON', () {
      final json = {
        'id': 'wb1',
        'userId': 'u1',
        'balance': 500.0,
        'currency': 'ج.م',
        'updatedAt': now.toIso8601String(),
      };

      final wallet = WalletBalance.fromJson(json);
      expect(wallet.id, 'wb1');
      expect(wallet.userId, 'u1');
      expect(wallet.balance, 500.0);
      expect(wallet.currency, 'ج.م');
    });

    test('toJson serializes correctly', () {
      final wallet = WalletBalance(
        id: 'wb1',
        userId: 'u1',
        updatedAt: now,
      );

      final json = wallet.toJson();
      expect(json['id'], 'wb1');
      expect(json['userId'], 'u1');
      expect(json['balance'], 0.0);
      expect(json['currency'], 'ج.م');
    });

    test('fromJson roundtrip preserves data', () {
      final original = WalletBalance(
        id: 'wb1',
        userId: 'u1',
        balance: 1250.50,
        currency: 'ج.م',
        updatedAt: now,
      );

      final restored = WalletBalance.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = WalletBalance(
        id: 'wb1',
        userId: 'u1',
        balance: 500.0,
        updatedAt: now,
      );
      final b = WalletBalance(
        id: 'wb1',
        userId: 'u1',
        balance: 500.0,
        updatedAt: now,
      );
      final c = WalletBalance(
        id: 'wb2',
        userId: 'u2',
        balance: 1000.0,
        updatedAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final wallet = WalletBalance(
        id: 'wb1',
        userId: 'u1',
        balance: 500.0,
        updatedAt: now,
      );

      final updated = wallet.copyWith(balance: 750.0);
      expect(updated.balance, 750.0);
      expect(updated.id, 'wb1');
      expect(updated.userId, 'u1');
      expect(wallet.balance, 500.0);
    });

    test('defaults are applied correctly', () {
      final wallet = WalletBalance(
        id: 'wb1',
        userId: 'u1',
        updatedAt: now,
      );

      expect(wallet.balance, 0.0);
      expect(wallet.currency, 'ج.م');
    });
  });

  group('WalletTransaction', () {
    test('fromJson creates WalletTransaction from JSON', () {
      final json = {
        'id': 'wt1',
        'walletId': 'wb1',
        'type': 'topup',
        'amount': 100.0,
        'description': 'Wallet top-up',
        'referenceId': 'ref1',
        'createdAt': now.toIso8601String(),
      };

      final tx = WalletTransaction.fromJson(json);
      expect(tx.id, 'wt1');
      expect(tx.walletId, 'wb1');
      expect(tx.type, TransactionType.topup);
      expect(tx.amount, 100.0);
      expect(tx.description, 'Wallet top-up');
      expect(tx.referenceId, 'ref1');
    });

    test('toJson serializes correctly', () {
      final tx = WalletTransaction(
        id: 'wt1',
        walletId: 'wb1',
        type: TransactionType.payment,
        amount: 50.0,
        description: 'Order payment',
        createdAt: now,
      );

      final json = tx.toJson();
      expect(json['id'], 'wt1');
      expect(json['type'], 'payment');
      expect(json['amount'], 50.0);
      expect(json['referenceId'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = WalletTransaction(
        id: 'wt1',
        walletId: 'wb1',
        type: TransactionType.refund,
        amount: 25.0,
        description: 'Refund for order',
        referenceId: 'order1',
        createdAt: now,
      );

      final restored = WalletTransaction.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = WalletTransaction(
        id: 'wt1',
        walletId: 'wb1',
        type: TransactionType.topup,
        amount: 100.0,
        description: 'Top-up',
        createdAt: now,
      );
      final b = WalletTransaction(
        id: 'wt1',
        walletId: 'wb1',
        type: TransactionType.topup,
        amount: 100.0,
        description: 'Top-up',
        createdAt: now,
      );
      final c = WalletTransaction(
        id: 'wt2',
        walletId: 'wb1',
        type: TransactionType.payment,
        amount: 50.0,
        description: 'Payment',
        createdAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final tx = WalletTransaction(
        id: 'wt1',
        walletId: 'wb1',
        type: TransactionType.topup,
        amount: 100.0,
        description: 'Top-up',
        createdAt: now,
      );

      final updated = tx.copyWith(amount: 200.0, description: 'Updated');
      expect(updated.amount, 200.0);
      expect(updated.description, 'Updated');
      expect(updated.id, 'wt1');
      expect(tx.amount, 100.0);
    });
  });
}
