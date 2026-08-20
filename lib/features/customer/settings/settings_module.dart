import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/about_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/help_center_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy_policy_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy_security_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/settings_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/terms_of_service_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SettingsModule extends FeatureModule {
  @override
  String get id => 'settings';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).settings;

  @override
  IconData get icon => Icons.settings_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 90;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/settings/about',
      name: 'settings-about',
      builder: (context, state) => const AboutPage(),
    ),
    GoRoute(
      path: '/settings/help-center',
      name: 'settings-help-center',
      builder: (context, state) => const HelpCenterPage(),
    ),
    GoRoute(
      path: '/settings/privacy-security',
      name: 'settings-privacy-security',
      builder: (context, state) => const PrivacySecurityPage(),
    ),
    GoRoute(
      path: '/settings/terms-of-service',
      name: 'settings-terms-of-service',
      builder: (context, state) => const TermsOfServicePage(),
    ),
    GoRoute(
      path: '/settings/privacy-policy',
      name: 'settings-privacy-policy',
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
  ];

  @override
  List<RouteBase> get shellSubRoutes => [
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context).settings)),
            body: const SettingsPage(),
          ),
        ),
      ];
}
