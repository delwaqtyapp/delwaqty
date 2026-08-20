import 'dart:ui';
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
      _AdminNavItem(
        path: '/admin/escalations',
        icon: Icons.gavel_rounded,
        label: (l) => l.adminEscalations,
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

const _bottomNavPaths = [
  '/admin',
  '/admin/members',
  '/admin/orders',
  '/admin/financial-center',
  '/admin/actions',
];

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child, this.showFab = true});

  final Widget child;
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

  int _currentBottomIndex(BuildContext context) {
    final path = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _bottomNavPaths.length; i++) {
      if (path == _bottomNavPaths[i] ||
          (_bottomNavPaths[i] != '/admin' && path.startsWith(_bottomNavPaths[i]))) {
        return i;
      }
    }
    return -1;
  }

  void _onBottomNavTap(int index) {
    if (index < _bottomNavPaths.length) {
      context.go(_bottomNavPaths[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminLocale = ref.watch(adminLocaleProvider);
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
        child: Builder(
          builder: (context) {
            final showBottomBar = widget.showFab;
            return Scaffold(
              key: _scaffoldKey,
              drawer: _AdminDrawer(
                isRtl: isRtl,
                onNavigate: (path) => _navigateTo(context, path),
              ),
              bottomNavigationBar: showBottomBar
                  ? _AdminBottomNavBar(
                      currentIndex: _currentBottomIndex(context),
                      onTap: _onBottomNavTap,
                      isRtl: isRtl,
                    )
                  : null,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  if (!wide) {
                    return widget.child;
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AdminRail(
                        isRtl: isRtl,
                        onNavigate: (path) => _navigateTo(context, path),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: widget.child),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminBottomNavBar extends StatelessWidget {
  const _AdminBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.isRtl,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final items = [
      _BottomNavEntry(Icons.speed_rounded, l10n.adminCommandCenter),
      _BottomNavEntry(Icons.people_rounded, l10n.adminMembers),
      _BottomNavEntry(Icons.receipt_long_rounded, l10n.adminOrdersPage),
      _BottomNavEntry(Icons.account_balance_rounded, l10n.adminFinancialCenter),
      _BottomNavEntry(Icons.bolt_rounded, l10n.adminMore),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.82),
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  return _BottomNavTile(
                    entry: items[i],
                    isActive: currentIndex == i,
                    onTap: () => onTap(i),
                    isDark: isDark,
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavTile extends StatelessWidget {
  const _BottomNavTile({
    required this.entry,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  final _BottomNavEntry entry;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? scheme.primary.withValues(alpha: isDark ? 0.22 : 0.15)
                    : Colors.transparent,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: -1,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                entry.icon,
                size: 22,
                color: isActive
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              entry.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavEntry {
  const _BottomNavEntry(this.icon, this.label);
  final IconData icon;
  final String label;
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
    final currentPath = GoRouterState.of(context).matchedLocation;
    return SafeArea(
      child: Drawer(
        width: 292,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.adminPanel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.adminCommandCenter,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final item in group.items)
                      _RailTile(
                        item: item,
                        isActive: currentPath == item.path,
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
