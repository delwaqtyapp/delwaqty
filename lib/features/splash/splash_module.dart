import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/splash/presentation/pages/splash_page.dart';

class SplashModule extends FeatureModule {
  @override
  String get id => 'splash';

  @override
  String name(BuildContext context) => 'Splash';

  @override
  IconData? get icon => null;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 0;

  @override
  List<RouteBase> get standaloneRoutes => [
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashPage(),
        ),
      ];
}
