import 'package:delwaqty/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError(
    'AuthRepository must be overridden at the data layer',
  );
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.watch(authRepositoryProvider));
});

class SignInUseCase {
  SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResult> call({
    required String email,
    required String password,
  }) {
    return _repository.signInWithEmail(email: email, password: password);
  }
}

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

class SignUpUseCase {
  SignUpUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResult> call({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _repository.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
    );
  }
}

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

class SignOutUseCase {
  SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  return ResetPasswordUseCase(ref.watch(authRepositoryProvider));
});

class ResetPasswordUseCase {
  ResetPasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String email}) {
    return _repository.resetPassword(email: email);
  }
}
