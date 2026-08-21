import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

class AdminQuickActionsPage extends StatelessWidget {
  const AdminQuickActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final sections = [
      (
        l10n.adminLeadershipSection,
        const Color(0xFF007AFF),
        [
          _ActionData(l10n.adminAnalytics, Icons.insights_rounded, const Color(0xFF007AFF), '/admin/analytics'),
          _ActionData(l10n.adminDeliveryIntelligence, Icons.route_rounded, const Color(0xFF00897B), '/admin/delivery-intelligence'),
          _ActionData(l10n.adminMerchantIntelligence, Icons.store_outlined, const Color(0xFF34C759), '/admin/merchant-intelligence'),
          _ActionData(l10n.adminProviderIntelligence, Icons.engineering_outlined, const Color(0xFF0288D1), '/admin/provider-intelligence'),
          _ActionData(l10n.adminWalletIntelligence, Icons.account_balance_wallet_rounded, const Color(0xFFAF52DE), '/admin/wallet-intelligence'),
          _ActionData(l10n.adminServicePerformance, Icons.analytics_rounded, const Color(0xFF5856D6), '/admin/service-performance'),
        ],
      ),
      (
        l10n.adminMembersSection,
        const Color(0xFF4A90D9),
        [
          _ActionData(l10n.adminVerifications, Icons.verified_user_rounded, const Color(0xFF34C759), '/admin/verifications'),
          _ActionData(l10n.sanctions, Icons.gavel_rounded, const Color(0xFFFF9500), '/admin/sanctions'),
          _ActionData(l10n.complaints, Icons.warning_amber_rounded, const Color(0xFFFF3B30), '/admin/complaints'),
          _ActionData(l10n.liveTracking, Icons.map_rounded, const Color(0xFF00C7BE), '/admin/live-tracking'),
          _ActionData(l10n.adminEscalations, Icons.priority_high_rounded, const Color(0xFFFF6482), '/admin/escalations'),
        ],
      ),
      (
        l10n.adminOperationsSection,
        const Color(0xFFFF9500),
        [
          _ActionData(l10n.adminDeliveries, Icons.delivery_dining_rounded, const Color(0xFFFF9500), '/admin/deliveries'),
          _ActionData(l10n.adminDrivers, Icons.local_shipping_rounded, const Color(0xFF007AFF), '/admin/drivers'),
          _ActionData(l10n.adminEmergency, Icons.sos_rounded, const Color(0xFFFF3B30), '/admin/emergency'),
          _ActionData(l10n.supportChat, Icons.chat_bubble_rounded, const Color(0xFF34C759), '/admin/support-chat'),
        ],
      ),
      (
        l10n.adminFinancialSection,
        const Color(0xFF5B3DF0),
        [
          _ActionData(l10n.adminTransactionLedger, Icons.receipt_long_rounded, const Color(0xFFFF9500), '/admin/transaction-ledger'),
          _ActionData(l10n.adminCommissions, Icons.percent_rounded, const Color(0xFF5B3DF0), '/admin/commissions'),
        ],
      ),
      (
        l10n.adminPlatformSection,
        const Color(0xFF34C759),
        [
          _ActionData(l10n.adminMgmtList, Icons.group_rounded, const Color(0xFF4A90D9), '/admin/admins'),
          _ActionData(l10n.adminMerchants, Icons.storefront_rounded, const Color(0xFF34C759), '/admin/merchants'),
        ],
      ),
      (
        l10n.adminMarketingSection,
        const Color(0xFF34C759),
        [
          _ActionData(l10n.adminPushNotifications, Icons.campaign_rounded, const Color(0xFF34C759), '/admin/push-notifications'),
        ],
      ),
      (
        l10n.adminAdministrationSection,
        const Color(0xFF8B5CF6),
        [
          _ActionData(l10n.adminApprovals, Icons.fact_check_rounded, const Color(0xFF8B5CF6), '/admin/approvals'),
        ],
      ),
      (
        l10n.adminSettingsGroupSection,
        const Color(0xFFAF52DE),
        [
          _ActionData(l10n.adminSettingsPage, Icons.settings_rounded, const Color(0xFFAF52DE), '/admin/settings'),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminQuickActions),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (int g = 0; g < sections.length; g++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: sections[g].$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(sections[g].$2 == const Color(0xFF007AFF) ? Icons.speed_rounded : Icons.circle, size: 12, color: sections[g].$2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sections[g].$1,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 4 : 3;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sections[g].$3.length,
                  itemBuilder: (context, index) {
                    final action = sections[g].$3[index];
                    return GestureDetector(
                      onTap: () => context.push(action.route),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: action.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(action.icon, color: action.color, size: 22),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              action.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
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
