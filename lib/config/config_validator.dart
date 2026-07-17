import 'package:flutter/foundation.dart';
import 'package:delwaqty/config/app_config.dart';

/// Exception thrown when configuration validation fails at startup.
class ConfigValidationException implements Exception {
  const ConfigValidationException(this.errors);
  final List<String> errors;

  @override
  String toString() {
    final buffer = StringBuffer('═══ CONFIG VALIDATION FAILED ═══\n');
    for (var i = 0; i < errors.length; i++) {
      buffer.writeln('  ${i + 1}. ${errors[i]}');
    }
    buffer.writeln('\nSet these values in your .env file and rebuild.');
    buffer.writeln(
      'Usage: flutter run --dart-define-from-file=.env.dev',
    );
    return buffer.toString();
  }
}

/// Validates all configuration values at application startup.
///
/// Runs before [Supabase.initialize] and [Firebase.initializeApp].
/// If any required value is missing, throws [ConfigValidationException]
/// and prevents the app from starting.
abstract final class ConfigValidator {
  static final _urlPattern = RegExp(r'^https://[a-zA-Z0-9.-]+\.supabase\.co$');
  static final _jwtPattern = RegExp(r'^eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$');

  /// Validates all configuration and returns a [ValidationResult].
  static ValidationResult validate() {
    final errors = <String>[];
    final warnings = <String>[];

    // ── Required: Supabase ────────────────────────────────────
    if (AppConfig.supabaseUrl.isEmpty) {
      errors.add('SUPABASE_URL is missing or empty');
    } else if (!_urlPattern.hasMatch(AppConfig.supabaseUrl)) {
      errors.add(
        'SUPABASE_URL has invalid format: "${AppConfig.supabaseUrl}". '
        'Expected: https://your-project.supabase.co',
      );
    }

    if (AppConfig.supabaseAnonKey.isEmpty) {
      errors.add('SUPABASE_ANON_KEY is missing or empty');
    } else if (!_jwtPattern.hasMatch(AppConfig.supabaseAnonKey)) {
      errors.add(
        'SUPABASE_ANON_KEY has invalid format. Expected a JWT token '
        '(eyJ...)',
      );
    }

    // ── Required: Firebase ────────────────────────────────────
    if (AppConfig.firebaseProjectId.isEmpty) {
      errors.add('FIREBASE_PROJECT_ID is missing or empty');
    }

    if (AppConfig.firebaseApiKey.isEmpty) {
      errors.add('FIREBASE_API_KEY is missing or empty');
    }

    if (AppConfig.firebaseAppId.isEmpty) {
      errors.add('FIREBASE_APP_ID is missing or empty');
    }

    if (AppConfig.firebaseMessagingSenderId.isEmpty) {
      errors.add('FIREBASE_MESSAGING_SENDER_ID is missing or empty');
    }

    // ── Optional: Google Maps ─────────────────────────────────
    if (AppConfig.mapsApiKey.isEmpty) {
      warnings.add(
        'GOOGLE_MAPS_API_KEY is not set. Maps features will be unavailable.',
      );
    }

    // ── Optional: Cloudflare ──────────────────────────────────
    if (AppConfig.cloudflareAccountId.isEmpty) {
      warnings.add(
        'CLOUDFLARE_ACCOUNT_ID is not set. CDN features will be unavailable.',
      );
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }

  /// Validates and throws [ConfigValidationException] if required
  /// values are missing. Always call this before service initialization.
  static void validateOrThrow() {
    final result = validate();

    // Log warnings in debug mode.
    if (result.warnings.isNotEmpty && kDebugMode) {
      for (final warning in result.warnings) {
        debugPrint('⚠ Config warning: $warning');
      }
    }

    if (result.hasErrors) {
      if (kDebugMode) {
        debugPrint(result.toString());
      }
      throw ConfigValidationException(result.errors);
    }
  }
}

/// Result of configuration validation.
class ValidationResult {
  const ValidationResult({required this.errors, required this.warnings});

  final List<String> errors;
  final List<String> warnings;

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() {
    final buffer = StringBuffer('═══ Config Validation [$environment] ═══\n');
    if (errors.isNotEmpty) {
      buffer.writeln('ERRORS (${errors.length}):');
      for (final error in errors) {
        buffer.writeln('  ✗ $error');
      }
    }
    if (warnings.isNotEmpty) {
      buffer.writeln('WARNINGS (${warnings.length}):');
      for (final warning in warnings) {
        buffer.writeln('  ⚠ $warning');
      }
    }
    if (!hasErrors && !hasWarnings) {
      buffer.writeln('  ✓ All configuration valid');
    }
    return buffer.toString();
  }

  String get environment => AppConfig.environment;
}
