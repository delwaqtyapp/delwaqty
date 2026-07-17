/// Supabase configuration for all environments.
///
/// Credentials are injected via --dart-define at compile time.
/// NEVER commit real credentials to version control.
abstract final class SupabaseConfig {
  // ─── Environment Selection ────────────────────────────────

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get isDev => environment == 'development';
  static bool get isStaging => environment == 'staging';
  static bool get isProd => environment == 'production';

  // ─── Development ──────────────────────────────────────────

  static const String devUrl = String.fromEnvironment(
    'SUPABASE_DEV_URL',
    defaultValue: '',
  );

  static const String devAnonKey = String.fromEnvironment(
    'SUPABASE_DEV_ANON_KEY',
    defaultValue: '',
  );

  static const String devServiceRoleKey = String.fromEnvironment(
    'SUPABASE_DEV_SERVICE_ROLE_KEY',
    defaultValue: '',
  );

  // ─── Staging ──────────────────────────────────────────────

  static const String stagingUrl = String.fromEnvironment(
    'SUPABASE_STAGING_URL',
    defaultValue: '',
  );

  static const String stagingAnonKey = String.fromEnvironment(
    'SUPABASE_STAGING_ANON_KEY',
    defaultValue: '',
  );

  // ─── Production ───────────────────────────────────────────

  static const String prodUrl = String.fromEnvironment(
    'SUPABASE_PROD_URL',
    defaultValue: '',
  );

  static const String prodAnonKey = String.fromEnvironment(
    'SUPABASE_PROD_ANON_KEY',
    defaultValue: '',
  );

  // ─── Computed Values ──────────────────────────────────────

  static String get url {
    switch (environment) {
      case 'staging':
        return stagingUrl;
      case 'production':
        return prodUrl;
      default:
        return devUrl;
    }
  }

  static String get anonKey {
    switch (environment) {
      case 'staging':
        return stagingAnonKey;
      case 'production':
        return prodAnonKey;
      default:
        return devAnonKey;
    }
  }

  // ─── Validation ───────────────────────────────────────────

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static String get validationError {
    if (url.isEmpty) return 'SUPABASE_URL is not configured';
    if (anonKey.isEmpty) return 'SUPABASE_ANON_KEY is not configured';
    return '';
  }
}
