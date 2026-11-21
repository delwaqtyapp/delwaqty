import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

class AdminQuickActionsPage extends ConsumerStatefulWidget {
  const AdminQuickActionsPage({super.key});

  @override
  ConsumerState<AdminQuickActionsPage> createState() =>
      _AdminQuickActionsPageState();
}

class _AdminQuickActionsPageState extends ConsumerState<AdminQuickActionsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final sections = [
      (
        l10n.adminLeadershipSection,
        const Color(0xFF007AFF),
        Icons.speed_rounded,
        [
          _ActionData(
            l10n.adminCommandCenter,
            Icons.dashboard_rounded,
            const Color(0xFF007AFF),
            '/admin',
          ),
          _ActionData(
            l10n.adminAnalytics,
            Icons.insights_rounded,
            const Color(0xFF007AFF),
            '/admin/analytics',
          ),
          _ActionData(
            l10n.adminServicePerformance,
            Icons.analytics_rounded,
            const Color(0xFF5856D6),
            '/admin/service-performance',
          ),
          _ActionData(
            l10n.adminDeliveryIntelligence,
            Icons.route_rounded,
            const Color(0xFF00897B),
            '/admin/delivery-intelligence',
          ),
          _ActionData(
            l10n.adminMerchantIntelligence,
            Icons.store_outlined,
            const Color(0xFF34C759),
            '/admin/merchant-intelligence',
          ),
        ],
      ),
      (
        l10n.adminMembersSection,
        const Color(0xFF4A90D9),
        Icons.people_rounded,
        [
          _ActionData(
            l10n.adminMembers,
            Icons.people_rounded,
            const Color(0xFF4A90D9),
            '/admin/members',
          ),
          _ActionData(
            l10n.adminVerifications,
            Icons.verified_user_rounded,
            const Color(0xFF34C759),
            '/admin/verifications',
          ),
          _ActionData(
            l10n.adminApprovals,
            Icons.fact_check_rounded,
            const Color(0xFF8B5CF6),
            '/admin/approvals',
          ),
          _ActionData(
            l10n.sanctions,
            Icons.gavel_rounded,
            const Color(0xFFFF9500),
            '/admin/sanctions',
          ),
          _ActionData(
            l10n.complaints,
            Icons.warning_amber_rounded,
            const Color(0xFFFF3B30),
            '/admin/complaints',
          ),
        ],
      ),
      (
        l10n.adminOperationsSection,
        const Color(0xFFFF9500),
        Icons.local_shipping_rounded,
        [
          _ActionData(
            l10n.adminOrdersPage,
            Icons.receipt_long_rounded,
            const Color(0xFFFF9500),
            '/admin/orders',
          ),
          _ActionData(
            l10n.adminDeliveries,
            Icons.delivery_dining_rounded,
            const Color(0xFFFF9500),
            '/admin/deliveries',
          ),
          _ActionData(
            l10n.adminDrivers,
            Icons.local_shipping_rounded,
            const Color(0xFF007AFF),
            '/admin/drivers',
          ),
          _ActionData(
            l10n.liveTracking,
            Icons.map_rounded,
            const Color(0xFF00C7BE),
            '/admin/live-tracking',
          ),
          _ActionData(
            l10n.supportChat,
            Icons.chat_bubble_rounded,
            const Color(0xFF34C759),
            '/admin/support-chat',
          ),
        ],
      ),
      (
        l10n.adminFinancialSection,
        const Color(0xFF5B3DF0),
        Icons.account_balance_rounded,
        [
          _ActionData(
            l10n.adminFinancialCenter,
            Icons.account_balance_rounded,
            const Color(0xFF5B3DF0),
            '/admin/financial-center',
          ),
          _ActionData(
            l10n.pendingTopups,
            Icons.swap_horiz_rounded,
            const Color(0xFF34C759),
            '/admin/topup-requests',
          ),
          _ActionData(
            l10n.settlements,
            Icons.payments_rounded,
            const Color(0xFFFF3B30),
            '/admin/settlements',
          ),
          _ActionData(
            l10n.regionalCollections,
            Icons.receipt_long_rounded,
            const Color(0xFF00C7BE),
            '/admin/collections',
          ),
          _ActionData(
            l10n.adminCommissions,
            Icons.percent_rounded,
            const Color(0xFF5B3DF0),
            '/admin/commissions',
          ),
          _ActionData(
            l10n.adminTransactionLedger,
            Icons.menu_book_rounded,
            const Color(0xFFFF9500),
            '/admin/transaction-ledger',
          ),
        ],
      ),
      (
        l10n.adminPlatformSection,
        const Color(0xFF34C759),
        Icons.storefront_rounded,
        [
          _ActionData(
            l10n.manageRegions,
            Icons.public_rounded,
            const Color(0xFF0D9488),
            '/admin/regions',
          ),
          _ActionData(
            l10n.adminCategories,
            Icons.category_rounded,
            const Color(0xFFAF52DE),
            '/admin/categories',
          ),
          _ActionData(
            l10n.adminBannersTitle,
            Icons.view_carousel_rounded,
            const Color(0xFFFF9500),
            '/admin/campaigns',
          ),
          _ActionData(
            l10n.adminMerchants,
            Icons.storefront_rounded,
            const Color(0xFF34C759),
            '/admin/merchants',
          ),
          _ActionData(
            l10n.adminPushNotifications,
            Icons.campaign_rounded,
            const Color(0xFF34C759),
            '/admin/push-notifications',
          ),
          _ActionData(
            l10n.auditLog,
            Icons.history_rounded,
            const Color(0xFF5B3DF0),
            '/admin/audit-log',
          ),
          _ActionData(
            l10n.adminSettingsMenu,
            Icons.tune_rounded,
            const Color(0xFFAF52DE),
            '/admin/settings',
          ),
        ],
      ),
    ];

    // Filter sections by search query
    final filtered = _query.isEmpty
        ? sections
        : sections
              .map(
                (s) => (
                  s.$1,
                  s.$2,
                  s.$3,
                  s.$4
                      .where((a) => a.label.toLowerCase().contains(_query))
                      .toList(),
                ),
              )
              .where((s) => s.$4.isNotEmpty)
              .toList();

    return Scaffold(
      appBar: AppBar(
        leading: MediaQuery.sizeOf(context).width < 1100
            ? const AdminMenuButton()
            : null,
        title: Text(l10n.adminQuickActions),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.search,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(l10n.noResultsFound))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (int g = 0; g < filtered.length; g++) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: filtered[g].$2.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  filtered[g].$3,
                                  size: 14,
                                  color: filtered[g].$2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                filtered[g].$1,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        PremiumCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < filtered[g].$4.length;
                                index++
                              ) ...[
                                if (index > 0)
                                  Divider(
                                    height: 1,
                                    indent: 60,
                                    endIndent: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                // Wrapped in a transparent Material so the
                                // tile's background/ink splash paint above
                                // PremiumCard's DecoratedBox (framework
                                // assertion otherwise).
                                Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    onTap: () => context.push(
                                      filtered[g].$4[index].route,
                                    ),
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 2,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: filtered[g].$4[index].color
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        filtered[g].$4[index].icon,
                                        color: filtered[g].$4[index].color,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      filtered[g].$4[index].label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionData {
  const _ActionData(this.label, this.icon, this.color, this.route);
  final String label;
  final IconData icon;
  final Color color;
  final String route;
}
