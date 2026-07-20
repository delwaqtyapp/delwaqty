
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _adminDeliveriesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.read(adminServiceProvider);
  final deliveries = await adminService.getRecentDeliveries();
  return deliveries.map((d) => {
    'id': d.id,
    'service_type': d.serviceType,
    'status': d.status,
    'sender_name': d.senderName ?? 'Unknown',
    'receiver_name': d.receiverName ?? 'Unknown',
    'items_description': d.itemDescription ?? '',
    'created_at': d.createdAt.toIso8601String(),
  }).toList();
});

class AdminDeliveriesPage extends ConsumerStatefulWidget {
  const AdminDeliveriesPage({super.key});

  @override
  ConsumerState<AdminDeliveriesPage> createState() => _AdminDeliveriesPageState();
}

class _AdminDeliveriesPageState extends ConsumerState<AdminDeliveriesPage> {
  String _serviceFilter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final deliveriesAsync = ref.watch(_adminDeliveriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deliveryManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_adminDeliveriesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _ServiceChip(
                      label: l10n.all,
                      selected: _serviceFilter.isEmpty,
                      onTap: () => setState(() => _serviceFilter = ''),
                      cs: cs,
                    ),
                    _ServiceChip(
                      label: l10n.food,
                      selected: _serviceFilter == 'food',
                      onTap: () => setState(() => _serviceFilter = 'food'),
                      cs: cs,
                    ),
                    _ServiceChip(
                      label: l10n.grocery,
                      selected: _serviceFilter == 'grocery',
                      onTap: () => setState(() => _serviceFilter = 'grocery'),
                      cs: cs,
                    ),
                    _ServiceChip(
                      label: l10n.pharmacy,
                      selected: _serviceFilter == 'pharmacy',
                      onTap: () => setState(() => _serviceFilter = 'pharmacy'),
                      cs: cs,
                    ),
                    _ServiceChip(
                      label: l10n.parcel,
                      selected: _serviceFilter == 'parcel',
                      onTap: () => setState(() => _serviceFilter = 'parcel'),
                      cs: cs,
                    ),
                    _ServiceChip(
                      label: l10n.package,
                      selected: _serviceFilter == 'direct_delivery',
                      onTap: () => setState(() => _serviceFilter = 'direct_delivery'),
                      cs: cs,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: deliveriesAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_adminDeliveriesProvider),
                ),
              ),
              data: (deliveries) {
                final filtered = _serviceFilter.isEmpty
                    ? deliveries
                    : deliveries.where((d) => d['service_type'] == _serviceFilter).toList();

                if (filtered.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: l10n.noDeliveriesFound,
                    message: _serviceFilter.isEmpty
                        ? l10n.noDeliveriesCreated
                        : l10n.noDeliveriesSelectedType,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final delivery = filtered[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DeliveryGlassTile(
                          delivery: delivery,
                          cs: cs,
                          l10n: l10n,
                          onStatusChanged: (status) async {
                            final adminService = ref.read(adminServiceProvider);
                            await adminService.updateDeliveryStatus(
                              delivery['id'] as String,
                              status,
                            );
                            ref.invalidate(_adminDeliveriesProvider);
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

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
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
                ? cs.secondary.withValues(alpha: 0.2)
                : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? cs.secondary.withValues(alpha: 0.5)
                  : cs.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? cs.secondary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryGlassTile extends StatelessWidget {
  const _DeliveryGlassTile({
    required this.delivery,
    required this.cs,
    required this.l10n,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> delivery;
  final ColorScheme cs;
  final AppLocalizations l10n;
  final Function(String) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final serviceType = delivery['service_type'] as String? ?? 'delivery';
    final status = delivery['status'] as String? ?? 'pending';
    final senderName = delivery['sender_name'] as String? ?? delivery['sender']?['name'] as String? ?? 'Unknown';
    final receiverName = delivery['receiver_name'] as String? ?? delivery['receiver']?['name'] as String? ?? 'Unknown';
    final items = delivery['items_description'] as String? ?? delivery['description'] as String? ?? '';
    final idShort = (delivery['id'] as String? ?? '').length > 8
        ? (delivery['id'] as String).substring(0, 8)
        : (delivery['id'] as String? ?? '');

    final statusColor = switch (status) {
      'pending' => const Color(0xFFFF9500),
      'confirmed' => const Color(0xFF007AFF),
      'picked_up' => const Color(0xFF5AC8FA),
      'in_transit' => const Color(0xFF5856D6),
      'delivered' => const Color(0xFF34C759),
      'cancelled' => const Color(0xFFFF3B30),
      _ => const Color(0xFF8E8E93),
    };

    final statusLabel = switch (status) {
      'pending' => l10n.pending,
      'confirmed' => l10n.confirmed,
      'picked_up' => l10n.pickedUp,
      'in_transit' => l10n.inTransit,
      'delivered' => l10n.delivered,
      'cancelled' => l10n.cancelled,
      _ => status,
    };

    final icon = switch (serviceType) {
      'food' => Icons.restaurant_rounded,
      'grocery' => Icons.shopping_basket_rounded,
      'pharmacy' => Icons.medical_services_rounded,
      'direct_delivery' => Icons.inventory_2_rounded,
      _ => Icons.local_shipping_rounded,
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
                child: Icon(icon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.deliveryNumber}$idShort',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      serviceType.replaceAll('_', ' ').toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.5,
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
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '${l10n.from}: $senderName',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '${l10n.to}: $receiverName',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.inventory_rounded, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    items,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                onSelected: onStatusChanged,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 16, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        l10n.updateStatus,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  if (status != 'confirmed') PopupMenuItem(value: 'confirmed', child: Text(l10n.confirm)),
                  if (status != 'picked_up') PopupMenuItem(value: 'picked_up', child: Text(l10n.markPickedUp)),
                  if (status != 'in_transit') PopupMenuItem(value: 'in_transit', child: Text(l10n.markInTransit)),
                  if (status != 'delivered') PopupMenuItem(value: 'delivered', child: Text(l10n.markDelivered)),
                  if (status != 'cancelled')
                    PopupMenuItem(
                      value: 'cancelled',
                      child: Text(l10n.cancel, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
