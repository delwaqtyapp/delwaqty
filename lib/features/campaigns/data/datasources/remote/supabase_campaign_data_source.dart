import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final supabaseCampaignDataSourceProvider = Provider<SupabaseCampaignDataSource>(
  (ref) {
    return SupabaseCampaignDataSource(ref.watch(supabaseClientProvider));
  },
);

class SupabaseCampaignDataSource {
  SupabaseCampaignDataSource(this._client);

  final SupabaseClient _client;

  static const String _tableName = 'campaigns';

  Future<Campaign?> getById(String campaignId) async {
    final data = await _client
        .from(_tableName)
        .select()
        .eq('id', campaignId)
        .maybeSingle();

    if (data == null) return null;
    return _fromRow(data);
  }

  Campaign _fromRow(Map<String, dynamic> row) {
    return Campaign(
      id: row['id'] as String,
      code: row['code'] as String,
      campaignType: CampaignType.fromDb(row['campaign_type'] as String),
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String?,
      subtitleAr: row['subtitle_ar'] as String?,
      subtitleEn: row['subtitle_en'] as String?,
      descriptionAr: row['description_ar'] as String?,
      descriptionEn: row['description_en'] as String?,
      status: CampaignStatus.fromDb(row['status'] as String),
      startsAt: row['starts_at'] != null
          ? DateTime.tryParse(row['starts_at'] as String)
          : null,
      endsAt: row['ends_at'] != null
          ? DateTime.tryParse(row['ends_at'] as String)
          : null,
      publishedAt: row['published_at'] != null
          ? DateTime.tryParse(row['published_at'] as String)
          : null,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
    );
  }
}
