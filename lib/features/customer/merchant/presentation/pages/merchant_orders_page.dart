import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/merchant/merchant_module.dart';
import 'package:delwaqty/features/customer/merchant/domain/entities/merchant_order.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';

final _merchantIdProvider = Provider<String>((_) => 'current-merchant-id');

final _ordersFilterProvider = StateProvider<String?>((ref) => null);

final _ordersProvider = FutureProvider<List<MerchantOrder>>((ref) async {
  final repo = ref.watch(merchantDashboardRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  final status = ref.watch(_ordersFilterProvider);
  return repo.getMerchantOrders(merchantId, status: status);
});

class MerchantOrdersPage extends ConsumerStatefulWidget {
  const MerchantOrdersPage({super.key});

  @override
  ConsumerState<MerchantOrdersPage> createState() =>
      _MerchantOrdersPageState();
}

class _MerchantOrdersPageState extends ConsumerState<MerchantOrdersPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(_ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orders),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_ordersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(ref, l10n),
          Expanded(
            child: ordersAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ShimmerCard(height: 100),
                ),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_ordersProvider),
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return Center(
                    child: PremiumEmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: l10n.noOrdersFound,
                      message: l10n.noOrdersFound,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_ordersProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _OrderCard(
                          order: order,
                          onStatusChanged: (status) async {
                            final repo = ref.read(
                              merchantDashboardRepositoryProvider,
                            );
                            await repo.updateOrderStatus(order.id, status);
                            ref.invalidate(_ordersProvider);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref, AppLocalizations l10n) {
    final currentFilter = ref.watch(_ordersFilterProvider);
    final filters = <MapEntry<String?, String?>>[
      MapEntry(null, l10n.all),
      MapEntry('pending', l10n.pending),
      MapEntry('preparing', l10n.preparing),
      MapEntry('ready', l10n.ready),
      MapEntry('delivered', l10n.delivered),
      MapEntry('cancelled', l10n.cancelled),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = currentFilter == filter.key;
          return FilterChip(
            label: Text(filter.value ?? ''),
            selected: isSelected,
            onSelected: (_) {
              ref.read(_ordersFilterProvider.notifier).state = filter.key;
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onStatusChanged,
  });

  final MerchantOrder order;
  final Function(String) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final statusColor = switch (order.status) {
      'delivered' => AppColors.successLight,
      'ready' => AppColors.orderReady,
      'preparing' => AppColors.infoLight,
      'pending' => AppColors.warningLight,
      'cancelled' => AppColors.errorLight,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    final statusLabel = switch (order.status) {
      'pending' => l10n.pending,
      'accepted' => l10n.accepted,
      'preparing' => l10n.preparing,
      'ready' => l10n.ready,
      'delivered' => l10n.delivered,
      'cancelled' => l10n.cancelled,
      _ => order.status,
    };

    final itemsSummary = order.items
        .map((item) => '${item.quantity}x ${item.productName}')
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.customerName ?? l10n.customer,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
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
              const SizedBox(height: 8),
              Text(
                itemsSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${l10n.currencySymbol} ${order.totalAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (order.status == 'pending') ...[
                    _ActionButton(
                      label: l10n.accept,
                      color: AppColors.successLight,
                      onPressed: () => onStatusChanged('preparing'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: l10n.reject,
                      color: theme.colorScheme.error,
                      onPressed: () => onStatusChanged('cancelled'),
                    ),
                  ] else if (order.status == 'preparing') ...[
                    _ActionButton(
                      label: l10n.markReady,
                      color: AppColors.orderReady,
                      onPressed: () => onStatusChanged('ready'),
                    ),
                  ] else if (order.status == 'ready') ...[
                    _ActionButton(
                      label: l10n.markDelivered,
                      color: AppColors.successLight,
                      onPressed: () => onStatusChanged('delivered'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
