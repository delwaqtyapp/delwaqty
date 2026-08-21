import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';

abstract class CampaignRepository {
  Future<Campaign?> getById(String campaignId);

  Future<List<Campaign>> getActiveCampaigns({String locale = 'ar'});

  Future<String?> getMediaUrl(String? path);
}
