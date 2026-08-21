import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/rewards/domain/entities/member_reward.dart';
import 'package:delwaqty/features/_shared/rewards/domain/repositories/rewards_repository.dart';
import 'package:delwaqty/features/_shared/rewards/data/repositories/supabase_rewards_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  return ref.watch(supabaseRewardsRepositoryProvider);
});

final myRewardsProvider = FutureProvider<List<MemberReward>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  final repo = ref.read(rewardsRepositoryProvider);
  return repo.getMyRewards(user.id);
});
