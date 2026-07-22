import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class SafetyHubPage extends ConsumerWidget {
  const SafetyHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.error, cs.error.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.safetyHub,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.safetyHubDesc,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(l10n.tripInstructions, Icons.menu_book_rounded, cs),
                        const SizedBox(height: 12),
                        _buildInstructionTile(
                          context,
                          icon: Icons.play_circle_outline_rounded,
                          title: l10n.beforeTrip,
                          subtitle: l10n.beforeTripInstructions,
                          color: Colors.blue,
                          cs: cs,
                        ),
                        _buildInstructionTile(
                          context,
                          icon: Icons.directions_car_rounded,
                          title: l10n.duringTrip,
                          subtitle: l10n.duringTripInstructions,
                          color: Colors.orange,
                          cs: cs,
                        ),
                        _buildInstructionTile(
                          context,
                          icon: Icons.flag_outlined,
                          title: l10n.afterTrip,
                          subtitle: l10n.afterTripInstructions,
                          color: Colors.green,
                          cs: cs,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(l10n.driverInstructions, Icons.badge_rounded, cs),
                        const SizedBox(height: 12),
                        _buildInstructionTile(
                          context,
                          icon: Icons.person_search_rounded,
                          title: l10n.beforeTrip,
                          subtitle: l10n.driverBeforeTrip,
                          color: Colors.blue,
                          cs: cs,
                        ),
                        _buildInstructionTile(
                          context,
                          icon: Icons.route_rounded,
                          title: l10n.duringTrip,
                          subtitle: l10n.driverDuringTrip,
                          color: Colors.orange,
                          cs: cs,
                        ),
                        _buildInstructionTile(
                          context,
                          icon: Icons.check_circle_outline_rounded,
                          title: l10n.afterTrip,
                          subtitle: l10n.driverAfterTrip,
                          color: Colors.green,
                          cs: cs,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(l10n.safetyTools, Icons.build_rounded, cs),
                        const SizedBox(height: 12),
                        _buildToolTile(
                          context,
                          icon: Icons.emergency_rounded,
                          title: l10n.sosAlertTool,
                          subtitle: l10n.sosAlertDesc,
                          color: Colors.red,
                          onTap: () => context.push('/safety/settings'),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.share_location_rounded,
                          title: l10n.tripSharingTool,
                          subtitle: l10n.tripSharingDesc,
                          color: AppColors.primaryLight,
                          onTap: () => context.push('/safety/settings'),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.contacts_rounded,
                          title: l10n.trustedContactsTool,
                          subtitle: l10n.trustedContactsDesc,
                          color: Colors.teal,
                          onTap: () => context.push('/safety/contacts'),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.pin_rounded,
                          title: l10n.pickupOtpTool,
                          subtitle: l10n.pickupOtpDesc,
                          color: Colors.green,
                          onTap: () => context.push('/safety/settings'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(l10n.safetyTips, Icons.lightbulb_rounded, cs),
                        const SizedBox(height: 12),
                        _buildTipItem(l10n.tip1, cs),
                        _buildTipItem(l10n.tip2, cs),
                        _buildTipItem(l10n.tip3, cs),
                        _buildTipItem(l10n.tip4, cs),
                        _buildTipItem(l10n.tip5, cs),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryLight),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required ColorScheme cs,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outline.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
