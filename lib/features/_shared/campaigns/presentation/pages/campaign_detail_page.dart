import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class CampaignDetailPage extends ConsumerWidget {
  const CampaignDetailPage({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final campaignAsync = ref.watch(campaignByIdProvider(campaignId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.campaignTitle)),
      body: campaignAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageView(
          icon: Icons.error_outline_rounded,
          text: l10n.campaignNotFound,
        ),
        data: (campaign) {
          if (campaign == null) {
            return _MessageView(
              icon: Icons.campaign_outlined,
              text: l10n.campaignNotFound,
            );
          }
          return _CampaignBody(campaign: campaign);
        },
      ),
    );
  }
}

class _CampaignBody extends ConsumerWidget {
  const _CampaignBody({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = isAr
        ? (campaign.nameAr.isNotEmpty
            ? campaign.nameAr
            : (campaign.nameEn ?? ''))
        : (campaign.nameEn?.isNotEmpty == true
            ? campaign.nameEn!
            : campaign.nameAr);
    final subtitle = isAr
        ? (campaign.subtitleAr?.isNotEmpty == true
            ? campaign.subtitleAr
            : campaign.subtitleEn)
        : (campaign.subtitleEn?.isNotEmpty == true
            ? campaign.subtitleEn
            : campaign.subtitleAr);
    final description = isAr
        ? (campaign.descriptionAr?.isNotEmpty == true
            ? campaign.descriptionAr
            : campaign.descriptionEn)
        : (campaign.descriptionEn?.isNotEmpty == true
            ? campaign.descriptionEn
            : campaign.descriptionAr);
    final imageUrl = ref
        .watch(campaignMediaUrlProvider(campaign.imagePath))
        .value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _typeLabel(l10n, campaign.campaignType),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(context, campaign.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabel(l10n, campaign.status),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _statusColor(context, campaign.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (campaign.startsAt != null || campaign.endsAt != null) ...[
          const SizedBox(height: 16),
          Text(
            l10n.campaignDates,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatRange(campaign.startsAt, campaign.endsAt),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.campaignDescription,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }

  String _typeLabel(AppLocalizations l10n, CampaignType type) {
    switch (type) {
      case CampaignType.offer:
        return l10n.offers;
      case CampaignType.promotion:
        return l10n.promotion;
      case CampaignType.coupon:
        return l10n.benefitCoupon;
      case CampaignType.productPromotion:
      case CampaignType.servicePromotion:
        return l10n.promotions;
      case CampaignType.announcement:
      case CampaignType.serviceAnnouncement:
      case CampaignType.importantNotice:
        return l10n.notifications;
      case CampaignType.informational:
        return l10n.about;
      case CampaignType.outage:
      case CampaignType.emergencyNotice:
        return l10n.emergencyStat;
      case CampaignType.safetyNotice:
        return l10n.security;
    }
  }

  String _statusLabel(AppLocalizations l10n, CampaignStatus status) {
    switch (status) {
      case CampaignStatus.draft:
        return l10n.draft;
      case CampaignStatus.pendingReview:
        return l10n.pendingReview;
      case CampaignStatus.approved:
        return l10n.statusApproved;
      case CampaignStatus.rejected:
        return l10n.rejected;
      case CampaignStatus.scheduled:
        return l10n.pending;
      case CampaignStatus.published:
        return l10n.active;
      case CampaignStatus.paused:
        return l10n.suspended;
      case CampaignStatus.expired:
        return l10n.rewardStatusExpired;
      case CampaignStatus.archived:
        return l10n.closed;
      case CampaignStatus.cancelled:
        return l10n.cancelled;
    }
  }

  Color _statusColor(BuildContext context, CampaignStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case CampaignStatus.published:
      case CampaignStatus.approved:
        return Colors.green;
      case CampaignStatus.draft:
      case CampaignStatus.scheduled:
        return scheme.primary;
      case CampaignStatus.rejected:
      case CampaignStatus.cancelled:
      case CampaignStatus.expired:
        return Colors.red;
      case CampaignStatus.pendingReview:
      case CampaignStatus.paused:
        return Colors.orange;
      case CampaignStatus.archived:
        return scheme.onSurfaceVariant;
    }
  }

  String _formatRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '-';
    String fmt(DateTime? d) =>
        d == null ? '...' : '${d.day}/${d.month}/${d.year}';
    return '${fmt(start)} - ${fmt(end)}';
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
