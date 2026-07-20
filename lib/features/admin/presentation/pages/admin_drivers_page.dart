import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _adminDriversProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.read(adminServiceProvider);
  final drivers = await adminService.getAllDrivers();
  return drivers.map((d) => {
    'id': d.id,
    'name': d.fullName,
    'phone': d.phone ?? '',
    'is_active': d.isActive,
    'is_online': d.isAvailable,
    'verification_status': d.isVerified ? 'verified' : 'pending',
    'rating': d.rating,
    'trips_count': d.totalTrips,
    'vehicle': {
      'model': d.vehicleType ?? '',
      'plate': d.vehiclePlate ?? '',
    },
  }).toList();
});

class AdminDriversPage extends ConsumerStatefulWidget {
  const AdminDriversPage({super.key});

  @override
  ConsumerState<AdminDriversPage> createState() => _AdminDriversPageState();
}

class _AdminDriversPageState extends ConsumerState<AdminDriversPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final driversAsync = ref.watch(_adminDriversProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_adminDriversProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              borderRadius: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Total', value: '--', icon: Icons.people_outline_rounded, color: cs.primary, cs: cs),
                  _StatItem(label: 'Active', value: '--', icon: Icons.check_circle_outline_rounded, color: Colors.green, cs: cs),
                  _StatItem(label: 'Pending', value: '--', icon: Icons.pending_outlined, color: Colors.orange, cs: cs),
                  _StatItem(label: 'Rating', value: '--', icon: Icons.star_outline_rounded, color: Colors.amber, cs: cs),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: driversAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_adminDriversProvider),
                ),
              ),
              data: (drivers) {
                final filtered = drivers.where((d) {
                  if (_searchQuery.isEmpty) return true;
                  final name = (d['name'] as String? ?? '').toLowerCase();
                  final phone = (d['phone'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'No drivers found',
                    message: 'No drivers match your search criteria.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final driver = filtered[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DriverGlassTile(
                          driver: driver,
                          cs: cs,
                          l10n: l10n,
                          onVerify: () async {
                            final adminService = ref.read(adminServiceProvider);
                            await adminService.verifyDriver(
                              driverId: driver['id'] as String,
                              isVerified: true,
                            );
                            ref.invalidate(_adminDriversProvider);
                          },
                          onSuspend: () async {
                            final adminService = ref.read(adminServiceProvider);
                            await adminService.verifyDriver(
                              driverId: driver['id'] as String,
                              isVerified: false,
                            );
                            ref.invalidate(_adminDriversProvider);
                          },
                        ),
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

class _StatItem extends StatelessWidget {
  const _StatItem({
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DriverGlassTile extends StatelessWidget {
  const _DriverGlassTile({
    required this.driver,
    required this.cs,
    required this.l10n,
    required this.onVerify,
    required this.onSuspend,
  });

  final Map<String, dynamic> driver;
  final ColorScheme cs;
  final AppLocalizations l10n;
  final VoidCallback onVerify;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    final name = driver['name'] as String? ?? 'Unknown';
    final phone = driver['phone'] as String? ?? '';
    final isActive = driver['is_active'] as bool? ?? false;
    final verificationStatus = driver['verification_status'] as String? ?? 'pending';
    final rating = (driver['rating'] as num?)?.toDouble() ?? 0.0;
    final tripsCount = (driver['trips_count'] as int?) ?? 0;
    final vehicle = driver['vehicle'] as Map<String, dynamic>?;
    final vehicleModel = vehicle?['model'] as String? ?? '';
    final vehiclePlate = vehicle?['plate'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    switch (verificationStatus) {
      case 'verified':
        statusColor = Colors.green;
        statusLabel = 'Verified';
        break;
      case 'suspended':
        statusColor = Colors.red;
        statusLabel = 'Suspended';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Pending';
    }

    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DriverInfoChip(icon: Icons.star_rounded, label: rating.toStringAsFixed(1), color: Colors.amber),
              const SizedBox(width: 8),
              _DriverInfoChip(icon: Icons.route_rounded, label: '$tripsCount trips', color: cs.primary),
              if (vehicleModel.isNotEmpty) ...[
                const SizedBox(width: 8),
                _DriverInfoChip(icon: Icons.directions_car_rounded, label: vehicleModel, color: cs.secondary),
              ],
            ],
          ),
          if (vehiclePlate.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Plate: $vehiclePlate',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (verificationStatus != 'verified')
                TextButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('Verify'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              if (verificationStatus != 'suspended')
                TextButton.icon(
                  onPressed: onSuspend,
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Suspend'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverInfoChip extends StatelessWidget {
  const _DriverInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
