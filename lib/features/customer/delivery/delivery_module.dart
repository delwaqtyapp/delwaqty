import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/delivery/presentation/pages/direct_delivery_page.dart';
import 'package:delwaqty/features/customer/delivery/presentation/pages/delivery_tracking_page.dart';
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
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'direct-delivery',
      label: (ctx) => AppLocalizations.of(ctx).directDelivery,
      icon: Icons.moped_rounded,
      onTap: (ctx, ref) {
        Navigator.of(ctx).pop();
        ctx.go('/direct-delivery');
      },
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/direct-delivery',
      name: 'direct-delivery',
      builder: (context, state) => const DirectDeliveryPage(),
    ),
    GoRoute(
      path: '/delivery-tracking/:deliveryId',
      name: 'delivery_tracking',
      builder: (context, state) => DeliveryTrackingPage(
        deliveryId: state.pathParameters['deliveryId']!,
      ),
    ),
  ];
}
