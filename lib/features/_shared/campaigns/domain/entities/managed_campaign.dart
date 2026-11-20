import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';

/// Administrative/provider summary of a campaign banner, including its
/// primary image path and regional target metadata.
class ManagedCampaign {
  const ManagedCampaign({
    required this.id,
    required this.code,
    required this.campaignType,
    required this.priority,
    required this.nameAr,
    this.nameEn,
    this.subtitleAr,
    this.subtitleEn,
    required this.status,
    this.imagePath,
    this.regionId,
    this.regionNameAr,
    this.regionNameEn,
    this.createdAt,
    this.publishedAt,
    this.startsAt,
    this.endsAt,
    this.proposedBy,
  });

  factory ManagedCampaign.fromRow(Map<String, dynamic> row) {
    String? imagePath = row['image_path'] as String?;
    final banners = row['campaign_banners'];
    if (imagePath == null && banners is List && banners.isNotEmpty) {
      final activeBanner = banners
          .whereType<Map<dynamic, dynamic>>()
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (b) => (b['is_active'] as bool?) ?? true,
            orElse: () => Map<String, dynamic>.from(banners.first as Map),
          );
      imagePath = activeBanner['image_path'] as String?;
    }

    String? regionId = row['region_id'] as String?;
    String? regionNameAr = row['region_name_ar'] as String?;
    String? regionNameEn = row['region_name_en'] as String?;

    final targets = row['campaign_targets'];
    if (targets is List && targets.isNotEmpty) {
      final firstTarget = Map<String, dynamic>.from(targets.first as Map);
      regionId ??= firstTarget['region_id'] as String?;
      final region = firstTarget['regions'];
      if (region is Map) {
        regionNameAr ??= region['name_ar'] as String?;
        regionNameEn ??= region['name_en'] as String?;
      }
    }

    return ManagedCampaign(
      id: row['id'] as String,
      code: (row['code'] as String?) ?? '',
      campaignType: CampaignType.fromDb(
        (row['campaign_type'] as String?) ?? 'promotion',
      ),
      priority: CampaignPriority.fromDb(row['priority'] as String?),
      nameAr: (row['name_ar'] as String?) ?? '',
      nameEn: row['name_en'] as String?,
      subtitleAr: row['subtitle_ar'] as String?,
      subtitleEn: row['subtitle_en'] as String?,
      status: CampaignStatus.fromDb((row['status'] as String?) ?? 'draft'),
      imagePath: imagePath,
      regionId: regionId,
      regionNameAr: regionNameAr,
      regionNameEn: regionNameEn,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString())
          : null,
      publishedAt: row['published_at'] != null
          ? DateTime.tryParse(row['published_at'].toString())
          : null,
      startsAt: row['starts_at'] != null
          ? DateTime.tryParse(row['starts_at'].toString())
          : null,
      endsAt: row['ends_at'] != null
          ? DateTime.tryParse(row['ends_at'].toString())
          : null,
      proposedBy: row['proposed_by'] as String?,
    );
  }

  final String id;
  final String code;
  final CampaignType campaignType;
  final CampaignPriority priority;
  final String nameAr;
  final String? nameEn;
  final String? subtitleAr;
  final String? subtitleEn;
  final CampaignStatus status;
  final String? imagePath;
  final String? regionId;
  final String? regionNameAr;
  final String? regionNameEn;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? proposedBy;

  bool get isNational => regionId == null;

  String localizedTitle(String languageCode) {
    if (languageCode == 'en' && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!;
    }
    return nameAr;
  }

  String? localizedSubtitle(String languageCode) {
    if (languageCode == 'en' &&
        subtitleEn != null &&
        subtitleEn!.trim().isNotEmpty) {
      return subtitleEn;
    }
    return subtitleAr;
  }

  String? localizedRegionName(String languageCode) {
    if (languageCode == 'en' &&
        regionNameEn != null &&
        regionNameEn!.trim().isNotEmpty) {
      return regionNameEn;
    }
    return regionNameAr ?? regionNameEn;
  }
}
