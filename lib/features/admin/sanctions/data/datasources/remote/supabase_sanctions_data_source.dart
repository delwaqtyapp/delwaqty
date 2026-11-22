import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/sanctions/domain/entities/sanction.dart';

class SupabaseSanctionsDataSource {
  SupabaseSanctionsDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Sanction>> getSanctions({bool? active}) async {
    var query = _client.from('sanctions').select();
    if (active != null) query = query.eq('is_active', active);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => Sanction.fromJson(r)).toList();
  }

  Future<List<Sanction>> getUserSanctions(String targetUserId) async {
    final rows = await _client
        .from('sanctions')
        .select()
        .eq('target_user_id', targetUserId)
        .order('created_at', ascending: false);
    return rows.map((r) => Sanction.fromJson(r)).toList();
  }

  Future<Sanction> getSanctionById(String id) async {
    final row = await _client.from('sanctions').select().eq('id', id).single();
    return Sanction.fromJson(row);
  }

  Future<String> issueSanction({
    required String memberId,
    required String sanctionType,
    required String reason,
    int durationDays = 0,
    double amount = 0,
    String? evidenceUrl,
  }) async {
    final params = <String, dynamic>{
      'p_member_id': memberId,
      'p_sanction_type': sanctionType,
      'p_reason': reason,
      'p_duration_days': durationDays,
      'p_amount': amount,
    };
    if (evidenceUrl != null) params['p_evidence_url'] = evidenceUrl;

    final result = await _client.rpc('issue_sanction', params: params);
    return result as String;
  }

  Future<void> revokeSanction({
    required String sanctionId,
    required String reason,
  }) async {
    await _client.rpc(
      'revoke_sanction',
      params: {'p_sanction_id': sanctionId, 'p_reason': reason},
    );
  }

  /// Platform-wide penalty policy: days a customer account is suspended
  /// after the 3rd cancellation in one Cairo calendar month.
  Future<int> getCancelSuspensionDays() async {
    final row = await _client
        .from('platform_settings')
        .select('cancel_suspension_days')
        .eq('id', 'default')
        .single();
    return (row['cancel_suspension_days'] as num?)?.toInt() ?? 5;
  }

  /// Owner-only on the server: set_cancel_suspension_days rejects non-owner
  /// callers, and every change is audited.
  Future<int> setCancelSuspensionDays(int days, {String? reason}) async {
    final result = await _client.rpc(
      'set_cancel_suspension_days',
      params: {
        'p_days': days,
        if (reason != null && reason.trim().isNotEmpty) 'p_reason': reason,
      },
    );
    return (result as num).toInt();
  }
}
