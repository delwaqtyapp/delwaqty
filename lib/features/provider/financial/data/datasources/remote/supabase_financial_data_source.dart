import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/provider/financial/domain/entities/financial_entities.dart';

final providerFinancialDataSourceProvider =
    Provider<ProviderFinancialDataSource>((ref) {
      return ProviderFinancialDataSource(
        ref.watch(supabaseClientProvider),
      );
    });

class ProviderFinancialDataSource {
  ProviderFinancialDataSource(this._client);
  final SupabaseClient _client;

  Future<FinancialSummary> getMyFinancialSummary() async {
    final data = await _client.rpc('get_my_financial_summary');
    return FinancialSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<GraceInfo> getMyGrace() async {
    final data = await _client.rpc('get_my_grace');
    return GraceInfo.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<TopupRequest>> getMyTopupRequests() async {
    final data = await _client.rpc('get_my_topup_requests');
    final map = Map<String, dynamic>.from(data as Map);
    return (map['requests'] as List? ?? [])
        .map((e) => TopupRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> resolveReceiver() async {
    final data = await _client.rpc('resolve_receiver_for_account');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createTopupRequest({
    required double amount,
    required String paymentMethod,
    String? transferReference,
    String? proofPath,
    String? message,
  }) async {
    final data = await _client.rpc(
      'create_topup_request',
      params: {
        'p_amount': amount,
        'p_payment_method': paymentMethod,
        'p_transfer_reference': transferReference,
        'p_proof_path': proofPath,
        'p_message': message,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
