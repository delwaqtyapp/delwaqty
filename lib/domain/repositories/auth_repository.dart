abstract class AuthRepository {
  Future<AuthResult> signInWithEmail({required String email, required String password});
  Future<AuthResult> signUpWithEmail({required String email, required String password, String? fullName});
  Future<void> signOut();
  Future<void> resetPassword({required String email});
  Future<AuthResult?> getCurrentSession();
  Future<void> refreshSession();
}

class AuthResult {
  const AuthResult({
    required this.userId,
    required this.email,
    this.accessToken,
    this.refreshToken,
  });

  final String userId;
  final String email;
  final String? accessToken;
  final String? refreshToken;
}
