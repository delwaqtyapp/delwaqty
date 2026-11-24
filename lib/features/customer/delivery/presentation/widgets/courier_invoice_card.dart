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
class CourierInvoiceCard extends ConsumerStatefulWidget {
  const CourierInvoiceCard({required this.state, super.key});

  final AskAnythingRideState state;

  @override
  ConsumerState<CourierInvoiceCard> createState() => _CourierInvoiceCardState();
}

class _CourierInvoiceCardState extends ConsumerState<CourierInvoiceCard> {
  /// The items whose decision RPCs are in flight; each item's buttons
  /// stay disabled until its own server answer lands (#213).
  final Set<String> _busyItemIds = {};

  AskAnythingRideState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final itemsAsync = ref.watch(courierInvoiceItemsProvider(state.rideId));

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
              data: (items) => _buildInvoice(context, l10n, cs, items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoice(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
    List<CourierInvoiceItem> items,
  ) {
    final approved = items
        .where((i) => i.isApproved)
        .fold<double>(0, (sum, i) => sum + i.price);
    final goods = state.shoppingFinished ? state.goodsTotal : approved;
    final fare = state.fare ?? 0;
    // The total is provisional until shopping is finished and no item
    // awaits a decision; never present it as the final bill before.
    final provisional =
        !state.shoppingFinished || items.any((i) => i.isPending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty)
          Text(
            l10n.itemStatusPending,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          )
        else
          ...items.map(
            (item) => InvoiceItemRow(
              item: item,
              busy: _busyItemIds.contains(item.id),
              onDecide: _canDecide(item)
                  ? (action) => _decide(item, action)
                  : null,
            ),
          ),
        const Divider(height: 24),
        InvoiceTotalRow(
          label: l10n.deliveryFeeLabel,
          amount: state.quoteLocked ? fare : null,
          pendingLabel: state.quoteLocked ? null : l10n.itemStatusPending,
        ),
        InvoiceTotalRow(label: l10n.goodsLabel, amount: goods),
        InvoiceTotalRow(
          label: provisional ? l10n.provisionalTotal : l10n.cashOnDeliveryTotal,
          amount: (state.quoteLocked ? fare : 0) + goods,
          emphasize: true,
        ),
      ],
    );
  }

  /// Decisions are only possible while shopping is open on a live ride;
  /// the server re-checks the same conditions.
  bool _canDecide(CourierInvoiceItem item) =>
      item.isPending &&
      !state.shoppingFinished &&
      (state.status == 'matched' || state.status == 'arrived') &&
      !_busyItemIds.contains(item.id);

  Future<void> _decide(CourierInvoiceItem item, String action) async {
    if (!_canDecide(item)) return;
    setState(() => _busyItemIds.add(item.id));
    try {
      await ref
          .read(deliveryRepositoryProvider)
          .decideCourierInvoiceItem(item.id, action);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(courierErrorText(context, e))));
      }
    } finally {
      if (mounted) setState(() => _busyItemIds.remove(item.id));
    }
  }
}

/// One invoice line: product, shop, quantity with a localized unit, the
/// receipt photo when the captain attached one, and the approval
/// actions while pending (#214).
class InvoiceItemRow extends StatelessWidget {
  const InvoiceItemRow({
    required this.item,
    required this.busy,
    this.onDecide,
    super.key,
  });

  final CourierInvoiceItem item;
  final bool busy;
  final void Function(String action)? onDecide;

  String _unitLabel(AppLocalizations l10n, String unit) => switch (unit) {
    'kilo' => l10n.unitKilo,
    'half' => l10n.unitHalf,
    'quarter' => l10n.unitQuarter,
    'piece' => l10n.unitPiece,
    'amount' => l10n.unitAmount,
    _ => unit,
  };

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
    final quantity = item.quantity;
    final unit = item.unit;
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
                '${item.price.toStringAsFixed(2)} ${l10n.egp}',
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
                  [
                    item.shopName,
                    if (quantity != null && unit != null)
                      '${quantity % 1 == 0 ? quantity.toInt() : quantity} × ${_unitLabel(l10n, unit)}'
                    else if (unit != null)
                      _unitLabel(l10n, unit),
                  ].join(' - '),
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
          if (_hasSafeReceipt) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showReceipt(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.viewReceipt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onDecide != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: busy ? null : () => onDecide!('approve'),
                    child: Text(l10n.approve),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => onDecide!('reject'),
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

  /// Render the receipt image only when it is an https URL on this
  /// project's Supabase storage host; anything else shows as plain text
  /// (security review, PR #45).
  bool get _hasSafeReceipt {
    final url = item.receiptPhotoUrl;
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.endsWith('.supabase.co');
  }

  void _showReceipt(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.receiptPhotoTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
          child: InteractiveViewer(
            child: Image.network(
              item.receiptPhotoUrl!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              errorBuilder: (context, _, _) =>
                  Center(child: Text(l10n.somethingWentWrong)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

/// One totals line; shared by the live invoice and the final receipt.
class InvoiceTotalRow extends StatelessWidget {
  const InvoiceTotalRow({
    required this.label,
    this.amount,
    this.pendingLabel,
    this.emphasize = false,
    super.key,
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
