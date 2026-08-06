import 'dart:typed_data';

import 'package:delwaqty/domain/enums/user_type.dart';

enum AuthProviderType { email, phone, google, apple, facebook, anonymous }

abstract class AuthRepository {
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    UserType userType = UserType.customer,
    Uint8List? idCardBytes,
    String? idCardFileName,
    Uint8List? profilePhotoBytes,
    String? profilePhotoFileName,
  });
  Future<void> signInWithPhone({required String phone});
  Future<AuthResult> verifyOTP({required String phone, required String otp});
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> signInWithApple();
  Future<AuthResult> signInWithFacebook();
  Future<AuthResult> signInAnonymously();
  Future<void> signOut();
  Future<void> resetPassword({required String email});
  Future<void> deleteAccount();
  Future<AuthResult?> getCurrentSession();
  Future<void> refreshSession();
  Stream<AuthEvent> get onAuthStateChange;
}

class AuthResult {
  const AuthResult({
    required this.userId,
    this.email,
    this.phone,
    this.fullName,
    this.avatarUrl,
    this.provider = AuthProviderType.email,
    this.accessToken,
    this.refreshToken,
    this.isNewUser = false,
  });

  final String userId;
  final String? email;
  final String? phone;
  final String? fullName;
  final String? avatarUrl;
  final AuthProviderType provider;
  final String? accessToken;
  final String? refreshToken;
  final bool isNewUser;
}

class AuthEvent {
  const AuthEvent({required this.type, this.userId, this.email, this.provider});

  final AuthEventType type;
  final String? userId;
  final String? email;
  final AuthProviderType? provider;
}

enum AuthEventType {
  signedIn,
  signedOut,
  tokenRefreshed,
  passwordRecovery,
  mfaChallenge,
}
