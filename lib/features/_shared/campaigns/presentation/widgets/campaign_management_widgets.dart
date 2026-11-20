import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/managed_campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Displays a signed thumbnail for a campaign banner image path.
class CampaignBannerThumbnail extends ConsumerWidget {
  const CampaignBannerThumbnail({
    super.key,
    required this.imagePath,
    this.width = 72,
    this.height = 56,
  });

  final String? imagePath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = imagePath;
    if (path == null || path.isEmpty) {
      return _placeholder(context);
    }

    final urlAsync = ref.watch(campaignMediaUrlProvider(path));
    return urlAsync.when(
      data: (url) {
        if (url == null || url.isEmpty) return _placeholder(context);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(context),
          ),
        );
      },
      loading: () => _placeholder(context),
      error: (_, _) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.view_carousel_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Colored status badge for a [CampaignStatus].
class CampaignStatusBadge extends StatelessWidget {
  const CampaignStatusBadge({super.key, required this.status});

  final CampaignStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = _style(l10n, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color) _style(AppLocalizations l10n, CampaignStatus status) {
    switch (status) {
      case CampaignStatus.published:
        return (l10n.active, AppColors.successLight);
      case CampaignStatus.pendingReview:
        return (l10n.pendingReview, AppColors.warningLight);
      case CampaignStatus.paused:
        return (l10n.inactive, Colors.orange);
      case CampaignStatus.approved:
        return (l10n.statusApproved, AppColors.infoLight);
      case CampaignStatus.rejected:
      case CampaignStatus.cancelled:
        return (
          status == CampaignStatus.rejected ? l10n.rejected : l10n.cancelled,
          AppColors.errorLight,
        );
      case CampaignStatus.draft:
        return (l10n.draft, Colors.blueGrey);
      case CampaignStatus.scheduled:
      case CampaignStatus.expired:
      case CampaignStatus.archived:
        return (status.dbName, Colors.grey);
    }
  }
}

/// Target scope badge showing either "All Egypt" or the target governorate name.
class CampaignScopeBadge extends StatelessWidget {
  const CampaignScopeBadge({super.key, required this.campaign});

  final ManagedCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final label = campaign.isNational
        ? l10n.allEgypt
        : (campaign.localizedRegionName(lang) ?? l10n.specificGovernorate);
    final color = campaign.isNational
        ? AppColors.brandPurple
        : AppColors.infoLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            campaign.isNational
                ? Icons.public_rounded
                : Icons.location_on_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
