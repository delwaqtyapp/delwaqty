import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/delivery/presentation/widgets/courier_invoice_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The final receipt of an ask-anything ride (436), shown once the ride
/// is terminal (#212): the agreed delivery price, every approved item,
/// the final goods total and the cash-on-delivery amount due.
///
/// A cancelled ride with goods in progress never shows an amount due:
/// settlement goes through the incident report, so the card presents
/// the record plus a note instead.
class CourierReceiptCard extends ConsumerWidget {
  const CourierReceiptCard({required this.state, super.key});

  final AskAnythingRideState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final itemsAsync = ref.watch(courierInvoiceItemsProvider(state.rideId));
    final cancelled = state.status == 'cancelled';

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
                    l10n.askAnythingReceiptTitle,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            itemsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.somethingWentWrong,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      courierInvoiceItemsProvider(state.rideId),
                    ),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
              data: (items) {
                final approved = items.where((i) => i.isApproved).toList();
                final goods = state.shoppingFinished
                    ? state.goodsTotal
                    : approved.fold<double>(0, (sum, i) => sum + i.price);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...approved.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.productName} - ${item.shopName}',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                            Text(
                              '${item.price.toStringAsFixed(2)} ${l10n.egp}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (approved.isNotEmpty) const Divider(height: 20),
                    InvoiceTotalRow(
                      label: l10n.deliveryFeeLabel,
                      amount: state.fare ?? 0,
                    ),
                    InvoiceTotalRow(label: l10n.goodsLabel, amount: goods),
                    if (cancelled) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.incidentSettlementNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ] else
                      InvoiceTotalRow(
                        label: l10n.cashOnDeliveryTotal,
                        amount: (state.fare ?? 0) + goods,
                        emphasize: true,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
