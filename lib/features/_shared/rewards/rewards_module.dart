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
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'rewards',
      label: (ctx) => AppLocalizations.of(ctx).rewards,
      icon: Icons.card_giftcard_rounded,
      onTap: (ctx, ref) {
        Navigator.of(ctx).pop();
        ctx.go('/rewards');
      },
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/rewards',
      name: 'rewards',
      builder: (context, state) => const RewardsPage(),
    ),
  ];
}
