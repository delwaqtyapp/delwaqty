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
import 'package:delwaqty/features/admin/presentation/pages/service_performance_page.dart';
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
import 'package:delwaqty/features/_shared/complaints/presentation/pages/admin_complaints_page.dart';
import 'package:delwaqty/features/admin/sanctions/presentation/pages/admin_sanctions_page.dart';
import 'package:delwaqty/features/admin/location_tracking/presentation/pages/admin_live_tracking_page.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/pages/admin_support_chat_page.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/pages/support_chat_room_page.dart';
import 'package:delwaqty/features/admin/member_management/presentation/pages/member_operations_center.dart';
import 'package:delwaqty/features/admin/member_management/presentation/pages/member_detail_page.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_commission_management_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_approvals_center_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_quick_actions_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_profile_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_hierarchy_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_pending_deletions_page.dart';

/// Smooth page transition for the admin module: quick fade + subtle rise.
Page<void> _adminPage(
  Widget page, {
  bool showFab = true,
  String? keySuffix,
}) {
  return CustomTransitionPage<void>(
    key: ValueKey('${page.runtimeType}-$keySuffix'),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: slide, child: child),
      );
    },
    child: AdminShell(showFab: showFab, child: page),
  );
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
      pageBuilder: (context, state) =>
          _adminPage(const PlatformIntelligenceDashboard()),
      routes: [
        GoRoute(
          path: 'users',
          pageBuilder: (context, state) => _adminPage(const AdminUsersPage()),
        ),
        GoRoute(
          path: 'merchants',
          pageBuilder: (context, state) =>
              _adminPage(const AdminMerchantsPage()),
        ),
        GoRoute(
          path: 'orders',
          pageBuilder: (context, state) => _adminPage(const AdminOrdersPage()),
        ),
        GoRoute(
          path: 'settings',
          pageBuilder: (context, state) =>
              _adminPage(const AdminSettingsPage()),
        ),
        GoRoute(
          path: 'drivers',
          pageBuilder: (context, state) => _adminPage(const AdminDriversPage()),
        ),
        GoRoute(
          path: 'analytics',
          pageBuilder: (context, state) =>
              _adminPage(const AdminAnalyticsPage()),
        ),
        GoRoute(
          path: 'deliveries',
          pageBuilder: (context, state) =>
              _adminPage(const AdminDeliveriesPage()),
        ),
        GoRoute(
          path: 'push-notifications',
          pageBuilder: (context, state) =>
              _adminPage(const AdminPushNotificationsPage()),
        ),
        GoRoute(
          path: 'verifications',
          pageBuilder: (context, state) =>
              _adminPage(const AdminVerificationsPage()),
        ),
        GoRoute(
          path: 'commissions',
          pageBuilder: (context, state) =>
              _adminPage(const AdminCommissionManagementPage()),
        ),
        GoRoute(
          path: 'approvals',
          pageBuilder: (context, state) =>
              _adminPage(const AdminApprovalsCenterPage()),
        ),
        GoRoute(
          path: 'complaints',
          pageBuilder: (context, state) =>
              _adminPage(const AdminComplaintsPage()),
        ),
        GoRoute(
          path: 'sanctions',
          pageBuilder: (context, state) =>
              _adminPage(const AdminSanctionsPage()),
        ),
        GoRoute(
          path: 'live-tracking',
          pageBuilder: (context, state) =>
              _adminPage(const AdminLiveTrackingPage()),
        ),
        GoRoute(
          path: 'support-chat',
          pageBuilder: (context, state) =>
              _adminPage(const AdminSupportChatPage()),
          routes: [
            GoRoute(
              path: 'room/:roomId',
              pageBuilder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                return _adminPage(
                  SupportChatRoomPage(roomId: roomId),
                  showFab: false,
                  keySuffix: roomId,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: 'members',
          pageBuilder: (context, state) =>
              _adminPage(const MemberOperationsCenter()),
          routes: [
            GoRoute(
              path: ':id',
              pageBuilder: (context, state) {
                final id = state.pathParameters['id']!;
                return _adminPage(
                  MemberDetailPage(memberId: id),
                  showFab: false,
                  keySuffix: id,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: 'financial-center',
          pageBuilder: (context, state) =>
              _adminPage(const AdminFinancialCenter()),
        ),
        GoRoute(
          path: 'emergency',
          pageBuilder: (context, state) =>
              _adminPage(const AdminEmergencyPage()),
        ),
        GoRoute(
          path: 'delivery-intelligence',
          pageBuilder: (context, state) =>
              _adminPage(const AdminDeliveryIntelligencePage()),
        ),
        GoRoute(
          path: 'merchant-intelligence',
          pageBuilder: (context, state) =>
              _adminPage(const AdminMerchantIntelligencePage()),
        ),
        GoRoute(
          path: 'provider-intelligence',
          pageBuilder: (context, state) =>
              _adminPage(const AdminProviderIntelligencePage()),
        ),
        GoRoute(
          path: 'wallet-intelligence',
          pageBuilder: (context, state) =>
              _adminPage(const AdminWalletIntelligencePage()),
        ),
        GoRoute(
          path: 'transaction-ledger',
          pageBuilder: (context, state) =>
              _adminPage(const AdminTransactionLedgerPage()),
        ),
        GoRoute(
          path: 'service-performance',
          pageBuilder: (context, state) =>
              _adminPage(const ServicePerformancePage()),
        ),
        GoRoute(
          path: 'actions',
          pageBuilder: (context, state) =>
              _adminPage(const AdminQuickActionsPage()),
        ),
        GoRoute(
          path: 'profile',
          pageBuilder: (context, state) =>
              _adminPage(const AdminProfilePage()),
        ),
        GoRoute(
          path: 'hierarchy',
          pageBuilder: (context, state) =>
              _adminPage(const AdminHierarchyPage()),
        ),
        GoRoute(
          path: 'pending-deletions',
          pageBuilder: (context, state) =>
              _adminPage(const AdminPendingDeletionsPage()),
        ),
      ],
    ),
  ];
}