import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

class AdminDeliveryIntelligencePage extends ConsumerWidget {
  const AdminDeliveryIntelligencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final deliveryAsync = ref.watch(deliveryIntelligenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('استخبارات التوصيل'),
        actions: [
          IconButton(
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

  Widget _buildContent(DeliveryIntelligence data, ColorScheme cs, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedFadeIn(
          child: Text(
            'السائقون',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 50),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: [
                  _StatCard('إجمالي السائقين', data.totalDrivers.toString(), Icons.people_outline_rounded, const Color(0xFF007AFF)),
                  _StatCard('متصلون', data.onlineDrivers.toString(), Icons.wifi_rounded, const Color(0xFF34C759)),
                  _StatCard('معلقون', data.pendingDrivers.toString(), Icons.pending_outlined, const Color(0xFFFF9500)),
                  _StatCard('موثقون', data.verifiedDrivers.toString(), Icons.verified_outlined, const Color(0xFF5B3DF0)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 150),
          child: Text(
            'أداء التوصيل',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _StatCard('مكتملة', data.completedDeliveries.toString(), Icons.check_circle_outline_rounded, const Color(0xFF34C759)),
                  _StatCard('معلقة', data.pendingDeliveries.toString(), Icons.schedule_rounded, const Color(0xFFFF9500)),
                  _StatCard('ملغاة', data.cancelledDeliveries.toString(), Icons.cancel_outlined, const Color(0xFFFF3B30)),
                  _StatCard('GMV', 'ج.م ${data.deliveryGmv.toStringAsFixed(0)}', Icons.payments_outlined, const Color(0xFF5B3DF0)),
                  _StatCard('أرباح السائقين', 'ج.م ${data.driverEarningsTotal.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, const Color(0xFF14B8A6)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 300),
          child: Text(
            'السحوبات',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 350),
          child: PremiumCard(
            padding: const EdgeInsets.all(16),
            radius: AppSpacing.radiusCard,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ج.م ${data.pendingWithdrawalAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF9500),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.pendingWithdrawals} سحوبات معلقة',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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
                        'ج.م ${data.paidWithdrawalAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF34C759),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.paidWithdrawals} سحوبات مدفوعة',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      radius: AppSpacing.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
