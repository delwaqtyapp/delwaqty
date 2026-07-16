/// Cloudflare infrastructure configuration.
///
/// Cloudflare provides: CDN, Images, R2 Storage, DNS, Cache, Security, Workers.
/// This does NOT replace Supabase as the primary database.
abstract final class CloudflareConfig {
  // ─── Account ──────────────────────────────────────────────
  
  static const String accountId = '9926100b5ebd116ea215d09ad09c2f78';
  
  static const String apiToken = String.fromEnvironment(
    'CLOUDFLARE_API_TOKEN',
    defaultValue: '',
  );

  // ─── R2 Storage ───────────────────────────────────────────
  
  static const String r2Bucket = 'delwaqty-assets';
  
  static const String r2AccountId = '9926100b5ebd116ea215d09ad09c2f78';
  
  static const String r2AccessKeyId = 'c9d7a83e716768d5225ec238b2f9c90f';
  
  static const String r2SecretAccessKey = 'a53c6b483b1c61062492e08481480edf5de6ca9bf5df02bb9af68f70570afd11';

  // ─── CDN ──────────────────────────────────────────────────
  
  static const String cdnDomain = String.fromEnvironment(
    'CLOUDFLARE_CDN_DOMAIN',
    defaultValue: 'cdn.delwaqty.com',
  );
  
  static const String zonesDomain = String.fromEnvironment(
    'CLOUDFLARE_ZONES_DOMAIN',
    defaultValue: 'delwaqty.com',
  );

  // ─── Images ───────────────────────────────────────────────
  
  static const String imagesAccountId = String.fromEnvironment(
    'CLOUDFLARE_IMAGES_ACCOUNT_ID',
    defaultValue: '',
  );
  
  static const String imagesDeliveryUrl = String.fromEnvironment(
    'CLOUDFLARE_IMAGES_DELIVERY_URL',
    defaultValue: '',
  );

  // ─── Computed URLs ────────────────────────────────────────
  
  static String get r2BaseUrl => 'https://$r2Bucket.$r2AccountId.r2.cloudflarestorage.com';
  static String get cdnBaseUrl => 'https://$cdnDomain';
  static String get zonesBaseUrl => 'https://api.cloudflare.com/client/v4/zones';

  // ─── Cache Settings ───────────────────────────────────────
  
  static const int defaultCacheTtlSeconds = 86400; // 24 hours
  static const int assetCacheTtlSeconds = 604800; // 7 days
  static const int apiCacheTtlSeconds = 300; // 5 minutes

  // ─── Security ─────────────────────────────────────────────
  
  static const bool enableWaf = true;
  static const bool enableBotFightMode = true;
  static const bool enableChallengePassage = true;
  static const int rateLimitRequestsPerSecond = 100;
  static const int rateLimitWindowSeconds = 60;

  // ─── Validation ───────────────────────────────────────────
  
  static bool get isR2Configured => accountId.isNotEmpty && r2Bucket.isNotEmpty;
  static bool get isCdnConfigured => cdnDomain.isNotEmpty;
  static bool get isImagesConfigured => imagesAccountId.isNotEmpty;
  static bool get isFullyConfigured => isR2Configured && isCdnConfigured;
}
