import 'package:delwaqty/shared/widgets/delivery_handoff_button.dart';
import 'package:delwaqty/core/utils/rpc_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_order.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/services/realtime/realtime_channel_constants.dart';
import 'package:delwaqty/services/realtime/realtime_service.dart';

final _merchantIdProvider = providerMerchantIdProvider;

final _ordersFilterProvider = StateProvider<String?>((ref) => null);

final _ordersProvider = FutureProvider<List<MerchantOrder>>((ref) async {
  final repo = ref.watch(merchantDashboardRepositoryProvider);
  final merchantId = await ref.watch(_merchantIdProvider.future);
  final status = ref.watch(_ordersFilterProvider);
  return repo.getMerchantOrders(merchantId, status: status);
});

class MerchantOrdersPage extends ConsumerStatefulWidget {
  const MerchantOrdersPage({super.key});

  @override
  ConsumerState<MerchantOrdersPage> createState() => _MerchantOrdersPageState();
}

class _MerchantOrdersPageState extends ConsumerState<MerchantOrdersPage> {
  RealtimeService? _realtimeService;
  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  Future<void> _subscribeRealtime() async {
    try {
      final merchantId = await ref.read(providerMerchantIdProvider.future);
      if (!mounted || merchantId.isEmpty) return;
      final realtime = ref.read(realtimeServiceProvider);
      _realtimeService = realtime;
      realtime.subscribe(
        channelName: RealtimeChannels.providerOrders,
        opts: [
          RealtimeChannelFilter(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'merchant_id',
              value: merchantId,
            ),
            callback: (_) => ref.invalidate(_ordersProvider),
          ),
        ],
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _realtimeService?.unsubscribe(RealtimeChannels.providerOrders);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(_ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orders),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
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
                itemBuilder: (_, _) => const Padding(
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _OrderCard(
                          order: order,
                          onDispatchDriver: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.hideCurrentSnackBar();
                            try {
                              final result = checkedRpcResult(
                                await Supabase.instance.client.rpc(
                                  'merchant_dispatch_order_driver',
                                  params: {'p_order_id': order.id},
                                ),
                                onFailure: Exception.new,
                              );
                              final dispatch = result['dispatch'];
                              final noDrivers =
                                  dispatch is Map &&
                                  dispatch['reason'] == 'no_drivers_available';
                              ref.invalidate(_ordersProvider);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    noDrivers
                                        ? l10n.noDriversFound
                                        : l10n.driverDispatchedSuccess,
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(appErrorText(context, e)),
                                  ),
                                );
                              }
                            }
                          },
                          onStatusChanged: (status) async {
                            final repo = ref.read(
                              merchantDashboardRepositoryProvider,
                            );
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.hideCurrentSnackBar();
                            try {
                              await repo.updateOrderStatus(order.id, status);
                              ref.invalidate(_ordersProvider);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n.updatedSuccessfully),
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(appErrorText(context, e)),
                                  ),
                                );
                              }
                            }
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
      MapEntry('confirmed', l10n.confirmed),
      MapEntry('preparing', l10n.preparing),
      MapEntry('ready', l10n.ready),
      MapEntry('delivering', l10n.inTransit),
      MapEntry('delivered', l10n.delivered),
      MapEntry('cancelled', l10n.cancelled),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
    required this.onDispatchDriver,
  });

  final MerchantOrder order;
  final Function(String) onStatusChanged;
  final VoidCallback onDispatchDriver;

  Future<void> _callCustomer(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsappCustomer(String phone) async {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('01') && digits.length == 11) {
      digits = '2$digits';
    }
    if (digits.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final statusColor = switch (order.status) {
      'delivered' => AppColors.successLight,
      'delivering' => Colors.indigo,
      'ready' => AppColors.orderReady,
      'preparing' => AppColors.infoLight,
      'confirmed' || 'accepted' => Colors.teal,
      'pending' => AppColors.warningLight,
      'cancelled' => AppColors.errorLight,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    final statusLabel = switch (order.status) {
      'pending' => l10n.pending,
      'confirmed' || 'accepted' => l10n.accepted,
      'preparing' => l10n.preparing,
      'ready' => l10n.ready,
      'delivering' => l10n.startOrderDelivery,
      'delivered' => l10n.delivered,
      'cancelled' => l10n.cancelled,
      _ => l10n.pending,
    };

    final itemsSummary = order.items
        .map(
          (item) =>
              '${item.quantity}x ${item.productName}${item.modifiers.isNotEmpty ? ' (${item.modifiers.join(', ')})' : ''}',
        )
        .join(', ');
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm')
        .format(order.createdAt.toLocal());
    final deliveryAddress = order.deliveryAddress?.trim() ?? '';
    final notes = order.notes?.trim() ?? '';
    final customerPhone = order.customerPhone?.trim() ?? '';
    final canDispatchDriver = const {
      'confirmed',
      'accepted',
      'preparing',
      'ready',
    }.contains(order.status);

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName ?? l10n.customer,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (customerPhone.isNotEmpty) ...[
                    IconButton(
                      tooltip: l10n.callCustomer,
                      icon: const Icon(Icons.phone_outlined, size: 20),
                      onPressed: () => _callCustomer(customerPhone),
                    ),
                    IconButton(
                      tooltip: l10n.whatsappCustomer,
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      onPressed: () => _whatsappCustomer(customerPhone),
                    ),
                  ],
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
              ),
              if (deliveryAddress.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${l10n.orderDeliveryAddress}: $deliveryAddress',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${l10n.orderSpecialNotes}: $notes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (canDispatchDriver)
                DeliveryHandoffButton(orderId: order.id, pickup: true),
              if (canDispatchDriver) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: onDispatchDriver,
                    icon: const Icon(Icons.delivery_dining_rounded, size: 18),
                    label: Text(l10n.dispatchDeliveryDriver),
                  ),
                ),
              ],
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
                      // The lifecycle is pending -> confirmed -> preparing
                      // -> ready -> delivering -> delivered. Jumping
                      // straight to 'preparing' skipped 'confirmed',
                      // which the DB CHECK allows and the filter chips
                      // expect.
                      onPressed: () => onStatusChanged('confirmed'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: l10n.reject,
                      color: theme.colorScheme.error,
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dlgCtx) => AlertDialog(
                            title: Text(l10n.cancelOrder),
                            content: Text(l10n.areYouSure),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dlgCtx).pop(false),
                                child: Text(l10n.no),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(dlgCtx).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(dlgCtx)
                                      .colorScheme
                                      .error,
                                ),
                                child: Text(l10n.yes),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          onStatusChanged('cancelled');
                        }
                      },
                    ),
                  ] else if (order.status == 'confirmed' ||
                      order.status == 'accepted') ...[
                    _ActionButton(
                      label: l10n.startPreparing,
                      color: AppColors.orderPreparing,
                      onPressed: () => onStatusChanged('preparing'),
                    ),
                  ] else if (order.status == 'preparing') ...[
                    _ActionButton(
                      label: l10n.markReady,
                      color: AppColors.orderReady,
                      onPressed: () => onStatusChanged('ready'),
                    ),
                  ] else if (order.status == 'ready') ...[
                    _ActionButton(
                      label: l10n.startOrderDelivery,
                      color: Colors.indigo,
                      onPressed: () => onStatusChanged('delivering'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: l10n.markDelivered,
                      color: AppColors.successLight,
                      onPressed: () => onStatusChanged('delivered'),
                    ),
                  ] else if (order.status == 'delivering') ...[
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
