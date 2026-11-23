import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/admin/presentation/widgets/intelligence_stat_grid.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminDeliveryIntelligencePage extends ConsumerWidget {
  const AdminDeliveryIntelligencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final deliveryAsync = ref.watch(deliveryIntelligenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDeliveryIntelligence),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(deliveryIntelligenceProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(deliveryIntelligenceProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: deliveryAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: AppLoaderCircular(),
              ),
            ),
            error: (e, _) => PremiumCard(
              child: PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.error,
                message: l10n.errorLoadingMetrics,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(deliveryIntelligenceProvider),
              ),
            ),
            data: (data) => _buildContent(data, cs, context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    DeliveryIntelligence data,
    ColorScheme cs,
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          child: Text(
            l10n.driversSection,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 50),
          child: IntelligenceStatGrid(
            wideColumns: 4,
            stats: [
              IntelligenceStat(
                title: l10n.totalDrivers,
                value: data.totalDrivers.toString(),
                icon: Icons.people_outline_rounded,
                color: const Color(0xFF007AFF),
              ),
              IntelligenceStat(
                title: l10n.onlineStat,
                value: data.onlineDrivers.toString(),
                icon: Icons.wifi_rounded,
                color: const Color(0xFF34C759),
              ),
              IntelligenceStat(
                title: l10n.pendingStat,
                value: data.pendingDrivers.toString(),
                icon: Icons.pending_outlined,
                color: const Color(0xFFFF9500),
              ),
              IntelligenceStat(
                title: l10n.verifiedStat,
                value: data.verifiedDrivers.toString(),
                icon: Icons.verified_outlined,
                color: const Color(0xFF5B3DF0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 150),
          child: Text(
            l10n.deliveryPerformance,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 200),
          child: IntelligenceStatGrid(
            wideColumns: 3,
            stats: [
              IntelligenceStat(
                title: l10n.completedDeliveries,
                value: data.completedDeliveries.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF34C759),
              ),
              IntelligenceStat(
                title: l10n.pendingDeliveries,
                value: data.pendingDeliveries.toString(),
                icon: Icons.schedule_rounded,
                color: const Color(0xFFFF9500),
              ),
              IntelligenceStat(
                title: l10n.cancelledDeliveries,
                value: data.cancelledDeliveries.toString(),
                icon: Icons.cancel_outlined,
                color: const Color(0xFFFF3B30),
              ),
              IntelligenceStat(
                title: l10n.deliveryGmv,
                value:
                    '${l10n.currencySymbol} ${data.deliveryGmv.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
                color: const Color(0xFF5B3DF0),
              ),
              IntelligenceStat(
                title: l10n.driverEarnings,
                value:
                    '${l10n.currencySymbol} ${data.driverEarningsTotal.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF14B8A6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 300),
          child: Text(
            l10n.withdrawalsSection,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 350),
          child: PremiumCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.currencySymbol} ${data.pendingWithdrawalAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFF9500),
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.pendingWithdrawalsCount(data.pendingWithdrawals),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: cs.outlineVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.currencySymbol} ${data.paidWithdrawalAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF34C759),
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.paidWithdrawalsCount(data.paidWithdrawals),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
