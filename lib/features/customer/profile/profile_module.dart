import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/profile/presentation/pages/profile_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ProfileModule extends FeatureModule {
  @override
  String get id => 'profile';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).profile;

  @override
  IconData? get icon => Icons.person_outline_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 40;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    );
  }

  @override
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'profile',
      label: (ctx) => AppLocalizations.of(ctx).profile,
      icon: Icons.person_outline_rounded,
      onTap: (ctx, ref) {
        Navigator.of(ctx).pop();
        ctx.go('/profile');
      },
    ),
  ];
}
