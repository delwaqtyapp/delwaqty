import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final search = ref.watch(adminOrdersSearchProvider);
    final query = AdminOrdersQuery(
      search: search.trim().isEmpty ? null : search.trim(),
      status: _status,
    );
    final ordersAsync = ref.watch(adminOrdersProvider(query));

    return Scaffold(
      appBar: AppBar(
        leading: MediaQuery.sizeOf(context).width < 1100
            ? const AdminMenuButton()
            : null,
        title: Text(l10n.orderManagement),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminOrdersProvider(query)),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 68,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _OrderQuickAction(
                  icon: Icons.delivery_dining_rounded,
                  label: l10n.adminDeliveries,
                  color: const Color(0xFFFF9500),
                  onTap: () => context.push('/admin/deliveries'),
                ),
                _OrderQuickAction(
                  icon: Icons.local_shipping_rounded,
                  label: l10n.adminDrivers,
                  color: const Color(0xFF007AFF),
                  onTap: () => context.push('/admin/drivers'),
                ),

                _OrderQuickAction(
                  icon: Icons.chat_bubble_rounded,
                  label: l10n.supportChat,
                  color: const Color(0xFF34C759),
                  onTap: () => context.push('/admin/support-chat'),
                ),
              ],
            ),
          ),
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
                      ref
                          .read(adminOrdersSearchProvider.notifier)
                          .update(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.filter,
                  icon: const Icon(Icons.filter_list_outlined),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.list_alt_rounded),
                              title: Text(l10n.all),
                              trailing: _status == null
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () {
                                setState(() => _status = null);
                                Navigator.pop(ctx);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.pending_outlined),
                              title: Text(l10n.pending),
                              trailing: _status == 'pending'
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () {
                                setState(() => _status = 'pending');
                                Navigator.pop(ctx);
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.local_shipping_outlined,
                              ),
                              title: Text(l10n.inTransit),
                              trailing: _status == 'delivering'
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () {
                                setState(() => _status = 'delivering');
                                Navigator.pop(ctx);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.check_circle_outline),
                              title: Text(l10n.delivered),
                              trailing: _status == 'delivered'
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () {
                                setState(() => _status = 'delivered');
                                Navigator.pop(ctx);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.cancel_outlined),
                              title: Text(l10n.cancelled),
                              trailing: _status == 'cancelled'
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () {
                                setState(() => _status = 'cancelled');
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(adminOrdersProvider(query)),
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
                          final adminService = ref.read(adminServiceProvider);
                          await adminService.updateOrderStatus(
                            order['id'] as String,
                            status,
                          );
                          ref.invalidate(adminOrdersProvider(query));
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
    final customerName = users?['full_name'] as String? ?? '';
    final merchantName = merchants?['name'] as String? ?? '';

    final statusColor = switch (status) {
      'delivered' => AppColors.successLight,
      'in_transit' => AppColors.infoLight,
      'pending' => AppColors.warningLight,
      'cancelled' => AppColors.errorLight,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };

    final statusLabel = switch (status) {
      'delivered' => l10n.delivered,
      'in_transit' => l10n.inTransit,
      'pending' => l10n.pending,
      'cancelled' => l10n.cancelled,
      _ => status,
    };

    // Stacked card: id + amount share the header (amount scales down),
    // customer/merchant get the full width, status on its own chip.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () =>
            _showOrderDetailsSheet(context, order, l10n, onStatusChanged),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.receipt_outlined,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      orderId.length > 8 ? orderId.substring(0, 8) : orderId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${l10n.currencySymbol} ${totalAmount.toStringAsFixed(2)}',
                        maxLines: 1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
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
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$customerName • $merchantName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsSheet(
    BuildContext context,
    Map<String, dynamic> order,
    AppLocalizations l10n,
    Function(String) onStatusChanged,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final orderId = order['id'] as String? ?? '';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? 'pending';
    final createdAt = order['created_at'] as String? ?? '';
    final users = order['users'] as Map<String, dynamic>?;
    final merchants = order['merchants'] as Map<String, dynamic>?;
    final customerName = users?['full_name'] as String? ?? '';
    final customerEmail = users?['email'] as String? ?? '';
    final merchantName = merchants?['name'] as String? ?? '';

    final statusColor = switch (status) {
      'delivered' => AppColors.successLight,
      'in_transit' => AppColors.infoLight,
      'pending' => AppColors.warningLight,
      'cancelled' => AppColors.errorLight,
      _ => cs.onSurfaceVariant,
    };

    final statusLabel = switch (status) {
      'delivered' => l10n.delivered,
      'in_transit' => l10n.inTransit,
      'pending' => l10n.pending,
      'cancelled' => l10n.cancelled,
      _ => status,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                orderId,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: l10n.copyCode,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: orderId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.copiedToClipboard),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (createdAt.isNotEmpty)
                          Text(
                            createdAt.split('.').first.replaceFirst('T', ' '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 20,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName.isNotEmpty
                                      ? customerName
                                      : l10n.customer,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (customerEmail.isNotEmpty)
                                  Text(
                                    customerEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 20,
                            color: AppColors.brandPurple,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              merchantName.isNotEmpty
                                  ? merchantName
                                  : l10n.merchant,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.total,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${l10n.currencySymbol} ${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.status,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (status != 'in_transit')
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                        ),
                        label: Text(l10n.markInTransit),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onStatusChanged('in_transit');
                        },
                      ),
                    ),
                  if (status != 'in_transit' && status != 'delivered')
                    const SizedBox(width: 8),
                  if (status != 'delivered')
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(l10n.markDelivered),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onStatusChanged('delivered');
                        },
                      ),
                    ),
                ],
              ),
              if (status != 'cancelled') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.cancel_outlined,
                      size: 18,
                      color: cs.error,
                    ),
                    label: Text(
                      l10n.cancelOrder,
                      style: TextStyle(color: cs.error),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onStatusChanged('cancelled');
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderQuickAction extends StatelessWidget {
  const _OrderQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
