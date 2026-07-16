/// Firebase configuration for all services.
///
/// Firebase provides: Auth, FCM, Crashlytics, Analytics, Performance, Remote Config, App Check.
/// Configuration is done via google-services.json (Android) and GoogleService-Info.plist (iOS).
abstract final class FirebaseConfig {
  // ─── Project Settings ─────────────────────────────────────
  
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  
  static const String androidPackageName = 'com.delwaqty.app';
  static const String iosBundleId = 'com.delwaqty.app';

  // ─── Service Toggles ──────────────────────────────────────
  
  static const bool enableAuth = true;
  static const bool enableMessaging = true;
  static const bool enableCrashlytics = true;
  static const bool enableAnalytics = true;
  static const bool enablePerformance = true;
  static const bool enableRemoteConfig = true;
  static const bool enableAppCheck = false; // Enable after App Review

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
