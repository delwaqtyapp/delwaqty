import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_invoice_item.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The live itemized invoice of an ask-anything ride (436): the captain
/// records each item at the shop with its real price and the customer
/// approves or rejects it before it is bought. Rejected items are
/// cancelled by the captain at the shop. Final charge = the agreed
/// delivery price + the approved items total, paid in cash on delivery.
class CourierInvoiceCard extends ConsumerWidget {
  const CourierInvoiceCard({required this.state, super.key});

  final AskAnythingRideState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = ref.watch(courierInvoiceItemsProvider(state.rideId)).value;

    final approved = (items ?? [])
        .where((i) => i.isApproved)
        .fold<double>(0, (sum, i) => sum + i.price);
    final goods = state.shoppingFinished ? state.goodsTotal : approved;
    final fare = state.fare ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.liveInvoiceTitle,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.approveItemHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            if (items == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (items.isEmpty)
              Text(
                l10n.itemStatusPending,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else
              ...items.map(
                (item) => _InvoiceItemRow(
                  item: item,
                  onDecide: item.isPending
                      ? (action) => _decide(context, ref, item, action)
                      : null,
                ),
              ),
            const Divider(height: 24),
            _TotalRow(
              label: l10n.deliveryFeeLabel,
              amount: state.quoteLocked ? fare : null,
              pendingLabel: state.quoteLocked ? null : l10n.itemStatusPending,
            ),
            _TotalRow(label: l10n.goodsLabel, amount: goods),
            _TotalRow(
              label: l10n.cashOnDeliveryTotal,
              amount: (state.quoteLocked ? fare : 0) + goods,
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    CourierInvoiceItem item,
    String action,
  ) async {
    try {
      await ref
          .read(deliveryRepositoryProvider)
          .decideCourierInvoiceItem(item.id, action);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    }
  }
}

class _InvoiceItemRow extends StatelessWidget {
  const _InvoiceItemRow({required this.item, this.onDecide});

  final CourierInvoiceItem item;
  final void Function(String action)? onDecide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (label, color) = switch (item.status) {
      'approved' => (l10n.itemStatusApproved, cs.primary),
      'rejected' => (l10n.itemStatusRejected, cs.error),
      'cancelled' => (l10n.itemStatusCancelled, cs.onSurfaceVariant),
      _ => (l10n.itemStatusPending, cs.tertiary),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    decoration: item.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              Text(
                '${item.price} ${l10n.egp}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.shopName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (onDecide == null)
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
            ],
          ),
          if (onDecide != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => onDecide!('approve'),
                    child: Text(l10n.approve),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onDecide!('reject'),
                    child: Text(l10n.reject),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    this.amount,
    this.pendingLabel,
    this.emphasize = false,
  });

  final String label;
  final double? amount;
  final String? pendingLabel;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = emphasize
        ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)
        : AppTextStyles.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            amount != null
                ? '${amount!.toStringAsFixed(2)} ${l10n.egp}'
                : pendingLabel ?? '',
            style: style,
          ),
        ],
      ),
    );
  }
}
