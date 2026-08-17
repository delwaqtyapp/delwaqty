import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/repositories/profile_repository.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository mockRepository;

  final testUser = User(
    id: 'user-123',
    email: 'test@example.com',
    fullName: 'John Doe',
    createdAt: DateTime(2024, 1, 15),
  );

  setUp(() {
    mockRepository = MockProfileRepository();
  });

  group('GetProfileUseCase', () {
    late GetProfileUseCase useCase;

    setUp(() {
      useCase = GetProfileUseCase(mockRepository);
    });

    test('calls getProfile on repository with correct userId', () async {
      when(
        () => mockRepository.getProfile('user-123'),
      ).thenAnswer((_) async => testUser);

      final result = await useCase('user-123');

      expect(result, testUser);
      verify(() => mockRepository.getProfile('user-123')).called(1);
    });

    test('propagates exceptions from repository', () async {
      when(
        () => mockRepository.getProfile(any()),
      ).thenThrow(Exception('Profile not found'));

      expect(() => useCase('user-123'), throwsA(isA<Exception>()));
    });
  });

  group('UpdateProfileUseCase', () {
    late UpdateProfileUseCase useCase;

    setUp(() {
      useCase = UpdateProfileUseCase(mockRepository);
    });

    test('calls updateProfile on repository', () async {
      final data = {'full_name': 'Jane Doe'};
      final updatedUser = testUser.copyWith(fullName: 'Jane Doe');

      when(
        () => mockRepository.updateProfile(userId: 'user-123', data: data),
      ).thenAnswer((_) async => updatedUser);

      final result = await useCase(userId: 'user-123', data: data);

      expect(result.fullName, 'Jane Doe');
      verify(
        () => mockRepository.updateProfile(userId: 'user-123', data: data),
      ).called(1);
    });
  });

  group('UpdateDateOfBirthUseCase', () {
    late UpdateDateOfBirthUseCase useCase;

    setUp(() {
      useCase = UpdateDateOfBirthUseCase(mockRepository);
    });

    test('calls updateDateOfBirth on repository', () async {
      final dob = DateTime(1990, 5, 14);
      final updatedUser = testUser.copyWith(dateOfBirth: dob);

      when(
        () => mockRepository.updateDateOfBirth(
          userId: 'user-123',
          dateOfBirth: dob,
        ),
      ).thenAnswer((_) async => updatedUser);

      final result = await useCase(
        userId: 'user-123',
        dateOfBirth: dob,
      );

      expect(result.dateOfBirth, dob);
      verify(
        () => mockRepository.updateDateOfBirth(
          userId: 'user-123',
          dateOfBirth: dob,
        ),
      ).called(1);
    });

    test('calls updateDateOfBirth on repository with null (clear)', () async {
      final updatedUser = testUser.copyWith(dateOfBirth: null);

      when(
        () => mockRepository.updateDateOfBirth(
          userId: 'user-123',
          dateOfBirth: null,
        ),
      ).thenAnswer((_) async => updatedUser);

      final result = await useCase(userId: 'user-123', dateOfBirth: null);

      expect(result.dateOfBirth, isNull);
      verify(
        () => mockRepository.updateDateOfBirth(
          userId: 'user-123',
          dateOfBirth: null,
        ),
      ).called(1);
    });
  });

  group('UploadAvatarUseCase', () {
    late UploadAvatarUseCase useCase;

    setUp(() {
      useCase = UploadAvatarUseCase(mockRepository);
    });

    test('calls uploadAvatar on repository', () async {
      const avatarUrl = 'https://example.com/avatar.jpg';
      when(
        () => mockRepository.uploadAvatar(
          userId: 'user-123',
          bytes: any(named: 'bytes'),
          fileName: 'avatar.jpg',
        ),
      ).thenAnswer((_) async => avatarUrl);

      final result = await useCase(
        userId: 'user-123',
        bytes: [1, 2, 3],
        fileName: 'avatar.jpg',
      );

      expect(result, avatarUrl);
      verify(
        () => mockRepository.uploadAvatar(
          userId: 'user-123',
          bytes: [1, 2, 3],
          fileName: 'avatar.jpg',
        ),
      ).called(1);
    });
  });

  group('UploadDocumentUseCase', () {
    late UploadDocumentUseCase useCase;

    setUp(() {
      useCase = UploadDocumentUseCase(mockRepository);
    });

    test('calls uploadDocument on repository', () async {
      const documentUrl = 'https://example.com/id-card.jpg';
      when(
        () => mockRepository.uploadDocument(
          userId: 'user-123',
          bytes: any(named: 'bytes'),
          fileName: 'id-card.jpg',
        ),
      ).thenAnswer((_) async => documentUrl);

      final result = await useCase(
        userId: 'user-123',
        bytes: [1, 2, 3],
        fileName: 'id-card.jpg',
      );

      expect(result, documentUrl);
      verify(
        () => mockRepository.uploadDocument(
          userId: 'user-123',
          bytes: [1, 2, 3],
          fileName: 'id-card.jpg',
        ),
      ).called(1);
    });
  });

  group('ReapplyVerificationUseCase', () {
    late ReapplyVerificationUseCase useCase;

    setUp(() {
      useCase = ReapplyVerificationUseCase(mockRepository);
    });

    test('calls reapplyVerification on repository', () async {
      when(
        () => mockRepository.reapplyVerification(
          userId: 'user-123',
          idCardUrl: 'https://example.com/id-card.jpg',
          profilePhotoUrl: 'https://example.com/photo.jpg',
        ),
      ).thenAnswer((_) async {});

      await useCase(
        userId: 'user-123',
        idCardUrl: 'https://example.com/id-card.jpg',
        profilePhotoUrl: 'https://example.com/photo.jpg',
      );

      verify(
        () => mockRepository.reapplyVerification(
          userId: 'user-123',
          idCardUrl: 'https://example.com/id-card.jpg',
          profilePhotoUrl: 'https://example.com/photo.jpg',
        ),
      ).called(1);
    });

    test('propagates exceptions from repository', () async {
      when(
        () => mockRepository.reapplyVerification(
          userId: any(named: 'userId'),
          idCardUrl: any(named: 'idCardUrl'),
          profilePhotoUrl: any(named: 'profilePhotoUrl'),
        ),
      ).thenThrow(Exception('Not rejected'));

      expect(
        () => useCase(
          userId: 'user-123',
          idCardUrl: 'https://example.com/id-card.jpg',
          profilePhotoUrl: 'https://example.com/photo.jpg',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
