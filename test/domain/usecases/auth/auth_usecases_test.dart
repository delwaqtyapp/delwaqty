import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/repositories/auth_repository.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  setUpAll(() {
    registerFallbackValue(const AuthResult(
      userId: '',
      email: '',
    ));
    registerFallbackValue(UserType.customer);
    registerFallbackValue(Uint8List(0));
  });

  group('SignInUseCase', () {
    late SignInUseCase useCase;

    setUp(() {
      useCase = SignInUseCase(mockRepository);
    });

    test('calls signInWithEmail on repository', () async {
      const email = 'test@example.com';
      const password = 'password123';
      const expectedResult = AuthResult(userId: '1', email: email);

      when(() => mockRepository.signInWithEmail(
            email: email,
            password: password,
          )).thenAnswer((_) async => expectedResult);

      final result = await useCase(email: email, password: password);

      expect(result, expectedResult);
      verify(() => mockRepository.signInWithEmail(
            email: email,
            password: password,
          )).called(1);
    });

    test('propagates exceptions from repository', () async {
      when(() => mockRepository.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Auth failed'));

      expect(
        () => useCase(email: 'test@example.com', password: 'wrong'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SignUpUseCase', () {
    late SignUpUseCase useCase;

    setUp(() {
      useCase = SignUpUseCase(mockRepository);
    });

    test('calls signUpWithEmail on repository', () async {
      const email = 'test@example.com';
      const password = 'password123';
      const fullName = 'John Doe';
      const expectedResult = AuthResult(userId: '1', email: email);

      when(() => mockRepository.signUpWithEmail(
            email: email,
            password: password,
            fullName: fullName,
            userType: any(named: 'userType'),
            language: any(named: 'language'),
            idCardBytes: any(named: 'idCardBytes'),
            idCardFileName: any(named: 'idCardFileName'),
            profilePhotoBytes: any(named: 'profilePhotoBytes'),
            profilePhotoFileName: any(named: 'profilePhotoFileName'),
          )).thenAnswer((_) async => expectedResult);

      final result = await useCase(
        email: email,
        password: password,
        fullName: fullName,
        userType: UserType.delivery,
        language: 'ar',
        idCardBytes: Uint8List.fromList([1, 2, 3]),
        idCardFileName: 'id.jpg',
        profilePhotoBytes: Uint8List.fromList([4, 5, 6]),
        profilePhotoFileName: 'photo.jpg',
      );

      expect(result, expectedResult);
      verify(() => mockRepository.signUpWithEmail(
            email: email,
            password: password,
            fullName: fullName,
            userType: UserType.delivery,
            language: 'ar',
            idCardBytes: any(named: 'idCardBytes'),
            idCardFileName: 'id.jpg',
            profilePhotoBytes: any(named: 'profilePhotoBytes'),
            profilePhotoFileName: 'photo.jpg',
          )).called(1);
    });
  });

  group('SignOutUseCase', () {
    late SignOutUseCase useCase;

    setUp(() {
      useCase = SignOutUseCase(mockRepository);
    });

    test('calls signOut on repository', () async {
      when(() => mockRepository.signOut()).thenAnswer((_) async {});

      await useCase();

      verify(() => mockRepository.signOut()).called(1);
    });

    test('propagates exceptions from repository', () async {
      when(() => mockRepository.signOut()).thenThrow(Exception('Sign out failed'));

      expect(() => useCase(), throwsA(isA<Exception>()));
    });
  });

  group('ResetPasswordUseCase', () {
    late ResetPasswordUseCase useCase;

    setUp(() {
      useCase = ResetPasswordUseCase(mockRepository);
    });

    test('calls resetPassword on repository', () async {
      const email = 'test@example.com';
      when(() => mockRepository.resetPassword(email: email))
          .thenAnswer((_) async {});

      await useCase(email: email);

      verify(() => mockRepository.resetPassword(email: email)).called(1);
    });
  });
}
