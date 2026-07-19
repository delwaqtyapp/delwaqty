import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:delwaqty/features/ride/presentation/pages/ride_tracking_page.dart';
import 'package:delwaqty/features/ride/presentation/pages/ride_history_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RideModule extends FeatureModule {
  @override
  String get id => 'ride';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).tawsila;

  @override
  IconData? get icon => Icons.local_taxi_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 30;

  @override
  Set<ModuleCapability> get capabilities => {
        ModuleCapability.hasLocation,
        ModuleCapability.requiresMap,
      };

  @override
  List<String> get dependsOn => [];

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/ride',
          name: 'ride',
          builder: (context, state) => const RideBookingPage(),
        ),
      ],
    );
  }

  @override
  List<RouteBase> get standaloneRoutes => [
        GoRoute(
          path: '/ride/tracking/:id',
          builder: (context, state) => RideTrackingPage(
            rideId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/ride/history',
          builder: (context, state) => const RideHistoryPage(),
        ),
      ];

  @override
  List<Override> providerOverrides(Ref ref) => [];
}
