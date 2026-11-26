import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/managed_campaign.dart';

/// Service for admin and provider campaign banner management.
class CampaignAdminService {
  CampaignAdminService(this._client);

  final SupabaseClient _client;

  static const String _bucketName = 'campaign-media';

  Future<List<ManagedCampaign>> listAllCampaigns() async {
    final rows = await _client
        .from('campaigns')
        .select(
          'id, code, campaign_type, priority, name_ar, name_en, '
          'subtitle_ar, subtitle_en, status, starts_at, ends_at, '
          'created_at, published_at, proposed_by, '
          'campaign_banners(image_path, locale, placement, is_active), '
          'campaign_targets(region_id, regions(name_ar, name_en))',
        )
        .order('created_at', ascending: false);

    return (rows as List)
        .map(
          (r) => ManagedCampaign.fromRow(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<String?> createAndPublishBanner({
    required String titleAr,
    String? titleEn,
    String? subtitleAr,
    String? subtitleEn,
    String? regionId,
    Uint8List? imageBytes,
    String imageExtension = 'jpg',
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated');
    }

    final imagePath = await _uploadAdminImage(
      uid: uid,
      imageBytes: imageBytes,
      imageExtension: imageExtension,
    );

    final cleanTitleEn = _cleanOptional(titleEn);
    final cleanSubtitleAr = _cleanOptional(subtitleAr);
    final cleanSubtitleEn = _cleanOptional(subtitleEn);

    try {
      final result = await _client.rpc(
        'admin_create_and_publish_banner',
        params: {
          'p_name_ar': titleAr.trim(),
          'p_name_en': cleanTitleEn,
          'p_subtitle_ar': cleanSubtitleAr,
          'p_subtitle_en': cleanSubtitleEn,
          'p_region_id': regionId,
          'p_image_path': imagePath,
          'p_starts_at': startsAt?.toUtc().toIso8601String(),
          'p_ends_at': endsAt?.toUtc().toIso8601String(),
        },
      );
      return result?.toString();
    } on PostgrestException catch (e) {
      // Fallback to direct insert + publish if the convenience RPC is not deployed.
      if (e.code != 'PGRST202' &&
          !e.message.contains('admin_create_and_publish_banner')) {
        rethrow;
      }
      return _fallbackCreateAndPublishBanner(
        titleAr: titleAr.trim(),
        titleEn: cleanTitleEn,
        subtitleAr: cleanSubtitleAr,
        subtitleEn: cleanSubtitleEn,
        regionId: regionId,
        imagePath: imagePath,
        startsAt: startsAt,
        endsAt: endsAt,
      );
    }
  }

  Future<void> updateBanner({
    required String campaignId,
    required String titleAr,
    String? titleEn,
    String? subtitleAr,
    String? subtitleEn,
    String? regionId,
    Uint8List? imageBytes,
    String imageExtension = 'jpg',
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated');
    }

    final imagePath = await _uploadAdminImage(
      uid: uid,
      imageBytes: imageBytes,
      imageExtension: imageExtension,
    );

    await _client.rpc(
      'admin_update_banner',
      params: {
        'p_campaign_id': campaignId,
        'p_name_ar': titleAr.trim(),
        'p_name_en': _cleanOptional(titleEn),
        'p_subtitle_ar': _cleanOptional(subtitleAr),
        'p_subtitle_en': _cleanOptional(subtitleEn),
        'p_region_id': regionId,
        'p_image_path': imagePath,
        'p_starts_at': startsAt?.toUtc().toIso8601String(),
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteBanner(String campaignId, {String? imagePath}) async {
    await _client.rpc(
      'admin_delete_banner',
      params: {'p_campaign_id': campaignId},
    );

    if (imagePath != null && imagePath.trim().isNotEmpty) {
      try {
        await _client.storage.from(_bucketName).remove([imagePath.trim()]);
      } catch (_) {
        // Best-effort storage cleanup after campaign deletion.
      }
    }
  }

  Future<String?> _uploadAdminImage({
    required String uid,
    required Uint8List? imageBytes,
    required String imageExtension,
  }) async {
    if (imageBytes == null || imageBytes.isEmpty) return null;
    final safeExt = _sanitizeExtension(imageExtension);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final imagePath = 'admin/${ts}_$uid.$safeExt';
    await _client.storage
        .from(_bucketName)
        .uploadBinary(
          imagePath,
          imageBytes,
          fileOptions: FileOptions(
            contentType: _contentTypeForExtension(safeExt),
            upsert: true,
          ),
        );
    return imagePath;
  }

  String? _cleanOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<String?> _fallbackCreateAndPublishBanner({
    required String titleAr,
    String? titleEn,
    String? subtitleAr,
    String? subtitleEn,
    String? regionId,
    String? imagePath,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final code = 'BANNER_${DateTime.now().millisecondsSinceEpoch}';
    final inserted = await _client
        .from('campaigns')
        .insert({
          'code': code,
          'campaign_type': 'promotion',
          'priority': 'normal',
          'name_ar': titleAr,
          'name_en': titleEn,
          'subtitle_ar': subtitleAr,
          'subtitle_en': subtitleEn,
          'status': 'approved',
          if (startsAt != null) 'starts_at': startsAt.toUtc().toIso8601String(),
          if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final campaignId = inserted['id'] as String;

    await _client.from('campaign_targets').insert({
      'campaign_id': campaignId,
      'region_id': regionId,
    });

    if (imagePath != null) {
      await _client.from('campaign_banners').insert([
        {
          'campaign_id': campaignId,
          'placement': 'home_carousel',
          'locale': 'ar',
          'image_path': imagePath,
          'is_active': true,
        },
        {
          'campaign_id': campaignId,
          'placement': 'home_carousel',
          'locale': 'en',
          'image_path': imagePath,
          'is_active': true,
        },
      ]);
    }

    await publishCampaign(campaignId);
    return campaignId;
  }

  Future<void> publishCampaign(String id) async {
    await _client.rpc('campaign_publish', params: {'p_campaign_id': id});
  }

  Future<void> pauseCampaign(
    String id, {
    String reason = 'Paused by admin',
  }) async {
    await _client.rpc(
      'campaign_pause',
      params: {'p_campaign_id': id, 'p_reason': reason},
    );
  }

  Future<void> resumeCampaign(String id) async {
    await _client.rpc('campaign_resume', params: {'p_campaign_id': id});
  }

  Future<void> cancelCampaign(
    String id, {
    String reason = 'Cancelled by admin',
  }) async {
    await _client.rpc(
      'campaign_cancel',
      params: {'p_campaign_id': id, 'p_reason': reason},
    );
  }

  Future<List<ManagedCampaign>> listProviderCampaigns() async {
    final data = await _client.rpc('provider_list_my_campaigns');
    final rows = (data as List?) ?? const [];
    return rows
        .map(
          (r) => ManagedCampaign.fromRow(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<String?> submitProviderBanner({
    required String titleAr,
    String? titleEn,
    String? subtitleAr,
    String? subtitleEn,
    String? regionId,
    Uint8List? imageBytes,
    String imageExtension = 'jpg',
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated');
    }

    String? imagePath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final safeExt = _sanitizeExtension(imageExtension);
      final ts = DateTime.now().millisecondsSinceEpoch;
      imagePath = 'providers/$uid/$ts.$safeExt';
      await _client.storage
          .from(_bucketName)
          .uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(
              contentType: _contentTypeForExtension(safeExt),
              upsert: true,
            ),
          );
    }

    final result = await _client.rpc(
      'provider_create_banner_campaign',
      params: {
        'p_name_ar': titleAr.trim(),
        'p_name_en': titleEn != null && titleEn.trim().isNotEmpty
            ? titleEn.trim()
            : null,
        'p_subtitle_ar': subtitleAr != null && subtitleAr.trim().isNotEmpty
            ? subtitleAr.trim()
            : null,
        'p_subtitle_en': subtitleEn != null && subtitleEn.trim().isNotEmpty
            ? subtitleEn.trim()
            : null,
        'p_region_id': regionId,
        'p_image_path': imagePath,
      },
    );
    return result?.toString();
  }

  String _sanitizeExtension(String ext) {
    final lower = ext.toLowerCase().replaceAll('.', '');
    if (lower == 'png' ||
        lower == 'webp' ||
        lower == 'jpeg' ||
        lower == 'jpg') {
      return lower;
    }
    return 'jpg';
  }

  String _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
