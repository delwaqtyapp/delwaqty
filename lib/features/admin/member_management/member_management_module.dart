import 'package:flutter/material.dart';
import 'package:delwaqty/core/module/feature_module.dart';

class MemberManagementModule extends FeatureModule {
  @override
  String get id => 'member_management';

  @override
  String name(BuildContext context) => 'Members';

  @override
  IconData? get icon => Icons.people_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 85;
}
