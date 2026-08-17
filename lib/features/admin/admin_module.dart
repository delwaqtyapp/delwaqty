import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_users_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_merchants_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_orders_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_settings_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_drivers_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_analytics_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_deliveries_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_push_notifications_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_verifications_page.dart';
import 'package:delwaqty/features/complaints/presentation/pages/admin_complaints_page.dart';
import 'package:delwaqty/features/sanctions/presentation/pages/admin_sanctions_page.dart';
import 'package:delwaqty/features/location_tracking/presentation/pages/admin_live_tracking_page.dart';
import 'package:delwaqty/features/support_chat/presentation/pages/admin_support_chat_page.dart';
import 'package:delwaqty/features/support_chat/presentation/pages/support_chat_room_page.dart';
import 'package:delwaqty/features/member_management/presentation/pages/member_list_page.dart';
import 'package:delwaqty/features/member_management/presentation/pages/member_detail_page.dart';

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
        GoRoute(
          path: 'drivers',
          builder: (context, state) => const AdminDriversPage(),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const AdminAnalyticsPage(),
        ),
        GoRoute(
          path: 'deliveries',
          builder: (context, state) => const AdminDeliveriesPage(),
        ),
        GoRoute(
          path: 'push-notifications',
          builder: (context, state) => const AdminPushNotificationsPage(),
        ),
        GoRoute(
          path: 'verifications',
          builder: (context, state) => const AdminVerificationsPage(),
        ),
        GoRoute(
          path: 'complaints',
          builder: (context, state) => const AdminComplaintsPage(),
        ),
        GoRoute(
          path: 'sanctions',
          builder: (context, state) => const AdminSanctionsPage(),
        ),
        GoRoute(
          path: 'live-tracking',
          builder: (context, state) => const AdminLiveTrackingPage(),
        ),
        GoRoute(
          path: 'support-chat',
          builder: (context, state) => const AdminSupportChatPage(),
          routes: [
            GoRoute(
              path: 'room/:roomId',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                return SupportChatRoomPage(roomId: roomId);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'members',
          builder: (context, state) => const MemberListPage(),
          routes: [
            GoRoute(
              path: ':memberId',
              builder: (context, state) {
                final memberId = state.pathParameters['memberId']!;
                return MemberDetailPage(memberId: memberId);
              },
            ),
          ],
        ),
      ],
    ),
  ];
}
