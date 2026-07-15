import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/settings/presentation/pages/settings_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SettingsModule extends FeatureModule {
  @override
  String get id => 'settings';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).settings;

  @override
  IconData get icon => Icons.settings_outlined;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 90;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );
  }
}
