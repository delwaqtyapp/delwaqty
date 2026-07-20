import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

class DriverDeliveryHubPage extends ConsumerWidget {
  const DriverDeliveryHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final userId = authState is AuthAuthenticated ? authState.user.id : null;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.delivery)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }

    final profileAsync = ref.watch(driverProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.delivery)),
      body: profileAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerCard(height: 100),
            SizedBox(height: 12),
            ShimmerCard(height: 100),
            SizedBox(height: 12),
            ShimmerCard(height: 100),
          ],
        ),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (profile) {
          if (profile == null || profile.vehicleType == null) {
            return _RegisterPrompt(userId: userId);
          }
          return _DeliveryHubBody(profile: profile);
        },
      ),
    );
  }
}

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(l10n.becomeADriver,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.joinFleetSubtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DeliveryHubBody extends ConsumerStatefulWidget {
  const _DeliveryHubBody({required this.profile});
  final dynamic profile;

  @override
  ConsumerState<_DeliveryHubBody> createState() => _DeliveryHubBodyState();
}

class _DeliveryHubBodyState extends ConsumerState<_DeliveryHubBody> {
  bool _offerShowing = false;

  String get _driverId => widget.profile.id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onlineState = ref.watch(driverOnlineProvider(_driverId));
    final online = onlineState.valueOrNull ?? false;

    ref.listen<AsyncValue<DeliveryOrder?>>(activeDeliveryProvider(_driverId),
        (prev, next) {
      final order = next.valueOrNull;
      if (order != null && order.status != 'completed' && order.status != 'cancelled') {
        context.push('/driver/delivery/${order.id}');
      }
    });

    if (online) {
      ref.listen<AsyncValue<List<RideOffer>>>(deliveryOffersProvider(_driverId),
          (prev, next) {
        final offers = next.valueOrNull ?? const [];
        if (offers.isNotEmpty && !_offerShowing) {
          _presentOffer(offers.first);
        }
      });
    }

    final statsAsync = ref.watch(driverStatsProvider(_driverId));
    final activeDeliveryAsync = ref.watch(activeDeliveryProvider(_driverId));
    final capabilitiesAsync = ref.watch(driverCapabilitiesProvider(_driverId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverStatsProvider(_driverId));
        ref.invalidate(activeDeliveryProvider(_driverId));
        ref.invalidate(driverCapabilitiesProvider(_driverId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedFadeIn(
            child: _OnlineCard(
              online: online,
              loading: onlineState.isLoading,
              onToggle: () =>
                  ref.read(driverOnlineProvider(_driverId).notifier).toggle(),
            ),
          ),
          const SizedBox(height: 16),
          activeDeliveryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (order) {
              if (order == null ||
                  order.status == 'completed' ||
                  order.status == 'cancelled') {
                return const SizedBox.shrink();
              }
              return AnimatedFadeIn(
                delay: const Duration(milliseconds: 50),
                child: _ActiveDeliveryCard(order: order),
              );
            },
          ),
          const SizedBox(height: 16),
          statsAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (e, _) => const SizedBox.shrink(),
            data: (stats) => AnimatedFadeIn(
              delay: const Duration(milliseconds: 100),
              child: _StatsRow(stats: stats),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 150),
            child: OutlinedButton.icon(
              onPressed: () => _showCapabilitiesSheet(context, ref),
              icon: const Icon(Icons.tune_rounded),
              label: Text(l10n.settings),
            ),
          ),
          const SizedBox(height: 32),
          if (online)
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 200),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.wifi_tethering_rounded,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.waitingForRides,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _presentOffer(RideOffer offer) async {
    _offerShowing = true;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeliveryOfferDialog(offer: offer),
    );
    _offerShowing = false;
    if (!mounted) return;
    if (accepted == true) {
      try {
        await ref
            .read(deliveryRepositoryProvider)
            .acceptDeliveryRequest(offer.rideId, offer.driverId);
        if (mounted) context.push('/driver/delivery/${offer.rideId}');
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorWithMessage(e.toString()))),
        );
      }
    } else if (accepted == false) {
      try {
        await ref
            .read(deliveryRepositoryProvider)
            .rejectDeliveryRequest(offer.rideId, offer.driverId);
      } catch (_) {}
    }
  }

  void _showCapabilitiesSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CapabilitiesBottomSheet(driverId: _driverId),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({
    required this.online,
    required this.loading,
    required this.onToggle,
  });

  final bool online;
  final bool loading;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: online
              ? [Colors.green.shade600, Colors.green.shade400]
              : [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainerHigh],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            online ? l10n.online : l10n.offline,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: online ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
                  value: online,
                  onChanged: (_) => onToggle(),
                ),
        ],
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({required this.order});
  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/driver/delivery/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delivery_dining_rounded,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.serviceType,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.itemsSummary ?? order.dropoffAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final dynamic stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: l10n.todayRides,
            value: '${stats.todayRides}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStat(
            label: l10n.todayEarnings,
            value: l10n.amountWithCurrency(
                stats.todayEarnings.toStringAsFixed(0),
                l10n.currencySymbol),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DeliveryOfferDialog extends StatefulWidget {
  const _DeliveryOfferDialog({required this.offer});
  final dynamic offer;

  @override
  State<_DeliveryOfferDialog> createState() => _DeliveryOfferDialogState();
}

class _DeliveryOfferDialogState extends State<_DeliveryOfferDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    final remaining = widget.offer.remaining;
    _timerController = AnimationController(
      vsync: this,
      duration: remaining,
    )..forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final offer = widget.offer;
    return AlertDialog(
      title: Text(l10n.delivery),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _timerController,
              builder: (context, _) {
                final remaining = _timerController.isCompleted
                    ? Duration.zero
                    : Duration(
                        milliseconds: (_timerController.upperBound -
                                _timerController.value *
                                    _timerController.upperBound)
                            .toInt());
                return LinearProgressIndicator(
                  value: _timerController.value,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                );
              },
            ),
            const SizedBox(height: 16),
            Text('${offer.pickupAddress}',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Icon(Icons.arrow_downward_rounded,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text('${offer.dropoffAddress}',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('${offer.distanceKm.toStringAsFixed(1)} km'),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.amountWithCurrency(
                        offer.fare.toStringAsFixed(0), offer.currency),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class _CapabilitiesBottomSheet extends ConsumerStatefulWidget {
  const _CapabilitiesBottomSheet({required this.driverId});
  final String driverId;

  @override
  ConsumerState<_CapabilitiesBottomSheet> createState() =>
      _CapabilitiesBottomSheetState();
}

class _CapabilitiesBottomSheetState
    extends ConsumerState<_CapabilitiesBottomSheet> {
  static const _serviceTypes = [
    ('food_delivery', Icons.restaurant_rounded),
    ('grocery_delivery', Icons.shopping_cart_rounded),
    ('pharmacy_delivery', Icons.local_pharmacy_rounded),
    ('marketplace_delivery', Icons.store_rounded),
    ('courier', Icons.local_shipping_rounded),
    ('package_delivery', Icons.inventory_2_rounded),
    ('document_delivery', Icons.description_rounded),
    ('flowerDelivery', Icons.local_florist_rounded),
    ('retail_delivery', Icons.shopping_bag_rounded),
  ];

  late Set<String> _selectedTypes;
  late bool _acceptsDeliveries;
  late double _maxDistance;
  late double _maxWeight;

  @override
  void initState() {
    super.initState();
    final cap = ref.read(driverCapabilitiesProvider(widget.driverId)).valueOrNull;
    _selectedTypes = Set<String>.from(cap?.serviceTypes ?? const ['ride']);
    _acceptsDeliveries = cap?.acceptsDeliveries ?? false;
    _maxDistance = cap?.maxDeliveryDistanceKm ?? 15;
    _maxWeight = cap?.maxWeightKg ?? 20;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settings,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.online),
              subtitle: Text(_acceptsDeliveries ? l10n.youAreOnline : l10n.youAreOffline),
              value: _acceptsDeliveries,
              onChanged: (v) => setState(() => _acceptsDeliveries = v),
            ),
            const Divider(),
            Text(l10n.delivery,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _serviceTypes.map((entry) {
                final (type, icon) = entry;
                final selected = _selectedTypes.contains(type);
                return FilterChip(
                  selected: selected,
                  avatar: Icon(icon, size: 18),
                  label: Text(type.replaceAll('_', ' ')),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedTypes.add(type);
                      } else {
                        _selectedTypes.remove(type);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('${l10n.deliveryAddress} (${_maxDistance.toStringAsFixed(0)} km)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Slider(
              value: _maxDistance,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${_maxDistance.toStringAsFixed(0)} km',
              onChanged: (v) => setState(() => _maxDistance = v),
            ),
            Text('${l10n.orderSummary} (${_maxWeight.toStringAsFixed(0)} kg)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Slider(
              value: _maxWeight,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${_maxWeight.toStringAsFixed(0)} kg',
              onChanged: (v) => setState(() => _maxWeight = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(deliveryRepositoryProvider).updateDriverCapabilities(
            widget.driverId,
            serviceTypes: _selectedTypes.toList(),
            acceptsDeliveries: _acceptsDeliveries,
            maxDistance: _maxDistance,
            maxWeight: _maxWeight,
          );
      ref.invalidate(driverCapabilitiesProvider(widget.driverId));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorWithMessage(e.toString()))),
      );
    }
  }
}
