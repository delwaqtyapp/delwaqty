import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/admin/financial/data/datasources/remote/supabase_admin_financial_data_source.dart';
import 'package:delwaqty/features/admin/financial/domain/entities/admin_financial_entities.dart';
import 'package:delwaqty/features/admin/financial/domain/repositories/admin_financial_repository.dart';

class AdminFinancialRepositoryImpl implements AdminFinancialRepository {
  AdminFinancialRepositoryImpl(this._source);
  final AdminFinancialDataSource _source;

  @override
  Future<List<AdminTopupRequest>> listTopupRequests(String? status) async {
    try {
      return await _source.listTopupRequests(status);
    } catch (e) {
      throw ServerException(message: 'Failed to load top-up requests: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> approveTopup(String requestId) async {
    try {
      return await _source.approveTopup(requestId);
    } catch (e) {
      throw ServerException(message: 'Failed to approve top-up: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> rejectTopup(
    String requestId,
    String? reason,
  ) async {
    try {
      return await _source.rejectTopup(requestId, reason);
    } catch (e) {
      throw ServerException(message: 'Failed to reject top-up: $e');
    }
  }

  @override
  Future<CollectionSummary> collectionSummary() async {
    try {
      return await _source.collectionSummary();
    } catch (e) {
      throw ServerException(message: 'Failed to load collection summary: $e');
    }
  }

  @override
  Future<List<CollectionRecord>> listCollections() async {
    try {
      return await _source.listCollections();
    } catch (e) {
      throw ServerException(message: 'Failed to load collections: $e');
    }
  }

  @override
  Future<List<SettlementRecord>> listSettlements() async {
    try {
      return await _source.listSettlements();
    } catch (e) {
      throw ServerException(message: 'Failed to load settlements: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> submitSettlement({
    required double amount,
    required String method,
    String? reference,
    String? proofPath,
    String? message,
  }) async {
    try {
      return await _source.submitSettlement(
        amount: amount,
        method: method,
        reference: reference,
        proofPath: proofPath,
        message: message,
      );
    } catch (e) {
      throw ServerException(message: 'Failed to submit settlement: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> approveSettlement(String settlementId) async {
    try {
      return await _source.approveSettlement(settlementId);
    } catch (e) {
      throw ServerException(message: 'Failed to approve settlement: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> rejectSettlement(
    String settlementId,
    String? reason,
  ) async {
    try {
      return await _source.rejectSettlement(settlementId, reason);
    } catch (e) {
      throw ServerException(message: 'Failed to reject settlement: $e');
    }
  }

  @override
  Future<GraceAccount?> getGrace(String userId) async {
    try {
      return await _source.getGrace(userId);
    } catch (e) {
      throw ServerException(message: 'Failed to load grace account: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> setGrace({
    required String userId,
    required int newLimit,
    String? reason,
  }) async {
    try {
      return await _source.setGrace(
        userId: userId,
        newLimit: newLimit,
        reason: reason,
      );
    } catch (e) {
      throw ServerException(message: 'Failed to set grace limit: $e');
    }
  }

  @override
  Future<List<ReceivingAccount>> listPlatformReceivingAccounts() async {
    try {
      return await _source.listPlatformReceivingAccounts();
    } catch (e) {
      throw ServerException(message: 'Failed to load receiving accounts: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listAdminReceivingWallets() async {
    try {
      return await _source.listAdminReceivingWallets();
    } catch (e) {
      throw ServerException(message: 'Failed to load receiving wallets: $e');
    }
  }

  @override
  Future<String> createAdminReceivingWallet({
    required String regionId,
    required String methodType,
    String? walletNumber,
    String? accountName,
    String? provider,
  }) async {
    try {
      return await _source.createAdminReceivingWallet(
        regionId: regionId,
        methodType: methodType,
        walletNumber: walletNumber,
        accountName: accountName,
        provider: provider,
      );
    } catch (e) {
      throw ServerException(message: 'Failed to create receiving wallet: $e');
    }
  }

  @override
  Future<String> ownerCreateReceivingAccount({
    required String methodType,
    required String displayName,
    String? accountName,
    String? accountNumber,
    String? walletNumber,
    String? instructions,
  }) async {
    try {
      return await _source.ownerCreateReceivingAccount(
        methodType: methodType,
        displayName: displayName,
        accountName: accountName,
        accountNumber: accountNumber,
        walletNumber: walletNumber,
        instructions: instructions,
      );
    } catch (e) {
      throw ServerException(message: 'Failed to create receiving account: $e');
    }
  }

  @override
  Future<bool> ownerUpdateReceivingAccount({
    required String id,
    bool? isActive,
    String? displayName,
    String? accountName,
    String? accountNumber,
    String? walletNumber,
    String? instructions,
  }) async {
    try {
      return await _source.ownerUpdateReceivingAccount(
        id: id,
        isActive: isActive,
        displayName: displayName,
        accountName: accountName,
        accountNumber: accountNumber,
        walletNumber: walletNumber,
        instructions: instructions,
      );
      } catch (e) {
        throw ServerException(message: 'Failed to update receiving account: $e');
      }
  }

  @override
  Future<Map<String, dynamic>> platformCollectionAudit() async {
    try {
      return await _source.platformCollectionAudit();
    } catch (e) {
      throw ServerException(message: 'Failed to load platform collection audit: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> platformSettlementAudit() async {
    try {
      return await _source.platformSettlementAudit();
    } catch (e) {
      throw ServerException(message: 'Failed to load platform settlement audit: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> adminDirectTopup({
    required String accountType,
    required String accountId,
    required double amount,
    String? note,
  }) async {
    try {
      return await _source.adminDirectTopup(
        accountType: accountType,
        accountId: accountId,
        amount: amount,
        note: note,
      );
    } catch (e) {
      throw ServerException(message: 'Failed to top up account: $e');
    }
  }
}
