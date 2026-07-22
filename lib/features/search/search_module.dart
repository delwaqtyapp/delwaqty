import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';

class SearchModule extends FeatureModule {
  @override
  String get id => 'search';

  @override
  String name(BuildContext context) => 'Search';

  @override
  IconData? get icon => Icons.search;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 100;

  @override
  bool get isSearchable => true;

  @override
  Set<ModuleCapability> get capabilities => {
        ModuleCapability.searchable,
      };
}
