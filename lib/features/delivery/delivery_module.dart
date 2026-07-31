import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/delivery/presentation/pages/direct_delivery_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class DirectDeliveryModule extends FeatureModule {
  @override
  String get id => 'direct_delivery';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).directDelivery;

  @override
  IconData? get icon => Icons.delivery_dining_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 60;

  @override
  Set<ModuleCapability> get capabilities => {
        ModuleCapability.hasLocation,
        ModuleCapability.requiresDelivery,
      };

  @override
  List<String> get dependsOn => [];

  @override
  List<RouteBase> get standaloneRoutes => [
        GoRoute(
          path: '/direct-delivery',
          name: 'direct_delivery',
          builder: (context, state) => const DirectDeliveryPage(),
        ),
      ];

  @override
  List<Override> providerOverrides(Ref ref) => [];
}
