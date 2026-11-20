import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/managed_campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/widgets/banner_form_sheet.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/widgets/campaign_management_widgets.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

class ProviderBannersPage extends ConsumerStatefulWidget {
  const ProviderBannersPage({super.key});

  @override
  ConsumerState<ProviderBannersPage> createState() =>
      _ProviderBannersPageState();
}

class _ProviderBannersPageState extends ConsumerState<ProviderBannersPage> {
  Future<void> _openCreateSheet() async {
    final l10n = AppLocalizations.of(context);
    final submitted = await BannerFormSheet.show(
      context,
      submitLabel: l10n.submitForApproval,
      confirmTitle: l10n.submitForApproval,
      confirmMessage: l10n.createBanner,
      successMessage: l10n.bannerSubmitted,
      onSubmit:
          ({
            required titleAr,
            titleEn,
            subtitleAr,
            subtitleEn,
            regionId,
            imageBytes,
            imageExtension = 'jpg',
            startsAt,
            endsAt,
          }) async {
            await ref
                .read(campaignManagementProvider)
                .submitProviderBanner(
                  titleAr: titleAr,
                  titleEn: titleEn,
                  subtitleAr: subtitleAr,
                  subtitleEn: subtitleEn,
                  regionId: regionId,
                  imageBytes: imageBytes,
                  imageExtension: imageExtension,
                );
          },
    );
    if (submitted) {
      ref.invalidate(providerCampaignsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final campaignsAsync = ref.watch(providerCampaignsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminBannersTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(providerCampaignsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.createBanner),
      ),
      body: campaignsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PremiumEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.error,
              message: appErrorText(context, e),
              actionLabel: l10n.retry,
              onAction: () => ref.invalidate(providerCampaignsProvider),
            ),
          ),
        ),
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PremiumEmptyState(
                  icon: Icons.view_carousel_outlined,
                  title: l10n.adminBannersTitle,
                  message: l10n.noResultsFound,
                  actionLabel: l10n.createBanner,
                  onAction: _openCreateSheet,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(providerCampaignsProvider);
              await ref.read(providerCampaignsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: campaigns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildBannerCard(context, campaigns[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerCard(BuildContext context, ManagedCampaign campaign) {
    final lang = Localizations.localeOf(context).languageCode;
    final title = campaign.localizedTitle(lang);
    final subtitle = campaign.localizedSubtitle(lang);

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampaignBannerThumbnail(imagePath: campaign.imagePath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    CampaignStatusBadge(status: campaign.status),
                    CampaignScopeBadge(campaign: campaign),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
