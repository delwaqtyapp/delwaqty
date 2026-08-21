import 'package:flutter/foundation.dart';

/// Centralized configuration for all environments.
///
/// All values are injected at compile time via `--dart-define-from-file`.
/// The active `.env` file determines which values are compiled into the app.
///
/// **Build commands:**
/// ```bash
/// flutter run --dart-define-from-file=.env.dev
/// flutter run --dart-define-from-file=.env.staging
/// flutter build apk --dart-define-from-file=.env.prod
/// ```
///
/// **Security:** Only public client-safe values are included.
/// Never embed service role keys, API tokens with write access,
/// or any other privileged credentials in `.env` files.
abstract final class AppConfig {
  // ─── Environment ───────────────────────────────────────────

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get isDev => environment == 'development';
  static bool get isStaging => environment == 'staging';
  static bool get isProd => environment == 'production';

  // ─── Supabase ──────────────────────────────────────────────

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  // ─── Firebase ──────────────────────────────────────────────

  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );

  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
  );

  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );

  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'delwaqty0.firebasestorage.app',
  );

  // ─── Google Maps ───────────────────────────────────────────

  static const String mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  // ─── Cloudflare ────────────────────────────────────────────

  static const String cloudflareAccountId = String.fromEnvironment(
    'CLOUDFLARE_ACCOUNT_ID',
  );

  static const String cloudflareR2Bucket = String.fromEnvironment(
    'CLOUDFLARE_R2_BUCKET',
    defaultValue: 'delwaqty-assets',
  );

  static const String cloudflareCdnDomain = String.fromEnvironment(
    'CLOUDFLARE_CDN_DOMAIN',
    defaultValue: 'cdn.delwaqty.com',
  );

  // ─── Paymob (Payment Gateway) ─────────────────────────────

  static const String paymobApiKey = String.fromEnvironment(
    'PAYMOB_API_KEY',
  );

  static const String paymobIntegrationId = String.fromEnvironment(
    'PAYMOB_INTEGRATION_ID',
  );

  static const String paymobIframeId = String.fromEnvironment(
    'PAYMOB_IFRAME_ID',
  );

  // ─── Derived Values ────────────────────────────────────────

  static String get cloudflareR2BaseUrl =>
      'https://$cloudflareR2Bucket.$cloudflareAccountId.r2.cloudflarestorage.com';

  static String get cloudflareCdnBaseUrl => 'https://$cloudflareCdnDomain';

  // ─── Validation ────────────────────────────────────────────

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static List<String> get validationErrors {
    final errors = <String>[];
    if (supabaseUrl.isEmpty) errors.add('SUPABASE_URL is missing');
    if (supabaseAnonKey.isEmpty) errors.add('SUPABASE_ANON_KEY is missing');
    if (firebaseProjectId.isEmpty) {
      errors.add('FIREBASE_PROJECT_ID is missing');
    }
    if (firebaseApiKey.isEmpty) errors.add('FIREBASE_API_KEY is missing');
    if (firebaseAppId.isEmpty) errors.add('FIREBASE_APP_ID is missing');
    return errors;
  }

  /// Call in debug mode to log configuration status.
  static void logConfig() {
    debugPrint('── AppConfig [$environment] ──');
    debugPrint('  Supabase URL: ${supabaseUrl.isEmpty ? "(empty)" : "OK"}');
    debugPrint(
      '  Supabase Anon Key: ${supabaseAnonKey.isEmpty ? "(empty)" : "OK"}',
    );
    debugPrint('  Firebase Project: ${firebaseProjectId.isEmpty ? "(empty)" : firebaseProjectId}');
    debugPrint('  Firebase API Key: ${firebaseApiKey.isEmpty ? "(empty)" : "OK"}');
    debugPrint('  Maps API Key: ${mapsApiKey.isEmpty ? "(empty)" : "OK"}');
    debugPrint('  Cloudflare CDN: ${cloudflareCdnDomain.isEmpty ? "(empty)" : cloudflareCdnDomain}');
    final errors = validationErrors;
    if (errors.isNotEmpty) {
      debugPrint('  ⚠ Validation errors: $errors');
    }
  }
}
