import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/config/supabase_config.dart';

/// Initializes and configures the Supabase client.
///
/// Call [initialize] before using any Supabase services.
/// Uses environment variables for configuration.
abstract final class SupabaseInitializer {
  static bool _initialized = false;

  /// Initializes the Supabase client with configuration from [SupabaseConfig].
  ///
  /// Bounded by a timeout so a slow/unreachable network can never hang
  /// app startup. The caller decides how to surface the failure.
  static Future<void> initialize() async {
    if (_initialized) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
      // Keep the customer permanently signed in across app restarts: the
      // Flutter client persists the session (SharedPreferences) and
      // auto-refreshes the access token on launch (package defaults: PKCE
      // flow + persistSession + autoRefreshToken).
    ).timeout(const Duration(seconds: 10));

    _initialized = true;
  }

  /// Returns the initialized Supabase client.
  static SupabaseClient get client => Supabase.instance.client;

  /// Returns the current authenticated user.
  static User? get currentUser => client.auth.currentUser;

  /// Returns whether a user is currently authenticated.
  static bool get isAuthenticated => currentUser != null;
}
