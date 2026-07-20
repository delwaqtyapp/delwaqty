import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminAnalyticsPage extends ConsumerWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analytics),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedFadeIn(
              child: Text(
                l10n.revenueOverview,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 80),
              child: GlassCard(
                borderRadius: 20,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90D9), Color(0xFFAF52DE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.insert_chart_outlined_rounded, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          l10n.revenueChart,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.currencySymbol} 0.00 ${l10n.total}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 130),
              child: Text(
                l10n.orderTrends,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 160),
              child: GlassCard(
                borderRadius: 20,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9500), Color(0xFFFF3B30)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.show_chart_rounded, color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          l10n.orderTrends,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          l10n.zeroOrdersToday,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 190),
              child: Text(
                l10n.peakHours,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 220),
              child: _PeerMetricCard(
                label: l10n.peakHours,
                value: '00:00 - 00:00',
                icon: Icons.access_time_rounded,
                color: const Color(0xFF00C7BE),
                cs: cs,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 250),
              child: Text(
                l10n.topMerchants,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 280),
              child: GlassCard(
                borderRadius: 20,
                child: PremiumEmptyState(
                  icon: Icons.store_outlined,
                  title: l10n.noDataYet,
                  message: l10n.merchantPerformancePlaceholder,
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 310),
              child: Text(
                l10n.driverPerformance,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 340),
              child: GlassCard(
                borderRadius: 20,
                child: PremiumEmptyState(
                  icon: Icons.speed_rounded,
                  title: l10n.noDataYet,
                  message: l10n.driverPerformancePlaceholder,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerMetricCard extends StatelessWidget {
  const _PeerMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.cs,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
