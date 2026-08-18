import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/platform_intelligence_dashboard.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_users_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_merchants_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_orders_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_settings_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_drivers_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_analytics_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_deliveries_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_push_notifications_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_verifications_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_financial_center.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_delivery_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_merchant_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_provider_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_wallet_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_transaction_ledger_page.dart';
import 'package:delwaqty/features/complaints/presentation/pages/admin_complaints_page.dart';
import 'package:delwaqty/features/escalation/presentation/pages/admin_escalations_page.dart';
import 'package:delwaqty/features/sanctions/presentation/pages/admin_sanctions_page.dart';
import 'package:delwaqty/features/location_tracking/presentation/pages/admin_live_tracking_page.dart';
import 'package:delwaqty/features/support_chat/presentation/pages/admin_support_chat_page.dart';
import 'package:delwaqty/features/support_chat/presentation/pages/support_chat_room_page.dart';
import 'package:delwaqty/features/member_management/presentation/pages/member_operations_center.dart';

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
      builder: (context, state) => const PlatformIntelligenceDashboard(),
      routes: [
        GoRoute(
          path: 'legacy',
          builder: (context, state) => const AdminDashboardPage(),
        ),
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
          path: 'escalations',
          builder: (context, state) => const AdminEscalationsPage(),
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
          builder: (context, state) => const MemberOperationsCenter(),
        ),
        GoRoute(
          path: 'financial-center',
          builder: (context, state) => const AdminFinancialCenter(),
        ),
        GoRoute(
          path: 'delivery-intelligence',
          builder: (context, state) => const AdminDeliveryIntelligencePage(),
        ),
        GoRoute(
          path: 'merchant-intelligence',
          builder: (context, state) => const AdminMerchantIntelligencePage(),
        ),
        GoRoute(
          path: 'provider-intelligence',
          builder: (context, state) => const AdminProviderIntelligencePage(),
        ),
        GoRoute(
          path: 'wallet-intelligence',
          builder: (context, state) => const AdminWalletIntelligencePage(),
        ),
        GoRoute(
          path: 'transaction-ledger',
          builder: (context, state) => const AdminTransactionLedgerPage(),
        ),
        GoRoute(
          path: 'service-performance',
          builder: (context, state) => const AdminAnalyticsPage(),
        ),
      ],
    ),
  ];
}
