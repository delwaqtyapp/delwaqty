import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/onboarding/presentation/pages/onboarding_page.dart';

class OnboardingModule extends FeatureModule {
  @override
  String get id => 'onboarding';

  @override
  String name(BuildContext context) => 'Onboarding';

  @override
  IconData? get icon => null;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 1;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
  ];
}
