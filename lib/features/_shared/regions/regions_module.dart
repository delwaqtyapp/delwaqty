import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/_shared/regions/presentation/pages/region_selection_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RegionsModule extends FeatureModule {
  @override
  String get id => 'regions';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).regions;

  @override
  IconData? get icon => Icons.public_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 90;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/region-selection',
      builder: (context, state) => const RegionSelectionPage(),
    ),
  ];
}
