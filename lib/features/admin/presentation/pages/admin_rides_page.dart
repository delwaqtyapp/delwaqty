import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _adminRidesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.read(adminServiceProvider);
  final rides = await adminService.getRecentRides();
  return rides.map((r) => {
    'id': r.id,
    'status': r.status,
    'fare': r.fare ?? 0,
    'pickup_address': 'Pickup',
    'dropoff_address': 'Dropoff',
    'driver_name': 'Assigned',
    'passenger_name': 'Passenger',
    'created_at': r.createdAt.toIso8601String(),
  }).toList();
});

class AdminRidesPage extends ConsumerStatefulWidget {
  const AdminRidesPage({super.key});

  @override
  ConsumerState<AdminRidesPage> createState() => _AdminRidesPageState();
}

class _AdminRidesPageState extends ConsumerState<AdminRidesPage> {
  String _statusFilter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final ridesAsync = ref.watch(_adminRidesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rideMonitoring),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_adminRidesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              borderRadius: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.all,
                      selected: _statusFilter.isEmpty,
                      onTap: () => setState(() => _statusFilter = ''),
                      cs: cs,
                    ),
                    _FilterChip(
                      label: l10n.searching,
                      selected: _statusFilter == 'searching',
                      onTap: () => setState(() => _statusFilter = 'searching'),
                      cs: cs,
                    ),
                    _FilterChip(
                      label: l10n.matchedRide,
                      selected: _statusFilter == 'matched',
                      onTap: () => setState(() => _statusFilter = 'matched'),
                      cs: cs,
                    ),
                    _FilterChip(
                      label: l10n.inTrip,
                      selected: _statusFilter == 'in_trip',
                      onTap: () => setState(() => _statusFilter = 'in_trip'),
                      cs: cs,
                    ),
                    _FilterChip(
                      label: l10n.completed,
                      selected: _statusFilter == 'completed',
                      onTap: () => setState(() => _statusFilter = 'completed'),
                      cs: cs,
                    ),
                    _FilterChip(
                      label: l10n.cancelled,
                      selected: _statusFilter == 'cancelled',
                      onTap: () => setState(() => _statusFilter = 'cancelled'),
                      cs: cs,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ridesAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_adminRidesProvider),
                ),
              ),
              data: (rides) {
                final filtered = _statusFilter.isEmpty
                    ? rides
                    : rides.where((r) => r['status'] == _statusFilter).toList();

                if (filtered.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.map_outlined,
                    title: l10n.noRidesFound,
                    message: _statusFilter.isEmpty
                        ? l10n.noRidesCreated
                        : l10n.noRidesSelectedStatus,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ride = filtered[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RideGlassTile(ride: ride, cs: cs),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.2)
                : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.5)
                  : cs.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RideGlassTile extends StatelessWidget {
  const _RideGlassTile({
    required this.ride,
    required this.cs,
  });

  final Map<String, dynamic> ride;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ride['status'] as String? ?? 'searching';
    final pickup = ride['pickup_location'] as String? ?? ride['pickup_address'] as String? ?? '';
    final dropoff = ride['dropoff_location'] as String? ?? ride['dropoff_address'] as String? ?? '';
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
    final driverName = ride['driver_name'] as String? ?? ride['driver']?['name'] as String? ?? '';
    final passengerName = ride['passenger_name'] as String? ?? ride['passenger']?['name'] as String? ?? '';
    final idShort = (ride['id'] as String? ?? '').length > 8
        ? (ride['id'] as String).substring(0, 8)
        : (ride['id'] as String? ?? '');

    final statusColor = switch (status) {
      'searching' => const Color(0xFFFF9500),
      'matched' => const Color(0xFF007AFF),
      'in_trip' => const Color(0xFF34C759),
      'completed' => const Color(0xFF8E8E93),
      'cancelled' => const Color(0xFFFF3B30),
      _ => const Color(0xFF8E8E93),
    };

    final statusLabel = switch (status) {
      'searching' => l10n.searching,
      'matched' => l10n.matchedRide,
      'in_trip' => l10n.inTrip,
      'completed' => l10n.completed,
      'cancelled' => l10n.cancelled,
      _ => status,
    };

    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _statusIcon(status),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.rideNumber}$idShort',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$passengerName · $driverName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RideLocationRow(icon: Icons.trip_origin_rounded, address: pickup, color: Colors.green, cs: cs),
          const SizedBox(height: 6),
          _RideLocationRow(icon: Icons.location_on_rounded, address: dropoff, color: Colors.red, cs: cs),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ج.م ${fare.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              Text(
                _formatTime(ride['created_at'] as String?, l10n),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'searching' => Icons.radar_rounded,
      'matched' => Icons.check_circle_outline_rounded,
      'in_trip' => Icons.directions_car_rounded,
      'completed' => Icons.check_circle_rounded,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.help_outline_rounded,
    };
  }

  String _formatTime(String? timestamp, AppLocalizations l10n) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return l10n.justNow;
      if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
      if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
      return l10n.daysAgo(diff.inDays);
    } catch (_) {
      return '';
    }
  }
}

class _RideLocationRow extends StatelessWidget {
  const _RideLocationRow({
    required this.icon,
    required this.address,
    required this.color,
    required this.cs,
  });

  final IconData icon;
  final String address;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
