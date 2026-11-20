import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/features/_shared/campaigns/data/repositories/supabase_campaign_repository_impl.dart';
import 'package:delwaqty/features/_shared/campaigns/data/services/campaign_admin_service.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/managed_campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/repositories/campaign_repository.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final campaignRepositoryProvider = Provider<CampaignRepository>((ref) {
  return ref.watch(supabaseCampaignRepositoryProvider);
});

final campaignByIdProvider = FutureProvider.family<Campaign?, String>((
  ref,
  campaignId,
) async {
  final repo = ref.read(campaignRepositoryProvider);
  return repo.getById(campaignId);
});

final activeCampaignsProvider = FutureProvider<List<Campaign>>((ref) async {
  final repo = ref.read(campaignRepositoryProvider);
  final locale = ref.watch(localeProvider);
  // Watch the user's region preference so active campaigns re-fetch when the
  // customer switches governorate.
  ref.watch(currentUserRegionProvider);
  return repo.getActiveCampaigns(
    locale: locale.languageCode == 'ar' ? 'ar' : 'en',
  );
});

final campaignMediaUrlProvider = FutureProvider.family<String?, String?>((
  ref,
  path,
) {
  final repo = ref.read(campaignRepositoryProvider);
  return repo.getMediaUrl(path);
});

final campaignManagementProvider = Provider<CampaignAdminService>((ref) {
  return CampaignAdminService(ref.watch(supabaseClientProvider));
});

final adminCampaignsProvider = FutureProvider<List<ManagedCampaign>>((ref) {
  return ref.watch(campaignManagementProvider).listAllCampaigns();
});

final providerCampaignsProvider = FutureProvider<List<ManagedCampaign>>((ref) {
  return ref.watch(campaignManagementProvider).listProviderCampaigns();
});
