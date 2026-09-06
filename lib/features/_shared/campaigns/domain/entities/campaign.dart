import 'package:freezed_annotation/freezed_annotation.dart';

part 'campaign.freezed.dart';

enum CampaignType {
  offer,
  promotion,
  coupon,
  productPromotion,
  servicePromotion,
  announcement,
  informational,
  serviceAnnouncement,
  outage,
  importantNotice,
  emergencyNotice,
  safetyNotice;

  static CampaignType fromDb(String value) {
    switch (value) {
      case 'product_promotion':
        return CampaignType.productPromotion;
      case 'service_promotion':
        return CampaignType.servicePromotion;
      case 'service_announcement':
        return CampaignType.serviceAnnouncement;
      case 'important_notice':
        return CampaignType.importantNotice;
      case 'emergency_notice':
        return CampaignType.emergencyNotice;
      case 'safety_notice':
        return CampaignType.safetyNotice;
      default:
        return CampaignType.values.firstWhere(
          (t) => t.name == value,
          orElse: () => CampaignType.announcement,
        );
    }
  }

  String get dbName {
    switch (this) {
      case CampaignType.productPromotion:
        return 'product_promotion';
      case CampaignType.servicePromotion:
        return 'service_promotion';
      case CampaignType.serviceAnnouncement:
        return 'service_announcement';
      case CampaignType.importantNotice:
        return 'important_notice';
      case CampaignType.emergencyNotice:
        return 'emergency_notice';
      case CampaignType.safetyNotice:
        return 'safety_notice';
      default:
        return name;
    }
  }
}

enum CampaignStatus {
  draft,
  pendingReview,
  approved,
  rejected,
  scheduled,
  published,
  paused,
  expired,
  archived,
  cancelled;

  static CampaignStatus fromDb(String value) {
    switch (value) {
      case 'pending_review':
        return CampaignStatus.pendingReview;
      default:
        return CampaignStatus.values.firstWhere(
          (s) => s.name == value,
          orElse: () => CampaignStatus.draft,
        );
    }
  }

  String get dbName => name == CampaignStatus.pendingReview.name
      ? 'pending_review'
      : name;
}

enum CampaignPriority {
  normal,
  important,
  critical;

  static CampaignPriority fromDb(String? value) {
    if (value == null) return CampaignPriority.normal;
    return CampaignPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => CampaignPriority.normal,
    );
  }

  String get dbName => name;
}

enum CampaignCtaType {
  none,
  internalRoute,
  entity,
  externalUrl,
  copyCode;

  static CampaignCtaType fromDb(String? value) {
    switch (value) {
      case 'internal_route':
        return CampaignCtaType.internalRoute;
      case 'entity':
        return CampaignCtaType.entity;
      case 'external_url':
        return CampaignCtaType.externalUrl;
      case 'copy_code':
        return CampaignCtaType.copyCode;
      default:
        return CampaignCtaType.none;
    }
  }
}

class CampaignCta {
  const CampaignCta({
    this.type = CampaignCtaType.none,
    this.route,
    this.url,
    this.code,
    this.entityType,
    this.entityId,
  });

  factory CampaignCta.fromJson(Map<String, dynamic> json) => CampaignCta(
        type: CampaignCtaType.fromDb(json['type'] as String?),
        route: json['route'] as String?,
        url: json['url'] as String?,
        code: json['code'] as String?,
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id'] as String?,
      );

  final CampaignCtaType type;
  final String? route;
  final String? url;
  final String? code;
  final String? entityType;
  final String? entityId;
}

@freezed
abstract class Campaign with _$Campaign {
  const factory Campaign({
    required String id,
    required String code,
    required CampaignType campaignType,
    required String nameAr,
    String? nameEn,
    String? subtitleAr,
    String? subtitleEn,
    String? descriptionAr,
    String? descriptionEn,
    required CampaignStatus status,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? publishedAt,
    DateTime? createdAt,
    @Default(CampaignPriority.normal) CampaignPriority priority,
    String? imagePath,
    CampaignCta? cta,
  }) = _Campaign;

  static Campaign fromJson(Map<String, dynamic> json) => Campaign(
        id: json['id'] as String,
        code: json['code'] as String,
        campaignType: CampaignType.fromDb(json['campaign_type'] as String),
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String?,
        subtitleAr: json['subtitle_ar'] as String?,
        subtitleEn: json['subtitle_en'] as String?,
        descriptionAr: json['description_ar'] as String?,
        descriptionEn: json['description_en'] as String?,
        status: CampaignStatus.fromDb(json['status'] as String),
        startsAt: json['starts_at'] != null
            ? DateTime.tryParse(json['starts_at'] as String)
            : null,
        endsAt: json['ends_at'] != null
            ? DateTime.tryParse(json['ends_at'] as String)
            : null,
        publishedAt: json['published_at'] != null
            ? DateTime.tryParse(json['published_at'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        priority: CampaignPriority.fromDb(json['priority'] as String?),
        imagePath: json['image_path'] as String?,
        cta: json['cta'] != null
            ? CampaignCta.fromJson(
                Map<String, dynamic>.from(json['cta'] as Map),
              )
            : null,
      );
}
