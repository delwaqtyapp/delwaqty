abstract final class CloudflareConfig {
  static const String accountId = String.fromEnvironment(
    'CLOUDFLARE_ACCOUNT_ID',
    defaultValue: '',
  );

  static const String apiToken = String.fromEnvironment(
    'CLOUDFLARE_API_TOKEN',
    defaultValue: '',
  );

  static const String r2Bucket = String.fromEnvironment(
    'CLOUDFLARE_R2_BUCKET',
    defaultValue: 'delwaqty-assets',
  );

  static const String r2AccountId = String.fromEnvironment(
    'CLOUDFLARE_R2_ACCOUNT_ID',
    defaultValue: '',
  );

  static const String r2AccessKeyId = String.fromEnvironment(
    'CLOUDFLARE_R2_ACCESS_KEY',
    defaultValue: '',
  );

  static const String r2SecretAccessKey = String.fromEnvironment(
    'CLOUDFLARE_R2_SECRET_KEY',
    defaultValue: '',
  );

  static const String cdnDomain = String.fromEnvironment(
    'CLOUDFLARE_CDN_DOMAIN',
    defaultValue: 'cdn.delwaqty.com',
  );

  static const String zonesDomain = String.fromEnvironment(
    'CLOUDFLARE_ZONES_DOMAIN',
    defaultValue: 'delwaqty.com',
  );

  static const String imagesAccountId = String.fromEnvironment(
    'CLOUDFLARE_IMAGES_ACCOUNT_ID',
    defaultValue: '',
  );

  static const String imagesDeliveryUrl = String.fromEnvironment(
    'CLOUDFLARE_IMAGES_DELIVERY_URL',
    defaultValue: '',
  );

  static String get r2BaseUrl =>
      'https://$r2Bucket.$r2AccountId.r2.cloudflarestorage.com';
  static String get cdnBaseUrl => 'https://$cdnDomain';
  static String get zonesBaseUrl =>
      'https://api.cloudflare.com/client/v4/zones';

  static const int defaultCacheTtlSeconds = 86400;
  static const int assetCacheTtlSeconds = 604800;
  static const int apiCacheTtlSeconds = 300;

  static const bool enableWaf = true;
  static const bool enableBotFightMode = true;
  static const bool enableChallengePassage = true;
  static const int rateLimitRequestsPerSecond = 100;
  static const int rateLimitWindowSeconds = 60;

  static bool get isR2Configured => accountId.isNotEmpty && r2Bucket.isNotEmpty;
  static bool get isCdnConfigured => cdnDomain.isNotEmpty;
  static bool get isImagesConfigured => imagesAccountId.isNotEmpty;
  static bool get isFullyConfigured => isR2Configured && isCdnConfigured;
}
