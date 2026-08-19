import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/module/feature_module.dart';
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
import 'package:delwaqty/features/admin/presentation/pages/admin_emergency_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_delivery_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_merchant_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_provider_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_wallet_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_transaction_ledger_page.dart';
import 'package:delwaqty/features/complaints/presentation/pages/admin_complaints_page.dart';
import 'package:delwaqty/features/sanctions/presentation/pages/admin_sanctions_page.dart';
import 'package:delwaqty/features/location_tracking/presentation/pages/admin_live_tracking_page.dart';
import 'package:delwaqty/features/support_chat/presentation/pages/admin_support_chat_page.dart';
import 'package:delwaqty/features/support_chat/presentation/pages/support_chat_room_page.dart';
import 'package:delwaqty/features/member_management/presentation/pages/member_operations_center.dart';
import 'package:delwaqty/features/member_management/presentation/pages/member_detail_page.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_commission_management_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_approvals_center_page.dart';

AdminShell _admin(Widget page, {bool showFab = true}) {
  return AdminShell(showFab: showFab, child: page);
}

class AdminModule extends FeatureModule {
  @override
  String get id => 'admin';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).adminPanel;

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
      builder: (context, state) =>
          _admin(const PlatformIntelligenceDashboard()),
      routes: [
        GoRoute(
          path: 'users',
          builder: (context, state) => _admin(const AdminUsersPage()),
        ),
        GoRoute(
          path: 'merchants',
          builder: (context, state) => _admin(const AdminMerchantsPage()),
        ),
        GoRoute(
          path: 'orders',
          builder: (context, state) => _admin(const AdminOrdersPage()),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => _admin(const AdminSettingsPage()),
        ),
        GoRoute(
          path: 'drivers',
          builder: (context, state) => _admin(const AdminDriversPage()),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => _admin(const AdminAnalyticsPage()),
        ),
        GoRoute(
          path: 'deliveries',
          builder: (context, state) => _admin(const AdminDeliveriesPage()),
        ),
        GoRoute(
          path: 'push-notifications',
          builder: (context, state) =>
              _admin(const AdminPushNotificationsPage()),
        ),
        GoRoute(
          path: 'verifications',
          builder: (context, state) => _admin(const AdminVerificationsPage()),
        ),
        GoRoute(
          path: 'commissions',
          builder: (context, state) =>
              _admin(const AdminCommissionManagementPage()),
        ),
        GoRoute(
          path: 'approvals',
          builder: (context, state) =>
              _admin(const AdminApprovalsCenterPage()),
        ),
        GoRoute(
          path: 'complaints',
          builder: (context, state) => _admin(const AdminComplaintsPage()),
        ),
        GoRoute(
          path: 'sanctions',
          builder: (context, state) => _admin(const AdminSanctionsPage()),
        ),
        GoRoute(
          path: 'live-tracking',
          builder: (context, state) => _admin(const AdminLiveTrackingPage()),
        ),
        GoRoute(
          path: 'support-chat',
          builder: (context, state) => _admin(const AdminSupportChatPage()),
          routes: [
            GoRoute(
              path: 'room/:roomId',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                return _admin(
                  SupportChatRoomPage(roomId: roomId),
                  showFab: false,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: 'members',
          builder: (context, state) =>
              _admin(const MemberOperationsCenter()),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return _admin(
                  MemberDetailPage(memberId: id),
                  showFab: false,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: 'financial-center',
          builder: (context, state) => _admin(const AdminFinancialCenter()),
        ),
        GoRoute(
          path: 'emergency',
          builder: (context, state) => _admin(const AdminEmergencyPage()),
        ),
        GoRoute(
          path: 'delivery-intelligence',
          builder: (context, state) =>
              _admin(const AdminDeliveryIntelligencePage()),
        ),
        GoRoute(
          path: 'merchant-intelligence',
          builder: (context, state) =>
              _admin(const AdminMerchantIntelligencePage()),
        ),
        GoRoute(
          path: 'provider-intelligence',
          builder: (context, state) =>
              _admin(const AdminProviderIntelligencePage()),
        ),
        GoRoute(
          path: 'wallet-intelligence',
          builder: (context, state) =>
              _admin(const AdminWalletIntelligencePage()),
        ),
        GoRoute(
          path: 'transaction-ledger',
          builder: (context, state) =>
              _admin(const AdminTransactionLedgerPage()),
        ),
        GoRoute(
          path: 'service-performance',
          builder: (context, state) => _admin(const AdminAnalyticsPage()),
        ),
      ],
    ),
  ];
}
