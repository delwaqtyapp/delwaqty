import 'package:delwaqty/features/_shared/rewards/domain/entities/member_reward.dart';

abstract class RewardsRepository {
  Future<List<MemberReward>> getMyRewards(String userId);
}
