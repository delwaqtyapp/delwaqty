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

@freezed
class Campaign with _$Campaign {
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
      );
}
