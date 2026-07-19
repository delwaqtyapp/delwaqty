import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/safety/presentation/pages/trusted_contacts_page.dart';
import 'package:delwaqty/features/safety/presentation/pages/safety_settings_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SafetyModule extends FeatureModule {
  @override
  String get id => 'safety';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).safety;

  @override
  IconData? get icon => Icons.shield_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 85;

  @override
  List<RouteBase> get standaloneRoutes => [
        GoRoute(
          path: '/safety/contacts',
          builder: (context, state) => const TrustedContactsPage(),
        ),
        GoRoute(
          path: '/safety/settings',
          builder: (context, state) => const SafetySettingsPage(),
        ),
      ];

  @override
  List<DrawerEntry> get drawerEntries => [
        DrawerEntry(
          id: 'safety-contacts',
          label: (ctx) => AppLocalizations.of(ctx).trustedContacts,
          icon: Icons.contacts_rounded,
          onTap: (ctx, ref) => ctx.push('/safety/contacts'),
        ),
        DrawerEntry(
          id: 'safety-settings',
          label: (ctx) => AppLocalizations.of(ctx).safetySettings,
          icon: Icons.shield_rounded,
          onTap: (ctx, ref) => ctx.push('/safety/settings'),
        ),
      ];
}
