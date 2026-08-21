import 'package:delwaqty/features/customer/wallet/domain/entities/wallet_balance.dart';
import 'package:delwaqty/features/customer/wallet/domain/entities/wallet_transaction.dart';
import 'package:delwaqty/features/customer/wallet/domain/repositories/wallet_repository.dart';
import 'package:delwaqty/features/customer/wallet/data/datasources/remote/supabase_wallet_data_source.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._dataSource);

  final SupabaseWalletDataSource _dataSource;

  @override
  Future<WalletBalance> getBalance(String userId) => _dataSource.getBalance(userId);

  @override
  Future<List<WalletTransaction>> getTransactions(String userId, {int limit = 20, int offset = 0}) =>
      _dataSource.getTransactions(userId, limit: limit, offset: offset);

  @override
  Future<WalletTransaction> topUp(String userId, double amount, String method) =>
      _dataSource.topUp(userId, amount, method);

  @override
  Future<WalletTransaction> pay(String userId, double amount, String description, {String? referenceId}) =>
      _dataSource.pay(userId, amount, description, referenceId: referenceId);

  @override
  Future<WalletTransaction?> getTransactionById(String transactionId) =>
      _dataSource.getTransactionById(transactionId);
}
