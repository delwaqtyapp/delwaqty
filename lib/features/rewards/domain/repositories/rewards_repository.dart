import 'package:delwaqty/features/rewards/domain/entities/member_reward.dart';

abstract class RewardsRepository {
  Future<List<MemberReward>> getMyRewards(String userId);
}
