import 'package:delwaqty/features/wallet/domain/entities/wallet_balance.dart';
import 'package:delwaqty/features/wallet/domain/entities/wallet_transaction.dart';

abstract interface class WalletRepository {
  Future<WalletBalance> getBalance(String userId);
  Future<List<WalletTransaction>> getTransactions(String userId, {int limit, int offset});
  Future<WalletTransaction> topUp(String userId, double amount, String method);
  Future<WalletTransaction> pay(String userId, double amount, String description, {String? referenceId});
  Future<WalletTransaction?> getTransactionById(String transactionId);
}
