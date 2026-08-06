import 'dart:typed_data';

import 'package:delwaqty/domain/enums/user_type.dart';
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

  Future<AuthResult> call({required String email, required String password}) {
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
    UserType userType = UserType.customer,
    Uint8List? idCardBytes,
    String? idCardFileName,
    Uint8List? profilePhotoBytes,
    String? profilePhotoFileName,
  }) {
    return _repository.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      userType: userType,
      idCardBytes: idCardBytes,
      idCardFileName: idCardFileName,
      profilePhotoBytes: profilePhotoBytes,
      profilePhotoFileName: profilePhotoFileName,
    );
  }
}

final signInWithPhoneUseCaseProvider = Provider<SignInWithPhoneUseCase>((ref) {
  return SignInWithPhoneUseCase(ref.watch(authRepositoryProvider));
});

class SignInWithPhoneUseCase {
  SignInWithPhoneUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String phone}) {
    return _repository.signInWithPhone(phone: phone);
  }
}

final verifyOTPUseCaseProvider = Provider<VerifyOTPUseCase>((ref) {
  return VerifyOTPUseCase(ref.watch(authRepositoryProvider));
});

class VerifyOTPUseCase {
  VerifyOTPUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResult> call({required String phone, required String otp}) {
    return _repository.verifyOTP(phone: phone, otp: otp);
  }
}

final signInWithGoogleUseCaseProvider = Provider<SignInWithGoogleUseCase>((
  ref,
) {
  return SignInWithGoogleUseCase(ref.watch(authRepositoryProvider));
});

class SignInWithGoogleUseCase {
  SignInWithGoogleUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResult> call() => _repository.signInWithGoogle();
}

final signInWithAppleUseCaseProvider = Provider<SignInWithAppleUseCase>((ref) {
  return SignInWithAppleUseCase(ref.watch(authRepositoryProvider));
});

class SignInWithAppleUseCase {
  SignInWithAppleUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResult> call() => _repository.signInWithApple();
}

final signInWithFacebookUseCaseProvider = Provider<SignInWithFacebookUseCase>((
  ref,
) {
  return SignInWithFacebookUseCase(ref.watch(authRepositoryProvider));
});

class SignInWithFacebookUseCase {
  SignInWithFacebookUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResult> call() => _repository.signInWithFacebook();
}

final signInAnonymouslyUseCaseProvider = Provider<SignInAnonymouslyUseCase>((
  ref,
) {
  return SignInAnonymouslyUseCase(ref.watch(authRepositoryProvider));
});

class SignInAnonymouslyUseCase {
  SignInAnonymouslyUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResult> call() => _repository.signInAnonymously();
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

final deleteAccountUseCaseProvider = Provider<DeleteAccountUseCase>((ref) {
  return DeleteAccountUseCase(ref.watch(authRepositoryProvider));
});

class DeleteAccountUseCase {
  DeleteAccountUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.deleteAccount();
}
