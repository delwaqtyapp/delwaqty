import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/commerce/presentation/pages/search_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SearchModule extends FeatureModule {
  @override
  String get id => 'search';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).search;

  @override
  IconData? get icon => Icons.search;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 20;

  @override
  Set<ModuleCapability> get capabilities => {
        ModuleCapability.searchable,
      };

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchPage(),
        ),
      ],
    );
  }
}
