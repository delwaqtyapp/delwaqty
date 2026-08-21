import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/_shared/rewards/data/datasources/remote/supabase_rewards_data_source.dart';
import 'package:delwaqty/features/_shared/rewards/data/repositories/supabase_rewards_repository_impl.dart';
import 'package:delwaqty/features/_shared/rewards/domain/entities/member_reward.dart';

class MockRewardsDataSource extends Mock implements SupabaseRewardsDataSource {}

void main() {
  late MockRewardsDataSource mockDataSource;
  late SupabaseRewardsRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockRewardsDataSource();
    repository = SupabaseRewardsRepositoryImpl(mockDataSource);
  });

  group('SupabaseRewardsRepositoryImpl.getMyRewards', () {
    test('returns rewards for the given user id', () async {
      final rewards = [
        MemberReward(
          id: 'reward-1',
          userId: 'user-123',
          rewardType: RewardType.birthday,
          periodKey: 'birthday:2026',
          status: RewardStatus.granted,
          createdAt: DateTime(2026, 7, 19),
        ),
      ];
      when(() => mockDataSource.getMyRewards('user-123')).thenAnswer(
        (_) async => rewards,
      );

      final result = await repository.getMyRewards('user-123');

      expect(result, rewards);
      verify(() => mockDataSource.getMyRewards('user-123')).called(1);
    });

    test('returns an empty list when no rewards exist', () async {
      when(() => mockDataSource.getMyRewards('user-123')).thenAnswer(
        (_) async => <MemberReward>[],
      );

      final result = await repository.getMyRewards('user-123');

      expect(result, isEmpty);
    });

    test('wraps data source errors in ServerException', () async {
      when(() => mockDataSource.getMyRewards(any())).thenThrow(
        Exception('network error'),
      );

      expect(
        () => repository.getMyRewards('user-123'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
