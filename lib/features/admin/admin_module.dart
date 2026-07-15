import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_users_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_merchants_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_orders_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_settings_page.dart';

class AdminModule extends FeatureModule {
  @override
  String get id => 'admin';

  @override
  String name(BuildContext context) => 'Admin Panel';

  @override
  IconData? get icon => Icons.admin_panel_settings_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 100;

  @override
  Set<ModuleCapability> get capabilities => {
        ModuleCapability.searchable,
        ModuleCapability.hasNotifications,
      };

  @override
  List<RouteBase> get standaloneRoutes => [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardPage(),
          routes: [
            GoRoute(
              path: 'users',
              builder: (context, state) => const AdminUsersPage(),
            ),
            GoRoute(
              path: 'merchants',
              builder: (context, state) => const AdminMerchantsPage(),
            ),
            GoRoute(
              path: 'orders',
              builder: (context, state) => const AdminOrdersPage(),
            ),
            GoRoute(
              path: 'settings',
              builder: (context, state) => const AdminSettingsPage(),
            ),
          ],
        ),
      ];
}
