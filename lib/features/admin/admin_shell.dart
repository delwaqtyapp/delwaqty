import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/localization/admin_locale_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _AdminNavItem {
  const _AdminNavItem({
    required this.path,
    required this.icon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final String Function(AppLocalizations) label;
}

class _AdminNavGroup {
  const _AdminNavGroup({
    required this.label,
    required this.items,
  });

  final String Function(AppLocalizations) label;
  final List<_AdminNavItem> items;
}

final List<_AdminNavGroup> _adminGroups = [
  _AdminNavGroup(
    label: (l) => l.adminLeadershipSection,
    items: [
      _AdminNavItem(
        path: '/admin',
        icon: Icons.speed_rounded,
        label: (l) => l.adminCommandCenter,
      ),
      _AdminNavItem(
        path: '/admin/analytics',
        icon: Icons.insights_rounded,
        label: (l) => l.adminAnalytics,
      ),
      _AdminNavItem(
        path: '/admin/delivery-intelligence',
        icon: Icons.route_rounded,
        label: (l) => l.adminDeliveryIntelligence,
      ),
      _AdminNavItem(
        path: '/admin/merchant-intelligence',
        icon: Icons.shopping_bag_rounded,
        label: (l) => l.adminMerchantIntelligence,
      ),
      _AdminNavItem(
        path: '/admin/provider-intelligence',
        icon: Icons.handyman_rounded,
        label: (l) => l.adminProviderIntelligence,
      ),
      _AdminNavItem(
        path: '/admin/wallet-intelligence',
        icon: Icons.account_balance_wallet_rounded,
        label: (l) => l.adminWalletIntelligence,
      ),
      _AdminNavItem(
        path: '/admin/service-performance',
        icon: Icons.leaderboard_rounded,
        label: (l) => l.adminServicePerformance,
      ),
    ],
  ),
  _AdminNavGroup(
    label: (l) => l.adminMembersSection,
    items: [
      _AdminNavItem(
        path: '/admin/members',
        icon: Icons.people_rounded,
        label: (l) => l.adminMembers,
      ),
      _AdminNavItem(
        path: '/admin/verifications',
        icon: Icons.verified_user_rounded,
        label: (l) => l.adminVerifications,
      ),
      _AdminNavItem(
        path: '/admin/sanctions',
        icon: Icons.gavel_rounded,
        label: (l) => l.sanctions,
      ),
      _AdminNavItem(
        path: '/admin/complaints',
        icon: Icons.warning_amber_rounded,
        label: (l) => l.complaints,
      ),
      _AdminNavItem(
        path: '/admin/live-tracking',
        icon: Icons.map_rounded,
        label: (l) => l.liveTracking,
      ),
    ],
  ),
  _AdminNavGroup(
    label: (l) => l.adminOperationsSection,
    items: [
      _AdminNavItem(
        path: '/admin/orders',
        icon: Icons.receipt_long_rounded,
        label: (l) => l.adminOrdersPage,
      ),
      _AdminNavItem(
        path: '/admin/deliveries',
        icon: Icons.delivery_dining_rounded,
        label: (l) => l.adminDeliveries,
      ),
      _AdminNavItem(
        path: '/admin/drivers',
        icon: Icons.local_shipping_rounded,
        label: (l) => l.adminDrivers,
      ),
      _AdminNavItem(
        path: '/admin/emergency',
        icon: Icons.sos_rounded,
        label: (l) => l.adminEmergency,
      ),
      _AdminNavItem(
        path: '/admin/support-chat',
        icon: Icons.chat_bubble_rounded,
        label: (l) => l.supportChat,
      ),
    ],
  ),
  _AdminNavGroup(
    label: (l) => l.adminFinancialSection,
    items: [
      _AdminNavItem(
        path: '/admin/financial-center',
        icon: Icons.account_balance_rounded,
        label: (l) => l.adminFinancialCenter,
      ),
      _AdminNavItem(
        path: '/admin/transaction-ledger',
        icon: Icons.menu_book_rounded,
        label: (l) => l.adminTransactionLedger,
      ),
      _AdminNavItem(
        path: '/admin/commissions',
        icon: Icons.percent_rounded,
        label: (l) => l.adminCommissions,
      ),
    ],
  ),
  _AdminNavGroup(
    label: (l) => l.adminMarketingSection,
    items: [
      _AdminNavItem(
        path: '/admin/push-notifications',
        icon: Icons.campaign_rounded,
        label: (l) => l.adminPushNotifications,
      ),
    ],
  ),
  _AdminNavGroup(
    label: (l) => l.adminPlatformSection,
    items: [
      _AdminNavItem(
        path: '/admin/users',
        icon: Icons.group_rounded,
        label: (l) => l.adminUsersPage,
      ),
      _AdminNavItem(
        path: '/admin/merchants',
        icon: Icons.storefront_rounded,
        label: (l) => l.adminMerchants,
      ),
      _AdminNavItem(
        path: '/admin/legacy',
        icon: Icons.dashboard_rounded,
        label: (l) => l.adminLegacyDashboard,
      ),
    ],
  ),
  _AdminNavGroup(
    label: (l) => l.adminAdministrationSection,
    items: [
      _AdminNavItem(
        path: '/admin/approvals',
        icon: Icons.fact_check_rounded,
        label: (l) => l.adminApprovals,
      ),
    ],
  ),
  _AdminNavGroup(
    label: (l) => l.adminSettingsGroupSection,
    items: [
      _AdminNavItem(
        path: '/admin/settings',
        icon: Icons.settings_rounded,
        label: (l) => l.adminSettingsPage,
      ),
    ],
  ),
];

/// Wraps every `/admin` route:
///  * applies the independent Admin locale (Arabic by default, persisted
///    separately from the app language) via Localizations.override,
///  * hosts the full grouped Admin navigation INSIDE the admin experience
///    (NavigationRail on wide screens, drawer + floating control on phones),
///  * keeps each admin page's own Scaffold/AppBar untouched.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child, this.showFab = true});

  final Widget child;

  /// Detail pages (chat room, member profile) hide the floating nav control
  /// so it never overlaps their own input/app bars.
  final bool showFab;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateTo(BuildContext context, String path) {
    context.go(path);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final adminLocale = ref.watch(adminLocaleProvider);
    final l10n = AppLocalizations.of(context);
    final isRtl = adminLocale.languageCode == 'ar';

    return Localizations.override(
      context: context,
      locale: adminLocale,
      delegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: _AdminDrawer(
            isRtl: isRtl,
            onNavigate: (path) => _navigateTo(context, path),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final content = Stack(
                children: [
                  widget.child,
                  if (!wide && widget.showFab)
                    Positioned(
                      right: isRtl ? null : 16,
                      left: isRtl ? 16 : null,
                      bottom: 16,
                      child: FloatingActionButton.extended(
                        heroTag: 'admin-nav-fab',
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: Text(l10n.adminPanel),
                      ),
                    ),
                ],
              );
              if (!wide) {
                return content;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminRail(
                    isRtl: isRtl,
                    onNavigate: (path) => _navigateTo(context, path),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminRail extends ConsumerWidget {
  const _AdminRail({required this.isRtl, required this.onNavigate});

  final bool isRtl;
  final void Function(String path) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final path = GoRouterState.of(context).matchedLocation;
    return Container(
      width: 232,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.adminPanel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final group in _adminGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                group.label(l10n),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final item in group.items)
              _RailTile(
                item: item,
                isActive: path == item.path,
                onTap: () => onNavigate(item.path),
              ),
          ],
        ],
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _AdminNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        item.icon,
        size: 20,
        color: isActive ? scheme.primary : null,
      ),
      title: Text(
        item.label(l10n),
        style: TextStyle(
          fontSize: 13,
          color: isActive ? scheme.primary : null,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      selected: isActive,
      selectedTileColor: scheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }
}

class _AdminDrawer extends ConsumerWidget {
  const _AdminDrawer({required this.isRtl, required this.onNavigate});

  final bool isRtl;
  final void Function(String path) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Drawer(
        width: 292,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                l10n.adminPanel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final group in _adminGroups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Text(
                        group.label(l10n),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final item in group.items)
                      _RailTile(
                        item: item,
                        isActive:
                            GoRouterState.of(context).matchedLocation ==
                                item.path,
                        onTap: () => onNavigate(item.path),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}