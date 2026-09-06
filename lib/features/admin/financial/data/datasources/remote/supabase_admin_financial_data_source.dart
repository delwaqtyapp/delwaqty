import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/financial/domain/entities/admin_financial_entities.dart';

class AdminFinancialDataSource {
  AdminFinancialDataSource(this._client);
  final SupabaseClient _client;

  Future<List<AdminTopupRequest>> listTopupRequests(String? status) async {
    final res = await _client.rpc(
      'list_region_topup_requests',
      params: {'p_status': status},
    );
    if (res == null) return const [];
    final list =
        (res as Map<String, dynamic>)['requests'] as List<dynamic>? ?? [];
    return [
      for (final e in list)
        AdminTopupRequest.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<Map<String, dynamic>> approveTopup(String requestId) async {
    final res = await _client.rpc(
      'approve_topup_request',
      params: {'p_request_id': requestId},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> rejectTopup(
    String requestId,
    String? reason,
  ) async {
    final res = await _client.rpc(
      'reject_topup_request',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<CollectionSummary> collectionSummary() async {
    final res = await _client.rpc('get_region_collection_summary');
    return CollectionSummary.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<CollectionRecord>> listCollections() async {
    final res = await _client
        .from('regional_collections')
        .select()
        .order('received_at', ascending: false);
    return [
      for (final e in res as List)
        CollectionRecord.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<List<SettlementRecord>> listSettlements() async {
    final res = await _client
        .from('platform_settlements')
        .select()
        .order('created_at', ascending: false);
    return [
      for (final e in res as List)
        SettlementRecord.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<Map<String, dynamic>> submitSettlement({
    required double amount,
    required String method,
    String? reference,
    String? proofPath,
    String? message,
  }) async {
    final res = await _client.rpc(
      'submit_settlement_request',
      params: {
        'p_amount': amount,
        'p_payment_method': method,
        'p_reference': reference,
        'p_proof_path': proofPath,
        'p_message': message,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> approveSettlement(String settlementId) async {
    final res = await _client.rpc(
      'approve_settlement_request',
      params: {'p_settlement_id': settlementId},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> rejectSettlement(
    String settlementId,
    String? reason,
  ) async {
    final res = await _client.rpc(
      'reject_settlement_request',
      params: {'p_settlement_id': settlementId, 'p_reason': reason},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<GraceAccount?> getGrace(String userId) async {
    final res = await _client.rpc(
      'get_or_create_grace',
      params: {'p_user_id': userId},
    );
    if (res == null) return null;
    return GraceAccount.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Map<String, dynamic>> setGrace({
    required String userId,
    required int newLimit,
    String? reason,
  }) async {
    final res = await _client.rpc(
      'admin_set_grace',
      params: {
        'p_user_id': userId,
        'p_new_limit': newLimit,
        'p_reason': reason,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<ReceivingAccount>> listPlatformReceivingAccounts() async {
    final res = await _client.rpc('list_platform_receiving_accounts');
    if (res == null) return const [];
    final list =
        (res as Map<String, dynamic>)['accounts'] as List<dynamic>? ?? [];
    return [
      for (final e in list)
        ReceivingAccount.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<List<Map<String, dynamic>>> listAdminReceivingWallets() async {
    final res = await _client
        .from('admin_receiving_wallets')
        .select()
        .order('created_at', ascending: false);
    return [
      for (final e in res as List) Map<String, dynamic>.from(e as Map),
    ];
  }

  Future<String> createAdminReceivingWallet({
    required String regionId,
    required String methodType,
    String? walletNumber,
    String? accountName,
    String? provider,
  }) async {
    final res = await _client.rpc(
      'admin_create_receiving_wallet',
      params: {
        'p_region_id': regionId,
        'p_method_type': methodType,
        'p_wallet_number': walletNumber,
        'p_account_name': accountName,
        'p_provider': provider,
      },
    );
    return res.toString();
  }

  Future<String> ownerCreateReceivingAccount({
    required String methodType,
    required String displayName,
    String? accountName,
    String? accountNumber,
    String? walletNumber,
    String? instructions,
  }) async {
    final res = await _client.rpc(
      'owner_create_receiving_account',
      params: {
        'p_method_type': methodType,
        'p_display_name': displayName,
        'p_account_name': accountName,
        'p_account_number': accountNumber,
        'p_wallet_number': walletNumber,
        'p_instructions': instructions,
      },
    );
    return res.toString();
  }

  Future<bool> ownerUpdateReceivingAccount({
    required String id,
    bool? isActive,
    String? displayName,
    String? accountName,
    String? accountNumber,
    String? walletNumber,
    String? instructions,
  }) async {
    final res = await _client.rpc(
      'owner_update_receiving_account',
      params: {
        'p_id': id,
        'p_is_active': isActive,
        'p_display_name': displayName,
        'p_account_name': accountName,
        'p_account_number': accountNumber,
        'p_wallet_number': walletNumber,
        'p_instructions': instructions,
      },
    );
    return res as bool? ?? false;
  }

  Future<Map<String, dynamic>> platformCollectionAudit() async {
    final res = await _client.rpc('platform_collection_audit');
    if (res == null) return {};
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> platformSettlementAudit() async {
    final res = await _client.rpc('platform_settlement_audit');
    if (res == null) return {};
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> adminDirectTopup({
    required String accountType,
    required String accountId,
    required double amount,
    String? note,
  }) async {
    final res = await _client.rpc(
      'admin_direct_topup',
      params: {
        'p_account_type': accountType,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_note': note,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }
}
