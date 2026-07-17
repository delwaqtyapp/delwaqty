import 'package:delwaqty/config/app_config.dart';

/// Cloudflare infrastructure configuration — delegates to [AppConfig].
abstract final class CloudflareConfig {
  static String get accountId => AppConfig.cloudflareAccountId;
  static String get r2Bucket => AppConfig.cloudflareR2Bucket;
  static String get cdnDomain => AppConfig.cloudflareCdnDomain;

  /// Base URL for R2 storage.
  static String get r2BaseUrl => AppConfig.cloudflareR2BaseUrl;

  /// Base URL for CDN.
  static String get cdnBaseUrl => AppConfig.cloudflareCdnBaseUrl;
}
