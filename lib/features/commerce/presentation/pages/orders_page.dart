import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/order.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';

final _ordersFutureProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.getOrders();
});

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final ordersAsync = ref.watch(_ordersFutureProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myOrders)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_ordersFutureProvider),
        child: ordersAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: PremiumEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.noOrders,
                      message: l10n.noOrdersMessage,
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final canTrack =
                    order.status != OrderStatus.delivered &&
                    order.status != OrderStatus.cancelled;

                return AnimatedFadeIn(
                  delay: Duration(milliseconds: 80 * index),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: canTrack
                          ? () => context.push('/market/orders/${order.id}')
                          : null,
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
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _StatusChip(status: order.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${order.total.toStringAsFixed(0)} ${l10n.sar}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(order.createdAt),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => ListView(
            children: const [
              SizedBox(height: 16),
              SkeletonCard(),
              SkeletonCard(),
              SkeletonCard(),
            ],
          ),
          error: (e, _) => ErrorState(
            title: l10n.error,
            message: e.toString(),
            onRetry: () => ref.invalidate(_ordersFutureProvider),
            retryLabel: l10n.retry,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final (labelKey, color) = switch (status) {
      OrderStatus.pending => (l10n.pending, AppColors.warningLight),
      OrderStatus.confirmed => (l10n.confirmed, AppColors.orderConfirmed),
      OrderStatus.preparing => (l10n.preparing, AppColors.orderPreparing),
      OrderStatus.ready => (l10n.ready, AppColors.orderReady),
      OrderStatus.pickedUp => (l10n.pickedUp, AppColors.orderInTransit),
      OrderStatus.inTransit => (l10n.inTransit, AppColors.infoLight),
      OrderStatus.delivered => (l10n.delivered, AppColors.successLight),
      OrderStatus.cancelled => (l10n.cancelled, AppColors.errorLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        labelKey,
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
