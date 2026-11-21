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

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    // Publishable client config: shipped in every APK/web bundle by design.
    defaultValue: 'https://bttnlkmwhorjamzemwda.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ0dG5sa213aG9yamFtemVtd2RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxODc4MzgsImV4cCI6MjA5OTc2MzgzOH0.IsksTaJz-k9Gbc-6f7Is6HxWd0wOZRhSGpYI00gYkH4',
  );

  // ─── Firebase ──────────────────────────────────────────────

  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'delwaqty0',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyBsBH-EQilAypJ2LGVyOK40UpqGWfjHt1A',
  );

  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:772052634679:android:17267a5736408b918b43b2',
  );

  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '772052634679',
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
    if (firebaseMessagingSenderId.isEmpty) {
      errors.add('FIREBASE_MESSAGING_SENDER_ID is missing');
    }
    return errors;
  }

  /// Call in debug mode to log configuration status.
  static void logConfig() {
    debugPrint('── AppConfig [$environment] ──');
    debugPrint('  Supabase URL: ${supabaseUrl.isEmpty ? "(empty)" : "OK"}');
    debugPrint(
      '  Supabase Anon Key: ${supabaseAnonKey.isEmpty ? "(empty)" : "OK"}',
    );
    debugPrint(
      '  Firebase Project: ${firebaseProjectId.isEmpty ? "(empty)" : firebaseProjectId}',
    );
    debugPrint(
      '  Firebase API Key: ${firebaseApiKey.isEmpty ? "(empty)" : "OK"}',
    );
    debugPrint('  Maps API Key: ${mapsApiKey.isEmpty ? "(empty)" : "OK"}');
    debugPrint(
      '  Cloudflare CDN: ${cloudflareCdnDomain.isEmpty ? "(empty)" : cloudflareCdnDomain}',
    );
    final errors = validationErrors;
    if (errors.isNotEmpty) {
      debugPrint('  ⚠ Validation errors: $errors');
    }
  }
}
