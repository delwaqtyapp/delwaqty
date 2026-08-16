import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/rewards/domain/entities/member_reward.dart';
import 'package:delwaqty/features/rewards/domain/repositories/rewards_repository.dart';
import 'package:delwaqty/features/rewards/data/datasources/remote/supabase_rewards_data_source.dart';

final supabaseRewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  return SupabaseRewardsRepositoryImpl(
    ref.watch(supabaseRewardsDataSourceProvider),
  );
});

class SupabaseRewardsRepositoryImpl implements RewardsRepository {
  SupabaseRewardsRepositoryImpl(this._dataSource);

  final SupabaseRewardsDataSource _dataSource;

  @override
  Future<List<MemberReward>> getMyRewards(String userId) async {
    try {
      return await _dataSource.getMyRewards(userId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
