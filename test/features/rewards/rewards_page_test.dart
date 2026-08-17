import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/rewards/domain/entities/member_reward.dart';
import 'package:delwaqty/features/rewards/domain/repositories/rewards_repository.dart';
import 'package:delwaqty/features/rewards/presentation/pages/rewards_page.dart';
import 'package:delwaqty/features/rewards/presentation/rewards_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MockRewardsRepository extends Mock implements RewardsRepository {}

final _user = User(
  id: 'u1',
  email: 'customer@example.com',
  fullName: 'Test Customer',
  verificationStatus: VerificationStatus.approved,
  createdAt: DateTime(2024),
);

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated(user: _user);
}

Widget _buildTestApp(RewardsRepository repo) {
  return ProviderScope(
    overrides: [
      rewardsRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: RewardsPage(),
    ),
  );
}

void main() {
  late MockRewardsRepository mockRepo;

  setUp(() {
    mockRepo = MockRewardsRepository();
  });

  testWidgets('renders period, status chip and benefit code on a reward',
      (tester) async {
    final rewards = [
      MemberReward(
        id: 'r1',
        userId: 'u1',
        rewardType: RewardType.birthday,
        periodKey: 'birthday:2026',
        benefit: {'kind': 'code_copy', 'code': 'SAVE10'},
        status: RewardStatus.granted,
        createdAt: DateTime(2026, 7, 19),
      ),
      MemberReward(
        id: 'r2',
        userId: 'u1',
        rewardType: RewardType.anniversary,
        periodKey: 'anniversary:3',
        benefit: {'kind': 'none'},
        status: RewardStatus.claimed,
        createdAt: DateTime(2026, 8, 10),
      ),
    ];
    when(() => mockRepo.getMyRewards(any())).thenAnswer((_) async => rewards);

    await tester.pumpWidget(_buildTestApp(mockRepo));
    await tester.pumpAndSettle();

    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Birthday gift for 2026'), findsOneWidget);
    expect(find.text('With us for 3 years'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.text('SAVE10'), findsOneWidget);
    verify(() => mockRepo.getMyRewards(any())).called(1);
  });

  testWidgets('renders empty state and retry on failure', (tester) async {
    when(() => mockRepo.getMyRewards(any())).thenAnswer(
      (_) async => <MemberReward>[],
    );

    await tester.pumpWidget(_buildTestApp(mockRepo));
    await tester.pumpAndSettle();

    expect(find.text('No rewards yet'), findsOneWidget);
  });
}