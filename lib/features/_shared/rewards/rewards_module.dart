import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/_shared/rewards/presentation/pages/rewards_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RewardsModule extends FeatureModule {
  @override
  String get id => 'rewards';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).rewards;

  @override
  IconData? get icon => Icons.card_giftcard_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 84;

  @override
  List<RouteBase> get shellSubRoutes => [
    GoRoute(
      path: '/rewards',
      name: 'rewards',
      builder: (context, state) => const RewardsPage(),
    ),
  ];
}
