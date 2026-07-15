/// Supabase configuration for development and production environments.
///
/// This file should NEVER be committed to version control with real keys.
/// Use .env files for actual credentials.
abstract final class SupabaseConfig {
  /// Development Supabase URL.
  static const String devUrl = String.fromEnvironment(
    'SUPABASE_DEV_URL',
    defaultValue: 'https://your-dev-project.supabase.co',
  );

  /// Development Supabase anon key.
  static const String devAnonKey = String.fromEnvironment(
    'SUPABASE_DEV_ANON_KEY',
    defaultValue: 'your-dev-anon-key',
  );

  /// Production Supabase URL.
  static const String prodUrl = String.fromEnvironment(
    'SUPABASE_PROD_URL',
    defaultValue: 'https://your-prod-project.supabase.co',
  );

  /// Production Supabase anon key.
  static const String prodAnonKey = String.fromEnvironment(
    'SUPABASE_PROD_ANON_KEY',
    defaultValue: 'your-prod-anon-key',
  );

  /// Returns the appropriate URL based on the build mode.
  static String get url => const bool.fromEnvironment('dart.tool.product')
      ? prodUrl
      : devUrl;

  /// Returns the appropriate anon key based on the build mode.
  static String get anonKey => const bool.fromEnvironment('dart.tool.product')
      ? prodAnonKey
      : devAnonKey;
}
