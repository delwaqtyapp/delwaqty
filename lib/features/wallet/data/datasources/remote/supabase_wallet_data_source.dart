import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/wallet/domain/entities/wallet_balance.dart';
import 'package:delwaqty/features/wallet/domain/entities/wallet_transaction.dart';

final supabaseWalletDataSourceProvider = Provider<SupabaseWalletDataSource>((ref) {
  return SupabaseWalletDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

class SupabaseWalletDataSource {
  SupabaseWalletDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _walletsTable = 'wallets';
  static const String _transactionsTable = 'wallet_transactions';

  WalletBalance _balanceFromRow(Map<String, dynamic> row) {
    return WalletBalance(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      balance: (row['balance'] as num?)?.toDouble() ?? 0.0,
      currency: row['currency'] as String? ?? 'SAR',
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  WalletTransaction _transactionFromRow(Map<String, dynamic> row) {
    final typeStr = row['type'] as String;
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TransactionType.payment,
    );
    return WalletTransaction(
      id: row['id'] as String,
      walletId: row['wallet_id'] as String,
      type: type,
      amount: (row['amount'] as num).toDouble(),
      description: row['description'] as String? ?? '',
      referenceId: row['reference_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<WalletBalance> getBalance(String userId) async {
    try {
      final data = await _client
          .from(_walletsTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        return _balanceFromRow(data as Map<String, dynamic>);
      }

      final created = await _client
          .from(_walletsTable)
          .insert({
            'user_id': userId,
            'balance': 0.0,
            'currency': 'SAR',
          })
          .select()
          .single();

      return _balanceFromRow(created as Map<String, dynamic>);
    } catch (e, stack) {
      _logger.e('Failed to get wallet balance', e, stack);
      rethrow;
    }
  }

  Future<List<WalletTransaction>> getTransactions(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final wallet = await _client
          .from(_walletsTable)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (wallet == null) return [];

      final data = await _client
          .from(_transactionsTable)
          .select()
          .eq('wallet_id', wallet['id'] as String)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List)
          .map((row) => _transactionFromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get wallet transactions', e, stack);
      rethrow;
    }
  }

  Future<WalletTransaction> topUp(String userId, double amount, String method) async {
    try {
      final balance = await getBalance(userId);

      await _client.from(_walletsTable).update({
        'balance': balance.balance + amount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', balance.id);

      final tx = await _client
          .from(_transactionsTable)
          .insert({
            'wallet_id': balance.id,
            'type': 'topup',
            'amount': amount,
            'description': 'Top up via $method',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return _transactionFromRow(tx as Map<String, dynamic>);
    } catch (e, stack) {
      _logger.e('Failed to top up wallet', e, stack);
      rethrow;
    }
  }

  Future<WalletTransaction> pay(
    String userId,
    double amount,
    String description, {
    String? referenceId,
  }) async {
    try {
      final balance = await getBalance(userId);

      if (balance.balance < amount) {
        throw Exception('Insufficient balance');
      }

      await _client.from(_walletsTable).update({
        'balance': balance.balance - amount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', balance.id);

      final tx = await _client
          .from(_transactionsTable)
          .insert({
            'wallet_id': balance.id,
            'type': 'payment',
            'amount': amount,
            'description': description,
            'reference_id': referenceId,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return _transactionFromRow(tx as Map<String, dynamic>);
    } catch (e, stack) {
      _logger.e('Failed to pay from wallet', e, stack);
      rethrow;
    }
  }

  Future<WalletTransaction?> getTransactionById(String transactionId) async {
    try {
      final data = await _client
          .from(_transactionsTable)
          .select()
          .eq('id', transactionId)
          .maybeSingle();

      if (data == null) return null;
      return _transactionFromRow(data as Map<String, dynamic>);
    } catch (e, stack) {
      _logger.e('Failed to get transaction: $transactionId', e, stack);
      rethrow;
    }
  }
}
