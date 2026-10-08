import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/localization/admin_locale_provider.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/floating_sidebar/sidebar_theme.dart';
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
      _AdminNavItem(
        path: '/admin/reviews-moderation',
        icon: Icons.rate_review_rounded,
        label: (l) => l.adminReviewsModeration,
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
        path: '/admin/admins',
        icon: Icons.group_rounded,
        label: (l) => l.adminMgmtList,
      ),
      _AdminNavItem(
        path: '/admin/merchants',
        icon: Icons.storefront_rounded,
        label: (l) => l.adminMerchants,
      ),
      _AdminNavItem(
        path: '/admin/categories',
        icon: Icons.category_rounded,
        label: (l) => l.adminCategories,
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
      _AdminNavItem(
        path: '/admin/pending-deletions',
        icon: Icons.person_remove_rounded,
        label: (l) => l.pendingDeletions,
      ),
      _AdminNavItem(
        path: '/admin/hierarchy',
        icon: Icons.account_tree_rounded,
        label: (l) => l.permissionDelegation,
      ),
    ],
  ),
  _AdminNavGroup(
    label: (l) => l.adminSettingsGroupSection,
    items: [
      _AdminNavItem(
        path: '/admin/settings',
        icon: Icons.tune_rounded,
        label: (l) => l.adminSettingsMenu,
      ),
      _AdminNavItem(
        path: '/admin/platform-config',
        icon: Icons.settings_rounded,
        label: (l) => l.adminPlatformConfig,
      ),
      _AdminNavItem(
        path: '/admin/profile',
        icon: Icons.person_rounded,
        label: (l) => l.adminProfile,
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
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
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
            final showBottomBar = widget.showFab &&
                MediaQuery.sizeOf(context).width < 1100;
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
                  final content = _AdminCanvas(child: widget.child);
                  if (!wide) {
                    return content;
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AdminSidebar(
                        isRtl: isRtl,
                        onNavigate: (path) => _navigateTo(context, path),
                      ),
                      Expanded(child: content),
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

/// Soft layered canvas behind every admin page — a gentle brand-tinted glow
/// that adapts to the active brightness via the registered [SidebarTheme],
/// topped with a slim brand gradient rule so the workspace reads as branded.
class _AdminCanvas extends StatelessWidget {
  const _AdminCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF232131),
                  Theme.of(context).colorScheme.surface,
                  const Color(0xFF18171F),
                ]
              : [
                  const Color(0xFFF6F4FF),
                  const Color(0xFFF3F5FB),
                  Theme.of(context).colorScheme.surface,
                ],
          stops: const [0, 0.42, 1],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 4,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandPurple,
                    AppColors.brandViolet,
                    AppColors.brandCyan,
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
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

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topCenter,
            end: AlignmentDirectional.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF2B2940).withValues(alpha: 0.92),
                    const Color(0xFF1E1D2B).withValues(alpha: 0.92),
                  ]
                : [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.92),
                    const Color(0xFFF4F3FB).withValues(alpha: 0.92),
                  ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : scheme.outlineVariant.withValues(alpha: 0.5),
            width: isDark ? 0.7 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.shadowFloat.withValues(alpha: 0.45)
                  : AppColors.shadowBrand.withValues(alpha: 0.4),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: isActive ? 92 : 60,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isActive
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandPurple, AppColors.brandViolet],
                )
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.brandPurple.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: -2,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              entry.icon,
              size: 20,
              color: isActive
                  ? Colors.white
                  : isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional.centerStart,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 7),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 64),
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
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

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({required this.isRtl, required this.onNavigate});

  final bool isRtl;
  final void Function(String path) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sth = Theme.of(context).extension<SidebarTheme>() ?? SidebarTheme.light;
    final path = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 256,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [sth.cardGradientTop, sth.cardGradientBottom],
        ),
        border: BorderDirectional(
          end: BorderSide(color: sth.dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: sth.cardShadowColor,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
            child: _AdminMasthead(sth: sth, l10n: l10n),
          ),
          Expanded(
            child: ListView(
              key: const Key('adminSidebarScroll'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (final group in _adminGroups) ...[
                  _AdminSectionLabel(label: group.label(l10n), sth: sth),
                  for (final item in group.items)
                    _PremiumNavTile(
                      item: item,
                      isActive: path == item.path,
                      sth: sth,
                      onTap: () => onNavigate(item.path),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: _AdminSidebarFooter(sth: sth, l10n: l10n),
          ),
        ],
      ),
    );
  }
}

class _AdminMasthead extends StatelessWidget {
  const _AdminMasthead({required this.sth, required this.l10n});

  final SidebarTheme sth;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPurple, AppColors.brandViolet, Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFloat.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminPanel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.adminCommandCenter,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSectionLabel extends StatelessWidget {
  const _AdminSectionLabel({required this.label, required this.sth});

  final String label;
  final SidebarTheme sth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: sth.sectionTitleColor.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: sth.sectionTitleColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumNavTile extends StatefulWidget {
  const _PremiumNavTile({
    required this.item,
    required this.isActive,
    required this.sth,
    required this.onTap,
  });

  final _AdminNavItem item;
  final bool isActive;
  final SidebarTheme sth;
  final VoidCallback onTap;

  @override
  State<_PremiumNavTile> createState() => _PremiumNavTileState();
}

class _PremiumNavTileState extends State<_PremiumNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final isActive = widget.isActive;
    final sth = widget.sth;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: isActive
                ? LinearGradient(
                    colors: [sth.selectedGradientStart, sth.selectedGradientEnd],
                  )
                : (_hovered
                    ? LinearGradient(
                        colors: [
                          sth.selectedGradientStart.withValues(alpha: 0.08),
                          sth.selectedGradientEnd.withValues(alpha: 0.04),
                        ],
                      )
                    : null),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: sth.selectedIndicatorColor.withValues(alpha: 0.32),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 19,
                color: isActive
                    ? Colors.white
                    : _hovered
                        ? sth.selectedGradientStart
                        : sth.iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isActive || _hovered
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : _hovered
                            ? sth.textPrimary
                            : sth.textPrimary.withValues(alpha: 0.92),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: isActive ? 6 : 0,
                height: isActive ? 6 : 0,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSidebarFooter extends StatelessWidget {
  const _AdminSidebarFooter({required this.sth, required this.l10n});

  final SidebarTheme sth;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sth.quickSettingsBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sth.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandPurple, AppColors.brandViolet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminPanel,
                  style: TextStyle(
                    color: sth.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.adminManagementMode,
                  style: TextStyle(
                    color: sth.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
    final sth = Theme.of(context).extension<SidebarTheme>() ?? SidebarTheme.light;
    final currentPath = GoRouterState.of(context).matchedLocation;

    return SafeArea(
      child: Drawer(
        width: 300,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [sth.cardGradientTop, sth.cardGradientBottom],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: _AdminMasthead(sth: sth, l10n: l10n),
              ),
              const Divider(height: 1, color: Colors.transparent),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: [
                    for (final group in _adminGroups) ...[
                      _AdminSectionLabel(label: group.label(l10n), sth: sth),
                      for (final item in group.items)
                        _PremiumNavTile(
                          item: item,
                          isActive: currentPath == item.path,
                          sth: sth,
                          onTap: () => onNavigate(item.path),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _AdminSidebarFooter(sth: sth, l10n: l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}