import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/welcome/presentation/pages/welcome_page.dart';

class WelcomeModule extends FeatureModule {
  @override
  String get id => 'welcome';

  @override
  String name(BuildContext context) => 'Welcome';

  @override
  IconData? get icon => null;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 2;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      builder: (context, state) => const WelcomePage(),
    ),
  ];
}
