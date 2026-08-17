import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/features/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/campaigns/domain/repositories/campaign_repository.dart';
import 'package:delwaqty/features/campaigns/data/repositories/supabase_campaign_repository_impl.dart';

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
  return repo.getActiveCampaigns(
    locale: locale.languageCode == 'ar' ? 'ar' : 'en',
  );
});

final campaignMediaUrlProvider = FutureProvider.family<String?, String?>((ref, path) {
  final repo = ref.read(campaignRepositoryProvider);
  return repo.getMediaUrl(path);
});
