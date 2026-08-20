import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';
import 'package:delwaqty/domain/repositories/user_repository.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/pages/pending_verification_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MockUserRepository extends Mock implements UserRepository {}

final _rejectedUser = User(
  id: 'u1',
  email: 'merchant@example.com',
  fullName: 'Rejected Merchant',
  userType: UserType.merchant,
  verificationStatus: VerificationStatus.rejected,
  createdAt: DateTime(2024),
);

final _pendingUser = User(
  id: 'u1',
  email: 'merchant@example.com',
  fullName: 'Pending Merchant',
  userType: UserType.merchant,
  idCardUrl: 'https://example.com/id.jpg',
  profilePhotoUrl: 'https://example.com/photo.jpg',
  createdAt: DateTime(2024),
);

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.pendingVerification();
}

Widget _buildTestApp(MockUserRepository repo) {
  return ProviderScope(
    overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: PendingVerificationPage(),
    ),
  );
}

void main() {
  late MockUserRepository mockRepo;

  setUp(() {
    mockRepo = MockUserRepository();
  });

  testWidgets('shows rejected state when verification was rejected',
      (tester) async {
    when(() => mockRepo.getCurrentUser())
        .thenAnswer((_) async => _rejectedUser);

    await tester.pumpWidget(_buildTestApp(mockRepo));
    await tester.pumpAndSettle();

    expect(find.text('Verification rejected'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    verify(() => mockRepo.getCurrentUser()).called(1);
  });

  testWidgets('shows rejection reason when provided', (tester) async {
    final user = _rejectedUser.copyWith(rejectionReason: 'Blurry ID card');
    when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => user);

    await tester.pumpWidget(_buildTestApp(mockRepo));
    await tester.pumpAndSettle();

    expect(find.text('Reason: Blurry ID card'), findsOneWidget);
  });

  testWidgets('re-apply button opens the documents flow', (tester) async {
    when(() => mockRepo.getCurrentUser())
        .thenAnswer((_) async => _rejectedUser);

    await tester.pumpWidget(_buildTestApp(mockRepo));
    await tester.pumpAndSettle();

    expect(find.text('Re-apply'), findsOneWidget);
    await tester.tap(find.text('Re-apply'));
    await tester.pumpAndSettle();

    expect(find.text('Complete your verification'), findsOneWidget);
    expect(find.text('Submit Documents'), findsOneWidget);
  });

  testWidgets('shows review-only state when docs present and pending',
      (tester) async {
    when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => _pendingUser);

    await tester.pumpWidget(_buildTestApp(mockRepo));
    await tester.pumpAndSettle();

    expect(find.text('Verification rejected'), findsNothing);
    verify(() => mockRepo.getCurrentUser()).called(1);
  });
}
