/// Represents an authenticated user.
class User {
  /// Creates a [User].
  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.isEmailVerified = false,
    this.createdAt,
  });

  /// Unique user identifier.
  final String id;

  /// User's email address.
  final String email;

  /// User's display name.
  final String? displayName;

  /// User's phone number in E.164 format.
  final String? phoneNumber;

  /// URL of the user's profile photo.
  final String? photoUrl;

  /// Whether the user's email has been verified.
  final bool isEmailVerified;

  /// Timestamp when the account was created.
  final DateTime? createdAt;

  /// Returns a new [User] with the given fields replaced.
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    bool? isEmailVerified,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Result returned by authentication operations.
class AuthResult {
  /// Creates an [AuthResult].
  const AuthResult({
    required this.success,
    this.user,
    this.errorMessage,
    this.requiresOTP = false,
    this.verificationId,
  });

  /// Whether the authentication operation succeeded.
  final bool success;

  /// The authenticated [User], if successful.
  final User? user;

  /// Human-readable error message if the operation failed.
  final String? errorMessage;

  /// Whether the next step requires OTP verification (phone sign-in flow).
  final bool requiresOTP;

  /// Verification ID used in the phone OTP flow.
  final String? verificationId;
}

/// Supported social authentication providers.
enum SocialProvider {
  /// Google sign-in.
  google,

  /// Apple sign-in.
  apple,

  /// Facebook sign-in.
  facebook,
}

/// Abstract interface for authentication services.
///
/// Supports email/password, phone OTP, and social sign-in flows, as well as
/// session management and profile operations.
abstract interface class AuthService {
  /// Signs in an existing user with [email] and [password].
  Future<AuthResult> signIn(String email, String password);

  /// Creates a new account with [email], [password], and [name].
  Future<AuthResult> signUp(String email, String password, String name);

  /// Initiates a phone-based sign-in flow by sending an OTP to [phone].
  Future<AuthResult> signInWithPhone(String phone);

  /// Verifies the OTP sent to [phone] and completes the sign-in.
  Future<AuthResult> verifyOTP(String phone, String otp);

  /// Signs in the user via the given social [provider].
  Future<AuthResult> signInWithSocial(SocialProvider provider);

  /// Signs out the current user.
  Future<void> signOut();

  /// Returns the currently authenticated [User], or null if not signed in.
  User? getCurrentUser();

  /// Stream that emits the current [User] whenever auth state changes.
  Stream<User?> onAuthStateChanged();

  /// Sends a password reset email to [email].
  Future<void> resetPassword(String email);

  /// Updates the current user's profile with the provided [data].
  Future<void> updateProfile(Map<String, dynamic> data);

  /// Refreshes the current session token and returns it, or null on failure.
  Future<String?> refreshToken();

  /// Permanently deletes the current user's account.
  Future<void> deleteAccount();
}
