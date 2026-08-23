import 'package:delwaqty/features/admin/financial/domain/entities/admin_financial_entities.dart';

abstract class AdminFinancialRepository {
  Future<List<AdminTopupRequest>> listTopupRequests(String? status);
  Future<Map<String, dynamic>> approveTopup(String requestId);
  Future<Map<String, dynamic>> rejectTopup(String requestId, String? reason);
  Future<CollectionSummary> collectionSummary();
  Future<List<CollectionRecord>> listCollections();
  Future<List<SettlementRecord>> listSettlements();
  Future<Map<String, dynamic>> submitSettlement({
    required double amount,
    required String method,
    String? reference,
    String? proofPath,
    String? message,
  });
  Future<Map<String, dynamic>> approveSettlement(String settlementId);
  Future<Map<String, dynamic>> rejectSettlement(
    String settlementId,
    String? reason,
  );
  Future<GraceAccount?> getGrace(String userId);
  Future<Map<String, dynamic>> setGrace({
    required String userId,
    required int newLimit,
    String? reason,
  });
  Future<List<ReceivingAccount>> listPlatformReceivingAccounts();
  Future<List<Map<String, dynamic>>> listAdminReceivingWallets();
  Future<String> createAdminReceivingWallet({
    required String regionId,
    required String methodType,
    String? walletNumber,
    String? accountName,
    String? provider,
  });
  Future<String> ownerCreateReceivingAccount({
    required String methodType,
    required String displayName,
    String? accountName,
    String? accountNumber,
    String? walletNumber,
    String? instructions,
  });
  Future<bool> ownerUpdateReceivingAccount({
    required String id,
    bool? isActive,
    String? displayName,
    String? accountName,
    String? accountNumber,
    String? walletNumber,
    String? instructions,
  });
  Future<Map<String, dynamic>> platformCollectionAudit();
  Future<Map<String, dynamic>> platformSettlementAudit();
  Future<Map<String, dynamic>> adminDirectTopup({
    required String accountType,
    required String accountId,
    required double amount,
    String? note,
  });
}
