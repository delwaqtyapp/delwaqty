/// Central platform configuration aggregator.
///
/// Provides a single entry point for all platform service configurations.
/// Use this to check the overall readiness of the platform.
import 'package:delwaqty/config/supabase_config_v2.dart';
import 'package:delwaqty/config/firebase_config.dart';
import 'package:delwaqty/config/maps_config_v2.dart';
import 'package:delwaqty/config/cloudflare_config_v2.dart';

/// Aggregated platform configuration status.
class PlatformConfig {
  const PlatformConfig._();

  // ─── Service Status ───────────────────────────────────────

  /// Whether Supabase is configured.
  static bool get supabaseReady => SupabaseConfig.isConfigured;

  /// Whether Firebase is configured.
  static bool get firebaseReady => FirebaseConfig.isConfigured;

  /// Whether Google Maps is configured.
  static bool get mapsReady => MapsConfig.isConfigured;

  /// Whether Cloudflare is configured.
  static bool get cloudflareReady => CloudflareConfig.isFullyConfigured;

  // ─── Overall Status ───────────────────────────────────────

  /// Whether the platform is ready for development.
  static bool get isDevReady => supabaseReady;

  /// Whether the platform is ready for staging.
  static bool get isStagingReady => supabaseReady && mapsReady;

  /// Whether the platform is ready for production.
  static bool get isProdReady =>
      supabaseReady && firebaseReady && mapsReady && cloudflareReady;

  // ─── Missing Configuration ────────────────────────────────

  /// Returns a list of missing configurations.
  static List<String> get missingConfigurations {
    final missing = <String>[];
    if (!supabaseReady) missing.add('Supabase (SUPABASE_URL, SUPABASE_ANON_KEY)');
    if (!firebaseReady) missing.add('Firebase (google-services.json)');
    if (!mapsReady) missing.add('Google Maps (GOOGLE_MAPS_API_KEY)');
    if (!cloudflareReady) missing.add('Cloudflare (ACCOUNT_ID, R2_BUCKET)');
    return missing;
  }

  /// Returns a human-readable status report.
  static String get statusReport {
    final buffer = StringBuffer();
    buffer.writeln('Platform Configuration Status');
    buffer.writeln('============================');
    buffer.writeln('Supabase:    ${supabaseReady ? "✅" : "❌"}');
    buffer.writeln('Firebase:    ${firebaseReady ? "✅" : "❌"}');
    buffer.writeln('Google Maps: ${mapsReady ? "✅" : "❌"}');
    buffer.writeln('Cloudflare:  ${cloudflareReady ? "✅" : "❌"}');
    buffer.writeln('');
    
    if (missingConfigurations.isNotEmpty) {
      buffer.writeln('Missing:');
      for (final item in missingConfigurations) {
        buffer.writeln('  - $item');
      }
    } else {
      buffer.writeln('All services configured! ✅');
    }
    
    return buffer.toString();
  }
}
