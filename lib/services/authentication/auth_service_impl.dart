import 'dart:async';
import 'package:delwaqty/services/authentication/auth_service.dart';

/// Mock implementation of [AuthService] for development.
///
/// Maintains an in-memory user session and provides predictable responses
/// for all authentication flows. No real network calls are made.
class AuthServiceImpl implements AuthService {
  User? _currentUser;
  final _authStateController = StreamController<User?>.broadcast();

  static const _mockUser = User(
    id: 'mock-user-001',
    email: 'demo@delwaqty.com',
    displayName: 'Demo User',
    phoneNumber: '+966501234567',
    isEmailVerified: true,
  );

  @override
  Future<AuthResult> signIn(String email, String password) async {
    _currentUser = _mockUser.copyWith(email: email);
    _authStateController.add(_currentUser);
    return AuthResult(success: true, user: _currentUser);
  }

  @override
  Future<AuthResult> signUp(String email, String password, String name) async {
    _currentUser = _mockUser.copyWith(
      email: email,
      displayName: name,
      createdAt: DateTime.now(),
    );
    _authStateController.add(_currentUser);
    return AuthResult(success: true, user: _currentUser);
  }

  @override
  Future<AuthResult> signInWithPhone(String phone) async {
    return const AuthResult(
      success: true,
      requiresOTP: true,
      verificationId: 'mock-verification-id',
    );
  }

  @override
  Future<AuthResult> verifyOTP(String phone, String otp) async {
    _currentUser = _mockUser.copyWith(phoneNumber: phone);
    _authStateController.add(_currentUser);
    return AuthResult(success: true, user: _currentUser);
  }

  @override
  Future<AuthResult> signInWithSocial(SocialProvider provider) async {
    _currentUser = _mockUser;
    _authStateController.add(_currentUser);
    return AuthResult(success: true, user: _currentUser);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  User? getCurrentUser() => _currentUser;

  @override
  Stream<User?> onAuthStateChanged() => _authStateController.stream;

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        displayName: data['displayName'] as String? ?? _currentUser!.displayName,
        photoUrl: data['photoUrl'] as String? ?? _currentUser!.photoUrl,
      );
      _authStateController.add(_currentUser);
    }
  }

  @override
  Future<String?> refreshToken() async {
    return 'mock-refresh-token-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> deleteAccount() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  /// Releases resources held by this service.
  void dispose() {
    _authStateController.close();
  }
}
