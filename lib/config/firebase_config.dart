import 'package:delwaqty/config/app_config.dart';

/// Firebase configuration — delegates to [AppConfig].
///
/// Service toggles and remote config defaults remain local since
/// they are not environment-specific and are safe to hardcode.
abstract final class FirebaseConfig {
  // ─── Project Settings (from AppConfig) ─────────────────────

  static String get projectId => AppConfig.firebaseProjectId;
  static String get apiKey => AppConfig.firebaseApiKey;
  static String get androidAppId => AppConfig.firebaseAppId;
  static String get messagingSenderId => AppConfig.firebaseMessagingSenderId;
  static String get storageBucket => AppConfig.firebaseStorageBucket;

  // ─── Package Names ─────────────────────────────────────────

  static const String androidPackageName = 'com.delwaqty.app';
  static const String iosBundleId = 'com.delwaqty.app';

  // ─── Service Toggles ──────────────────────────────────────

  static const bool enableAuth = true;
  static const bool enableMessaging = true;
  static const bool enableCrashlytics = true;
  static const bool enableAnalytics = true;
  static const bool enablePerformance = true;
  static const bool enableRemoteConfig = true;
  static const bool enableAppCheck = false;

  // ─── Remote Config Defaults ───────────────────────────────

  static const Map<String, dynamic> remoteConfigDefaults = {
    'maintenance_mode': false,
    'min_app_version_android': 1,
    'min_app_version_ios': 1,
    'max_upload_size_mb': 10,
    'search_debounce_ms': 300,
    'enable_new_features': false,
  };

  // ─── Validation ───────────────────────────────────────────

  static bool get isConfigured => projectId.isNotEmpty;
}
