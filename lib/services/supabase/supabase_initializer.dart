import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/config/supabase_config.dart';

/// Initializes and configures the Supabase client.
///
/// Call [initialize] before using any Supabase services.
/// Uses environment variables for configuration.
abstract final class SupabaseInitializer {
  static bool _initialized = false;

  /// Initializes the Supabase client with configuration from [SupabaseConfig].
  static Future<void> initialize() async {
    if (_initialized) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: kDebugMode,
    );

    _initialized = true;
  }

  /// Returns the initialized Supabase client.
  static SupabaseClient get client => Supabase.instance.client;

  /// Returns the current authenticated user.
  static User? get currentUser => client.auth.currentUser;

  /// Returns whether a user is currently authenticated.
  static bool get isAuthenticated => currentUser != null;
}
