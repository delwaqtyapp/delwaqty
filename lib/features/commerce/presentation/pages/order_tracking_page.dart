import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/order.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';

final _orderFutureProvider = FutureProvider.family<Order?, String>((
  ref,
  orderId,
) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.getOrderById(orderId);
});

class OrderTrackingPage extends ConsumerStatefulWidget {
  const OrderTrackingPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends ConsumerState<OrderTrackingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final orderAsync = ref.watch(_orderFutureProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderTracking)),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return Center(child: Text(l10n.noData));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_orderFutureProvider(widget.orderId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TimelineSection(order: order, pulseAnimation: _pulseAnimation),
                const SizedBox(height: 24),
                _OrderDetailsCard(order: order),
                const SizedBox(height: 24),
                _EstimatedArrivalSection(order: order),
                const SizedBox(height: 24),
                _DriverSection(),
              ],
            ),
          );
        },
        loading: () => _buildSkeleton(context),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(l10n.error),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  ref.invalidate(_orderFutureProvider(widget.orderId));
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: index == 0 ? 280.0 : 120.0,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.order, required this.pulseAnimation});

  final Order order;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final steps = _buildSteps(l10n, order);
    final currentStatusIndex = _getCurrentStepIndex(order.status);

    return AnimatedFadeIn(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.orderTimeline,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(steps.length, (index) {
                final step = steps[index];
                final isCompleted = index < currentStatusIndex;
                final isCurrent = index == currentStatusIndex;
                final isPending = index > currentStatusIndex;
                final isLast = index == steps.length - 1;

                return _TimelineStep(
                  step: step,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isPending: isPending,
                  isLast: isLast,
                  colorScheme: colorScheme,
                  pulseAnimation: pulseAnimation,
                  textTheme: textTheme,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  List<_TimelineStepData> _buildSteps(AppLocalizations l10n, Order order) {
    return [
      _TimelineStepData(
        title: l10n.orderConfirmed,
        icon: Icons.check_circle_outline,
        filledIcon: Icons.check_circle,
        timestamp: order.confirmedAt,
      ),
      _TimelineStepData(
        title: l10n.preparing,
        icon: Icons.restaurant_outlined,
        filledIcon: Icons.restaurant,
        timestamp: order.preparingAt,
      ),
      _TimelineStepData(
        title: l10n.ready,
        icon: Icons.done_outline,
        filledIcon: Icons.done_all,
        timestamp: order.readyAt,
      ),
      _TimelineStepData(
        title: l10n.outForDelivery,
        icon: Icons.local_shipping_outlined,
        filledIcon: Icons.local_shipping,
      ),
      _TimelineStepData(
        title: l10n.delivered,
        icon: Icons.home_outlined,
        filledIcon: Icons.home,
        timestamp: order.deliveredAt,
      ),
    ];
  }

  int _getCurrentStepIndex(OrderStatus status) {
    return switch (status) {
      OrderStatus.confirmed => 0,
      OrderStatus.preparing => 1,
      OrderStatus.ready => 2,
      OrderStatus.pickedUp => 3,
      OrderStatus.inTransit => 3,
      OrderStatus.delivered => 4,
      OrderStatus.pending => -1,
      OrderStatus.cancelled => -1,
    };
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.isPending,
    required this.isLast,
    required this.colorScheme,
    required this.pulseAnimation,
    required this.textTheme,
  });

  final _TimelineStepData step;
  final bool isCompleted;
  final bool isCurrent;
  final bool isPending;
  final bool isLast;
  final ColorScheme colorScheme;
  final Animation<double> pulseAnimation;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final activeColor = colorScheme.primary;
    final pendingColor = colorScheme.outlineVariant;

    final circleColor = isCompleted
        ? activeColor
        : isCurrent
        ? activeColor
        : pendingColor;

    final iconColor = isCompleted || isCurrent ? Colors.white : pendingColor;

    final lineColor = isCompleted ? activeColor : pendingColor;

    final icon = isCompleted || isCurrent ? step.filledIcon : step.icon;

    Widget circle;
    if (isCurrent) {
      circle = AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: circleColor.withValues(
                alpha: 0.2 + (pulseAnimation.value * 0.3),
              ),
              shape: BoxShape.circle,
            ),
            child: child,
          );
        },
        child: Icon(icon, size: 20, color: iconColor),
      );
    } else {
      circle = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: iconColor),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              circle,
              if (!isLast)
                Expanded(child: Container(width: 2, color: lineColor)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: isCompleted || isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isPending
                          ? colorScheme.onSurface.withValues(alpha: 0.4)
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (step.timestamp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(step.timestamp!),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hour:$minute';
  }
}

class _TimelineStepData {
  const _TimelineStepData({
    required this.title,
    required this.icon,
    required this.filledIcon,
    this.timestamp,
  });

  final String title;
  final IconData icon;
  final IconData filledIcon;
  final DateTime? timestamp;
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.orderDetails,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                order.merchantName,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              const Divider(height: 32),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.productName}',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${item.totalPrice.toStringAsFixed(2)} ${l10n.sar}',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              _PriceRow(
                label: l10n.subtotal,
                value: '${order.subtotal.toStringAsFixed(2)} ${l10n.sar}',
                textTheme: textTheme,
              ),
              const SizedBox(height: 8),
              _PriceRow(
                label: l10n.deliveryFee,
                value: '${order.deliveryFee.toStringAsFixed(2)} ${l10n.sar}',
                textTheme: textTheme,
              ),
              const Divider(height: 24),
              _PriceRow(
                label: l10n.total,
                value: '${order.total.toStringAsFixed(2)} ${l10n.sar}',
                textTheme: textTheme,
                isBold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    required this.textTheme,
    this.isBold = false,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EstimatedArrivalSection extends StatelessWidget {
  const _EstimatedArrivalSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.timer_outlined, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.estimatedArrival,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '25 ${l10n.minutes}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 300),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.person, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mohamed A.',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '••• 4521',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:+966500000000')),
                      icon: const Icon(Icons.call, size: 18),
                      label: Text(l10n.callDriver),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.chatDriver)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(l10n.chatDriver),
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
}
