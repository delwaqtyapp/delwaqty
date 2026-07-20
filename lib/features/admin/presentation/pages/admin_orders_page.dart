import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminOrdersPage extends ConsumerWidget {
  const AdminOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderManagement),
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
                      hintText: l10n.searchOrders,
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
                  tooltip: l10n.filterOrders,
                ),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(
                child: AppLoaderCircular(),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(adminOrdersProvider),
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: l10n.noOrdersFound,
                    message: l10n.noOrdersFound,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: _OrderTile(
                        order: order,
                        l10n: l10n,
                        onStatusChanged: (status) async {
                          final adminService =
                              ref.read(adminServiceProvider);
                          await adminService.updateOrderStatus(
                            order['id'] as String,
                            status,
                          );
                          ref.invalidate(adminOrdersProvider);
                        },
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

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.l10n,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> order;
  final AppLocalizations l10n;
  final Function(String) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderId = order['id'] as String? ?? '';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? 'pending';
    final users = order['users'] as Map<String, dynamic>?;
    final merchants = order['merchants'] as Map<String, dynamic>?;
    final customerName = users?['name'] as String? ?? '';
    final merchantName = merchants?['name'] as String? ?? '';

    final statusColor = switch (status) {
      'delivered' => Colors.green,
      'in_transit' => Colors.blue,
      'pending' => Colors.orange,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };

    final statusLabel = switch (status) {
      'delivered' => l10n.delivered,
      'in_transit' => l10n.inTransit,
      'pending' => l10n.pending,
      'cancelled' => l10n.cancelled,
      _ => status,
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
              '${l10n.currencySymbol} ${totalAmount.toStringAsFixed(2)}',
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
                statusLabel,
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
              PopupMenuItem(
                value: 'in_transit',
                child: Text(l10n.markInTransit),
              ),
            if (status != 'delivered')
              PopupMenuItem(
                value: 'delivered',
                child: Text(l10n.markDelivered),
              ),
            if (status != 'cancelled')
              PopupMenuItem(
                value: 'cancelled',
                child: Text(
                  l10n.cancelOrder,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
