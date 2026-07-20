import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

class AdminAnalyticsPage extends ConsumerWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedFadeIn(
              child: Text(
                'Revenue Overview',
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
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_chart_outlined_rounded, color: Colors.white, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Revenue Chart',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ج.م 0.00 total',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
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
                'Order Trends',
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
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart_rounded, color: Colors.white, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Order Trends',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '0 orders today',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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
                'Peak Hours',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 220),
              child: _PeerMetricCard(
                label: 'Peak Hours',
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
                'Top Merchants',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const AnimatedFadeIn(
              delay: Duration(milliseconds: 280),
              child: GlassCard(
                borderRadius: 20,
                child: PremiumEmptyState(
                  icon: Icons.store_outlined,
                  title: 'No data yet',
                  message: 'Merchant performance data will appear here.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 310),
              child: Text(
                'Driver Performance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const AnimatedFadeIn(
              delay: Duration(milliseconds: 340),
              child: GlassCard(
                borderRadius: 20,
                child: PremiumEmptyState(
                  icon: Icons.speed_rounded,
                  title: 'No data yet',
                  message: 'Driver performance metrics will appear here.',
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
