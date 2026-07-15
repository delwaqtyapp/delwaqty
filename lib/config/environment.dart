/// Application environment configuration.
///
/// Provides access to environment-specific settings and feature flags.
enum AppEnvironment {
  /// Development environment.
  development,

  /// Staging environment.
  staging,

  /// Production environment.
  production,
}

/// Environment configuration holder.
abstract final class Env {
  /// Current application environment.
  static const AppEnvironment environment = AppEnvironment.development;

  /// Whether we are in development mode.
  static const bool isDev = environment == AppEnvironment.development;

  /// Whether we are in production mode.
  static const bool isProd = environment == AppEnvironment.production;

  /// Application name.
  static const String appName = 'Delwaqty';

  /// Application version.
  static const String appVersion = '1.0.0';

  /// Build number.
  static const String buildNumber = '1';
}
