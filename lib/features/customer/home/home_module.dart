import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/home/presentation/pages/home_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class HomeModule extends FeatureModule {
  @override
  String get id => 'home';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).home;

  @override
  IconData get icon => Icons.home_outlined;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 10;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
      ],
    );
  }

  @override
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'home',
      label: (ctx) => AppLocalizations.of(ctx).home,
      icon: Icons.home_outlined,
      onTap: (ctx, ref) {
        Navigator.of(ctx).pop();
        ctx.go('/home');
      },
    ),
  ];
}
