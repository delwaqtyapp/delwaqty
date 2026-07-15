import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/repositories/user_repository.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository mockRepository;

  final testUser = User(
    id: 'user-123',
    email: 'test@example.com',
    fullName: 'John Doe',
    createdAt: DateTime(2024, 1, 15),
  );

  setUp(() {
    mockRepository = MockUserRepository();
  });

  group('GetCurrentUserUseCase', () {
    late GetCurrentUserUseCase useCase;

    setUp(() {
      useCase = GetCurrentUserUseCase(mockRepository);
    });

    test('calls getCurrentUser on repository', () async {
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => testUser);

      final result = await useCase();

      expect(result, testUser);
      verify(() => mockRepository.getCurrentUser()).called(1);
    });

    test('propagates exceptions from repository', () async {
      when(() => mockRepository.getCurrentUser())
          .thenThrow(Exception('User not found'));

      expect(() => useCase(), throwsA(isA<Exception>()));
    });
  });

  group('GetUserByIdUseCase', () {
    late GetUserByIdUseCase useCase;

    setUp(() {
      useCase = GetUserByIdUseCase(mockRepository);
    });

    test('calls getUserById on repository with correct id', () async {
      when(() => mockRepository.getUserById('user-123'))
          .thenAnswer((_) async => testUser);

      final result = await useCase('user-123');

      expect(result, testUser);
      verify(() => mockRepository.getUserById('user-123')).called(1);
    });

    test('propagates exceptions from repository', () async {
      when(() => mockRepository.getUserById(any()))
          .thenThrow(Exception('User not found'));

      expect(() => useCase('user-123'), throwsA(isA<Exception>()));
    });
  });
}
