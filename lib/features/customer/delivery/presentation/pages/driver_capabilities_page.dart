import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

class DriverCapabilitiesPage extends ConsumerStatefulWidget {
  const DriverCapabilitiesPage({required this.driverId, super.key});
  final String driverId;

  @override
  ConsumerState<DriverCapabilitiesPage> createState() =>
      _DriverCapabilitiesPageState();
}

class _DriverCapabilitiesPageState
    extends ConsumerState<DriverCapabilitiesPage> {
  static const _serviceTypes = [
    ('food_delivery', Icons.restaurant_rounded, 'food'),
    ('grocery_delivery', Icons.shopping_cart_rounded, 'grocery'),
    ('pharmacy_delivery', Icons.local_pharmacy_rounded, 'pharmacy'),
    ('marketplace_delivery', Icons.store_rounded, 'marketplace'),
    ('courier', Icons.local_shipping_rounded, 'courier'),
    ('package_delivery', Icons.inventory_2_rounded, 'package'),
    ('document_delivery', Icons.description_rounded, 'document'),
    ('flowerDelivery', Icons.local_florist_rounded, 'flower'),
    ('retail_delivery', Icons.shopping_bag_rounded, 'retail'),
  ];

  late Set<String> _selectedTypes;
  late bool _acceptsDeliveries;
  late double _maxDistance;
  late double _maxWeight;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final capAsync = ref.watch(driverCapabilitiesProvider(widget.driverId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: capAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerCard(height: 80),
            SizedBox(height: 12),
            ShimmerCard(height: 80),
            SizedBox(height: 12),
            ShimmerCard(height: 120),
          ],
        ),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (cap) {
          if (!_initialized) {
            _selectedTypes = Set<String>.from(cap.serviceTypes);
            _acceptsDeliveries = cap.acceptsDeliveries;
            _maxDistance = cap.maxDeliveryDistanceKm;
            _maxWeight = cap.maxWeightKg;
            _initialized = true;
          }
          return _CapabilitiesBody(
            driverId: widget.driverId,
            selectedTypes: _selectedTypes,
            acceptsDeliveries: _acceptsDeliveries,
            maxDistance: _maxDistance,
            maxWeight: _maxWeight,
            onTypesChanged: (types) => setState(() => _selectedTypes = types),
            onAcceptsChanged: (v) => setState(() => _acceptsDeliveries = v),
            onDistanceChanged: (v) => setState(() => _maxDistance = v),
            onWeightChanged: (v) => setState(() => _maxWeight = v),
            serviceTypes: _serviceTypes,
          );
        },
      ),
    );
  }
}

class _CapabilitiesBody extends ConsumerWidget {
  const _CapabilitiesBody({
    required this.driverId,
    required this.selectedTypes,
    required this.acceptsDeliveries,
    required this.maxDistance,
    required this.maxWeight,
    required this.onTypesChanged,
    required this.onAcceptsChanged,
    required this.onDistanceChanged,
    required this.onWeightChanged,
    required this.serviceTypes,
  });

  final String driverId;
  final Set<String> selectedTypes;
  final bool acceptsDeliveries;
  final double maxDistance;
  final double maxWeight;
  final ValueChanged<Set<String>> onTypesChanged;
  final ValueChanged<bool> onAcceptsChanged;
  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<double> onWeightChanged;
  final List<(String, IconData, String)> serviceTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedFadeIn(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.online),
            subtitle: Text(
                acceptsDeliveries ? l10n.youAreOnline : l10n.youAreOffline),
            value: acceptsDeliveries,
            onChanged: onAcceptsChanged,
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 50),
          child: Text(
            l10n.delivery,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 100),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: serviceTypes.map((entry) {
              final (type, icon, _) = entry;
              final selected = selectedTypes.contains(type);
              return FilterChip(
                selected: selected,
                avatar: Icon(icon, size: 18),
                label: Text(type.replaceAll('_', ' ')),
                onSelected: (v) {
                  final next = Set<String>.from(selectedTypes);
                  if (v) {
                    next.add(type);
                  } else {
                    next.remove(type);
                  }
                  onTypesChanged(next);
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 150),
          child: Text(
            '${l10n.deliveryAddress} (${maxDistance.toStringAsFixed(0)} ${l10n.kmUnit})',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Slider(
          value: maxDistance,
          min: 1,
          max: 50,
          divisions: 49,
          label: '${maxDistance.toStringAsFixed(0)} ${l10n.kmUnit}',
          onChanged: onDistanceChanged,
        ),
        const SizedBox(height: 8),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 200),
          child: Text(
            '${l10n.orderSummary} (${maxWeight.toStringAsFixed(0)} ${l10n.kgUnit})',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Slider(
          value: maxWeight,
          min: 1,
          max: 50,
          divisions: 49,
          label: '${maxWeight.toStringAsFixed(0)} ${l10n.kgUnit}',
          onChanged: onWeightChanged,
        ),
        const SizedBox(height: 24),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 250),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _save(context, ref),
              child: Text(l10n.save),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(deliveryRepositoryProvider).updateDriverCapabilities(
            driverId,
            serviceTypes: selectedTypes.toList(),
            acceptsDeliveries: acceptsDeliveries,
            maxDistance: maxDistance,
            maxWeight: maxWeight,
          );
      ref.invalidate(driverCapabilitiesProvider(driverId));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorWithMessage(e.toString()))),
      );
    }
  }
}
