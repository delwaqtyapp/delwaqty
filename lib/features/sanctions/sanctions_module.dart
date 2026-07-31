import 'package:flutter/material.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SanctionsModule extends FeatureModule {
  @override
  String get id => 'sanctions';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).sanctions;

  @override
  IconData? get icon => Icons.gavel_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 82;
}
