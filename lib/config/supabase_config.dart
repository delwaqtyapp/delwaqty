import 'package:delwaqty/config/app_config.dart';

/// Supabase configuration — delegates to [AppConfig].
///
/// All values come from `--dart-define-from-file` at compile time.
/// Use `SupabaseConfig.url` and `SupabaseConfig.anonKey` for backward
/// compatibility with existing consumers.
abstract final class SupabaseConfig {
  static String get url => AppConfig.supabaseUrl;
  static String get anonKey => AppConfig.supabaseAnonKey;
  static bool get isConfigured => AppConfig.isConfigured;
}
