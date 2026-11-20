import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/managed_campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/widgets/banner_form_sheet.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/widgets/campaign_management_widgets.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

class AdminCampaignsPage extends ConsumerStatefulWidget {
  const AdminCampaignsPage({super.key});

  @override
  ConsumerState<AdminCampaignsPage> createState() => _AdminCampaignsPageState();
}

class _AdminCampaignsPageState extends ConsumerState<AdminCampaignsPage> {
  String? _busyCampaignId;

  Future<void> _openCreateSheet() async {
    final l10n = AppLocalizations.of(context);
    final created = await BannerFormSheet.show(
      context,
      submitLabel: l10n.publishNow,
      confirmTitle: l10n.publishNow,
      confirmMessage: l10n.createBanner,
      successMessage: l10n.bannerPublished,
      onSubmit: ({
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
        await ref.read(campaignManagementProvider).createAndPublishBanner(
              titleAr: titleAr,
              titleEn: titleEn,
              subtitleAr: subtitleAr,
              subtitleEn: subtitleEn,
              regionId: regionId,
              imageBytes: imageBytes,
              imageExtension: imageExtension,
              startsAt: startsAt,
              endsAt: endsAt,
            );
      },
    );
    if (created) {
      ref.invalidate(adminCampaignsProvider);
      ref.invalidate(activeCampaignsProvider);
    }
  }

  Future<void> _openEditSheet(ManagedCampaign campaign) async {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final updated = await BannerFormSheet.show(
      context,
      sheetTitle: l10n.editBanner,
      submitLabel: l10n.editBanner,
      confirmTitle: l10n.editBanner,
      confirmMessage: campaign.localizedTitle(lang),
      successMessage: l10n.bannerUpdated,
      initialTitleAr: campaign.nameAr,
      initialTitleEn: campaign.nameEn,
      initialSubtitleAr: campaign.subtitleAr,
      initialSubtitleEn: campaign.subtitleEn,
      initialRegionId: campaign.regionId,
      initialStartsAt: campaign.startsAt,
      initialEndsAt: campaign.endsAt,
      onSubmit: ({
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
        await ref.read(campaignManagementProvider).updateBanner(
              campaignId: campaign.id,
              titleAr: titleAr,
              titleEn: titleEn,
              subtitleAr: subtitleAr,
              subtitleEn: subtitleEn,
              regionId: regionId,
              imageBytes: imageBytes,
              imageExtension: imageExtension,
              startsAt: startsAt,
              endsAt: endsAt,
            );
      },
    );
    if (updated) {
      ref.invalidate(adminCampaignsProvider);
      ref.invalidate(activeCampaignsProvider);
    }
  }

  String _formatScheduleDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _runCampaignAction({
    required ManagedCampaign campaign,
    required String confirmTitle,
    required String confirmMessage,
    required String confirmLabel,
    bool isDestructive = false,
    required Future<void> Function() action,
  }) async {
    if (_busyCampaignId != null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: confirmTitle,
      message: confirmMessage,
      confirmLabel: confirmLabel,
      isDestructive: isDestructive,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyCampaignId = campaign.id);
    try {
      await action();
      ref.invalidate(adminCampaignsProvider);
      ref.invalidate(activeCampaignsProvider);
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busyCampaignId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final campaignsAsync = ref.watch(adminCampaignsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: MediaQuery.sizeOf(context).width < 1100
            ? const AdminMenuButton()
            : null,
        title: Text(l10n.adminBannersTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(adminCampaignsProvider),
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
              onAction: () => ref.invalidate(adminCampaignsProvider),
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
              ref.invalidate(adminCampaignsProvider);
              await ref.read(adminCampaignsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: campaigns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildCampaignCard(context, campaigns[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCampaignCard(BuildContext context, ManagedCampaign campaign) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final title = campaign.localizedTitle(lang);
    final subtitle = campaign.localizedSubtitle(lang);
    final isBusy = _busyCampaignId == campaign.id;
    final service = ref.read(campaignManagementProvider);

    final canPublish = campaign.status == CampaignStatus.approved ||
        campaign.status == CampaignStatus.scheduled;
    final canPause = campaign.status == CampaignStatus.published;
    final canResume = campaign.status == CampaignStatus.paused;
    final canCancel = campaign.status == CampaignStatus.draft ||
        campaign.status == CampaignStatus.pendingReview ||
        campaign.status == CampaignStatus.approved ||
        campaign.status == CampaignStatus.scheduled;

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                    if (campaign.startsAt != null ||
                        campaign.endsAt != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                if (campaign.startsAt != null)
                                  '${l10n.startDate}: ${_formatScheduleDate(campaign.startsAt!)}',
                                if (campaign.endsAt != null)
                                  '${l10n.endDate}: ${_formatScheduleDate(campaign.endsAt!)}',
                              ].join('  •  '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canPublish)
                FilledButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => _runCampaignAction(
                            campaign: campaign,
                            confirmTitle: l10n.publishNow,
                            confirmMessage: title,
                            confirmLabel: l10n.publishNow,
                            action: () =>
                                service.publishCampaign(campaign.id),
                          ),
                  icon: const Icon(Icons.publish_rounded, size: 18),
                  label: Text(l10n.publishNow),
                ),
              if (canPause)
                OutlinedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => _runCampaignAction(
                            campaign: campaign,
                            confirmTitle: l10n.pauseBanner,
                            confirmMessage: title,
                            confirmLabel: l10n.pauseBanner,
                            action: () => service.pauseCampaign(campaign.id),
                          ),
                  icon: const Icon(Icons.pause_rounded, size: 18),
                  label: Text(l10n.pauseBanner),
                ),
              if (canResume)
                FilledButton.tonalIcon(
                  onPressed: isBusy
                      ? null
                      : () => _runCampaignAction(
                            campaign: campaign,
                            confirmTitle: l10n.resumeBanner,
                            confirmMessage: title,
                            confirmLabel: l10n.resumeBanner,
                            action: () => service.resumeCampaign(campaign.id),
                          ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(l10n.resumeBanner),
                ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : () => _openEditSheet(campaign),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.edit),
              ),
              if (canCancel)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.errorLight,
                  ),
                  onPressed: isBusy
                      ? null
                      : () => _runCampaignAction(
                            campaign: campaign,
                            confirmTitle: l10n.cancel,
                            confirmMessage: title,
                            confirmLabel: l10n.cancel,
                            isDestructive: true,
                            action: () => service.cancelCampaign(campaign.id),
                          ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(l10n.cancel),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.errorLight,
                ),
                onPressed: isBusy
                    ? null
                    : () => _runCampaignAction(
                          campaign: campaign,
                          confirmTitle: l10n.deleteBanner,
                          confirmMessage: title,
                          confirmLabel: l10n.delete,
                          isDestructive: true,
                          action: () async {
                            await service.deleteBanner(
                              campaign.id,
                              imagePath: campaign.imagePath,
                            );
                            if (context.mounted) {
                              context.showAppSnackBar(l10n.bannerDeleted);
                            }
                          },
                        ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(l10n.delete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
