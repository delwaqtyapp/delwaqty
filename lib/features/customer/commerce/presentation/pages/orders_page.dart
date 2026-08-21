import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

final _ordersFutureProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.getOrders();
});

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(_ordersFutureProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myOrders)),
      body: GradientBackground(
        child: RefreshIndicator(
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final canTrack =
                      order.status != OrderStatus.delivered &&
                      order.status != OrderStatus.cancelled;

                  return AnimatedFadeIn(
                    delay: Duration(milliseconds: 80 * index),
                    child: _OrderCard(
                      order: order,
                      canTrack: canTrack,
                      onTap: canTrack
                          ? () => context.push('/market/orders/${order.id}')
                          : null,
                    ),
                  );
                },
              );
            },
            loading: () => ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 16),
                _OrderSkeletonCard(),
                _OrderSkeletonCard(),
                _OrderSkeletonCard(),
              ],
            ),
            error: (e, _) => ListView(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.error,
                    message: e.toString(),
                    actionLabel: l10n.retry,
                    onAction: () => ref.invalidate(_ordersFutureProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.canTrack,
    this.onTap,
  });

  final Order order;
  final bool canTrack;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final statusColor = _statusColor(order.status);
    final statusLabel = _statusLabel(order.status, l10n);
    final itemCount = order.items.isEmpty ? 0 : order.items.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PremiumCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        color: colorScheme.surfaceContainerLowest,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusTile(
                  color: statusColor,
                  icon: _statusIcon(order.status),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.merchantName.isNotEmpty
                        ? order.merchantName
                        : 'Order #${order.id.substring(order.id.length - 6)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (itemCount > 0) ...[
                  Text(
                    l10n.itemCount(itemCount),
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
                ],
                Text(
                  '${order.total.toStringAsFixed(0)} ${l10n.currencySymbol}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.brandPurple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (canTrack)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.trackYourOrder,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.brandPurple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.brandPurple,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(order.createdAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  static Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.orderPending;
      case OrderStatus.confirmed:
        return AppColors.orderConfirmed;
      case OrderStatus.preparing:
        return AppColors.orderPreparing;
      case OrderStatus.ready:
        return AppColors.orderReady;
      case OrderStatus.pickedUp:
        return AppColors.orderInTransit;
      case OrderStatus.inTransit:
        return AppColors.infoLight;
      case OrderStatus.delivered:
        return AppColors.successLight;
      case OrderStatus.cancelled:
        return AppColors.errorLight;
    }
  }

  static IconData _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing:
        return Icons.ramen_dining_outlined;
      case OrderStatus.ready:
        return Icons.shopping_bag_outlined;
      case OrderStatus.pickedUp:
        return Icons.inventory_2_outlined;
      case OrderStatus.inTransit:
        return Icons.local_shipping_outlined;
      case OrderStatus.delivered:
        return Icons.verified_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  static String _statusLabel(OrderStatus status, AppLocalizations l10n) {
    switch (status) {
      case OrderStatus.pending:
        return l10n.pending;
      case OrderStatus.confirmed:
        return l10n.confirmed;
      case OrderStatus.preparing:
        return l10n.preparing;
      case OrderStatus.ready:
        return l10n.ready;
      case OrderStatus.pickedUp:
        return l10n.pickedUp;
      case OrderStatus.inTransit:
        return l10n.inTransit;
      case OrderStatus.delivered:
        return l10n.delivered;
      case OrderStatus.cancelled:
        return l10n.cancelled;
    }
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.08)],
        ),
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusFull,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSkeletonCard extends StatelessWidget {
  const _OrderSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: 132,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: AppSpacing.borderRadiusCard,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: AppSpacing.borderRadiusLg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest,
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 64,
                  height: 22,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: AppSpacing.borderRadiusFull,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 11,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56,
                  height: 11,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 64,
                  height: 11,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
