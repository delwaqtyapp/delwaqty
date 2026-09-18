import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/about_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/help_center_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy_policy_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy_security_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/terms_of_service_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/change_password_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/data_privacy_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/fingerprint_login_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/location_sharing_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/login_activity_page.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/notification_preferences_page.dart';
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
    GoRoute(
      path: '/settings/change-password',
      name: 'settings-change-password',
      builder: (context, state) => const ChangePasswordPage(),
    ),
    GoRoute(
      path: '/settings/fingerprint-login',
      name: 'settings-fingerprint-login',
      builder: (context, state) => const FingerprintLoginPage(),
    ),
    GoRoute(
      path: '/settings/login-activity',
      name: 'settings-login-activity',
      builder: (context, state) => const LoginActivityPage(),
    ),
    GoRoute(
      path: '/settings/data-privacy',
      name: 'settings-data-privacy',
      builder: (context, state) => const DataPrivacyPage(),
    ),
    GoRoute(
      path: '/settings/location-sharing',
      name: 'settings-location-sharing',
      builder: (context, state) => const LocationSharingPage(),
    ),
    GoRoute(
      path: '/settings/notification-preferences',
      name: 'settings-notification-preferences',
      builder: (context, state) => const NotificationPreferencesPage(),
    ),
  ];


}
