/// Cloudflare infrastructure configuration.
///
/// Cloudflare provides CDN, R2 storage, edge caching, and security.
/// It does NOT replace Supabase as the primary database.
abstract final class CloudflareConfig {
  /// Cloudflare API token.
  static const String apiToken = String.fromEnvironment(
    'CLOUDFLARE_API_TOKEN',
    defaultValue: '',
  );

  /// Cloudflare account ID.
  static const String accountId = String.fromEnvironment(
    'CLOUDFLARE_ACCOUNT_ID',
    defaultValue: '',
  );

  /// R2 bucket name for asset storage.
  static const String r2Bucket = String.fromEnvironment(
    'CLOUDFLARE_R2_BUCKET',
    defaultValue: 'delwaqty-assets',
  );

  /// CDN domain for asset delivery.
  static const String cdnDomain = String.fromEnvironment(
    'CLOUDFLARE_CDN_DOMAIN',
    defaultValue: 'cdn.delwaqty.com',
  );

  /// Base URL for R2 storage.
  static String get r2BaseUrl =>
      'https://$r2Bucket.$accountId.r2.cloudflarestorage.com';

  /// Base URL for CDN.
  static String get cdnBaseUrl => 'https://$cdnDomain';
}
