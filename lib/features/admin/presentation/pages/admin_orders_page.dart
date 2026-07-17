import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_service.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';

class AdminOrdersPage extends ConsumerWidget {
  const AdminOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminOrdersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search orders...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      ref.invalidate(adminOrdersProvider);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list_outlined),
                  onPressed: () {},
                  tooltip: 'Filter Orders',
                ),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(child: Text('No orders found'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderTile(
                      order: order,
                      onStatusChanged: (status) async {
                        final adminService = ref.read(adminServiceProvider);
                        await adminService.updateOrderStatus(
                          order['id'] as String,
                          status,
                        );
                        ref.invalidate(adminOrdersProvider);
                      },
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

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onStatusChanged});

  final Map<String, dynamic> order;
  final Function(String) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderId = order['id'] as String? ?? '';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? 'pending';
    final users = order['users'] as Map<String, dynamic>?;
    final merchants = order['merchants'] as Map<String, dynamic>?;
    final customerName = users?['name'] as String? ?? 'Unknown';
    final merchantName = merchants?['name'] as String? ?? 'Unknown';

    final statusColor = switch (status) {
      'delivered' => Colors.green,
      'in_transit' => Colors.blue,
      'pending' => Colors.orange,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(Icons.receipt_outlined, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Text(
              orderId.length > 8 ? orderId.substring(0, 8) : orderId,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              'SAR ${totalAmount.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(child: Text('$customerName · $merchantName')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => onStatusChanged(value),
          itemBuilder: (context) => [
            if (status != 'in_transit')
              const PopupMenuItem(
                value: 'in_transit',
                child: Text('Mark In Transit'),
              ),
            if (status != 'delivered')
              const PopupMenuItem(
                value: 'delivered',
                child: Text('Mark Delivered'),
              ),
            if (status != 'cancelled')
              const PopupMenuItem(
                value: 'cancelled',
                child: Text(
                  'Cancel Order',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
