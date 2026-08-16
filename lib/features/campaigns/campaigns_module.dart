import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/campaigns/presentation/pages/campaign_detail_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class CampaignsModule extends FeatureModule {
  @override
  String get id => 'campaigns';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).campaignTitle;

  @override
  IconData? get icon => Icons.campaign_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 58;

  @override
  List<RouteBase> get shellSubRoutes => [
    GoRoute(
      path: '/campaign/:id',
      name: 'campaign-detail',
      builder: (context, state) {
        final campaignId = state.pathParameters['id'] ?? '';
        return CampaignDetailPage(campaignId: campaignId);
      },
    ),
  ];
}
