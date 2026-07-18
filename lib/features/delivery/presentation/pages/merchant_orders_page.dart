import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

enum _OrderFilter { all, active, completed }

class MerchantOrdersPage extends ConsumerStatefulWidget {
  const MerchantOrdersPage({required this.merchantId, super.key});
  final String merchantId;

  @override
  ConsumerState<MerchantOrdersPage> createState() => _MerchantOrdersPageState();
}

class _MerchantOrdersPageState extends ConsumerState<MerchantOrdersPage> {
  _OrderFilter _filter = _OrderFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final userId = authState is AuthAuthenticated ? authState.user.id : null;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.merchantDashboard)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }

    final statusFilter = _statusForFilter(_filter);
    final deliveriesAsync = ref.watch(merchantDeliveriesProvider((
      merchantId: widget.merchantId,
      status: statusFilter,
    )));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.merchantDashboard)),
      body: Column(
        children: [
          _FilterTabs(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: deliveriesAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  ShimmerCard(height: 120),
                  SizedBox(height: 12),
                  ShimmerCard(height: 120),
                  SizedBox(height: 12),
                  ShimmerCard(height: 120),
                ],
              ),
              error: (e, _) => Center(
                child: Text(l10n.errorWithMessage(e.toString())),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(l10n.noData,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                )),
                      ],
                    ),
                  );
                }
                final grouped = _groupByStatus(orders);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(merchantDeliveriesProvider((
                      merchantId: widget.merchantId,
                      status: statusFilter,
                    )));
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in grouped.entries) ...[
                        AnimatedFadeIn(
                          child: _StatusHeader(status: entry.key),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < entry.value.length; i++)
                          AnimatedFadeIn(
                            delay: Duration(milliseconds: 50 * i),
                            child: _OrderCard(
                              order: entry.value[i],
                              onReadyForDispatch: () =>
                                  _readyForDispatch(entry.value[i]),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _statusForFilter(_OrderFilter filter) {
    switch (filter) {
      case _OrderFilter.all:
        return null;
      case _OrderFilter.active:
        return 'pending';
      case _OrderFilter.completed:
        return 'delivered';
    }
  }

  Map<String, List<DeliveryOrder>> _groupByStatus(List<DeliveryOrder> orders) {
    final map = <String, List<DeliveryOrder>>{};
    for (final order in orders) {
      final key = order.status;
      map.putIfAbsent(key, () => []).add(order);
    }
    return map;
  }

  Future<void> _readyForDispatch(DeliveryOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(deliveryRepositoryProvider)
          .merchantReadyForDispatch(order.id, widget.merchantId);
      ref.invalidate(merchantDeliveriesProvider((
        merchantId: widget.merchantId,
        status: _statusForFilter(_filter),
      )));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorWithMessage(e.toString()))),
      );
    }
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onChanged});
  final _OrderFilter selected;
  final ValueChanged<_OrderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<_OrderFilter>(
      segments: [
        ButtonSegment(value: _OrderFilter.all, label: Text(l10n.viewAll)),
        ButtonSegment(value: _OrderFilter.active, label: Text(l10n.orders)),
        ButtonSegment(value: _OrderFilter.completed, label: Text(l10n.orderHistory)),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      _label(l10n, status),
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }

  String _label(AppLocalizations l10n, String status) {
    switch (status) {
      case 'pending':
        return l10n.orderPlaced;
      case 'preparing':
        return l10n.loading;
      case 'ready':
        return l10n.confirm;
      case 'dispatching':
        return l10n.waitingForAcceptance;
      case 'delivering':
        return l10n.deliveryTime;
      case 'delivered':
        return l10n.orderHistory;
      case 'cancelled':
        return l10n.cancel;
      default:
        return status;
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onReadyForDispatch});
  final DeliveryOrder order;
  final VoidCallback onReadyForDispatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final elapsed = order.createdAt != null
        ? DateTime.now().difference(order.createdAt!)
        : Duration.zero;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length)}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            if (order.itemsSummary != null)
              Text(order.itemsSummary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.dropoffAddress.isNotEmpty
                        ? order.dropoffAddress
                        : l10n.notSet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatElapsed(elapsed),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (order.status == 'ready')
                  FilledButton.tonal(
                    onPressed: onReadyForDispatch,
                    child: Text(l10n.goOnline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label) = _style(status);
    return Chip(
      label: Text(label, style: theme.textTheme.labelSmall),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  (Color, String) _style(String status) {
    switch (status) {
      case 'pending':
        return (Colors.orange, 'Pending');
      case 'preparing':
        return (Colors.blue, 'Preparing');
      case 'ready':
        return (Colors.green, 'Ready');
      case 'dispatching':
        return (Colors.purple, 'Dispatching');
      case 'delivering':
        return (Colors.teal, 'Delivering');
      case 'delivered':
        return (Colors.green, 'Delivered');
      case 'cancelled':
        return (Colors.red, 'Cancelled');
      default:
        return (Colors.grey, status);
    }
  }
}
