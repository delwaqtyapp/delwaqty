import 'package:flutter/material.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class LocationTrackingModule extends FeatureModule {
  @override
  String get id => 'location_tracking';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).liveTracking;

  @override
  IconData? get icon => Icons.map_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 83;

  @override
  Set<ModuleCapability> get capabilities => {ModuleCapability.hasLocation};
}
