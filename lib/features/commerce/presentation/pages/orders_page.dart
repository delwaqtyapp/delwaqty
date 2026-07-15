import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/order.dart';

final _ordersFutureProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.getOrders();
});

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(_ordersFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.merchantName.isNotEmpty
                                  ? order.merchantName
                                  : 'Order #${order.id.substring(order.id.length - 6)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _StatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${order.items.length} item(s) · ${order.total.toStringAsFixed(0)} SAR',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OrderStatus.pending => ('Pending', Colors.orange),
      OrderStatus.confirmed => ('Confirmed', Colors.blue),
      OrderStatus.preparing => ('Preparing', Colors.purple),
      OrderStatus.ready => ('Ready', Colors.teal),
      OrderStatus.pickedUp => ('Picked Up', Colors.indigo),
      OrderStatus.inTransit => ('In Transit', Colors.cyan),
      OrderStatus.delivered => ('Delivered', Colors.green),
      OrderStatus.cancelled => ('Cancelled', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
