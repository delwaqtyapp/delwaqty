import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/rewards/domain/entities/member_reward.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final supabaseRewardsDataSourceProvider = Provider<SupabaseRewardsDataSource>((
  ref,
) {
  return SupabaseRewardsDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseRewardsDataSource {
  SupabaseRewardsDataSource(this._client);

  final SupabaseClient _client;

  static const String _tableName = 'member_rewards';

  Future<List<MemberReward>> getMyRewards(String userId) async {
    final data = await _client
        .from(_tableName)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  MemberReward _fromRow(Map<String, dynamic> row) {
    return MemberReward(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      rewardType: RewardType.values.firstWhere(
        (t) => t.name == row['reward_type'],
      ),
      periodKey: row['period_key'] as String,
      benefit: row['benefit'] as Map<String, dynamic>?,
      campaignId: row['campaign_id'] as String?,
      status: RewardStatus.values.firstWhere(
        (s) => s.name == row['status'],
      ),
      notifiedAt: row['notified_at'] != null
          ? DateTime.tryParse(row['notified_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
