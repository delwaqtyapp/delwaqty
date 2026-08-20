import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/repositories/campaign_repository.dart';
import 'package:delwaqty/features/_shared/campaigns/data/datasources/remote/supabase_campaign_data_source.dart';

final supabaseCampaignRepositoryProvider = Provider<CampaignRepository>((ref) {
  return SupabaseCampaignRepositoryImpl(
    ref.watch(supabaseCampaignDataSourceProvider),
  );
});

class SupabaseCampaignRepositoryImpl implements CampaignRepository {
  SupabaseCampaignRepositoryImpl(this._dataSource);

  final SupabaseCampaignDataSource _dataSource;

  @override
  Future<Campaign?> getById(String campaignId) async {
    try {
      return await _dataSource.getById(campaignId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Campaign>> getActiveCampaigns({String locale = 'ar'}) async {
    try {
      return await _dataSource.getActiveCampaigns(locale: locale);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String?> getMediaUrl(String? path) async {
    try {
      return await _dataSource.getMediaUrl(path);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
