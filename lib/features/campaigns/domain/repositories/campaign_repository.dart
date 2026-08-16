import 'package:delwaqty/features/campaigns/domain/entities/campaign.dart';

abstract class CampaignRepository {
  Future<Campaign?> getById(String campaignId);
}
