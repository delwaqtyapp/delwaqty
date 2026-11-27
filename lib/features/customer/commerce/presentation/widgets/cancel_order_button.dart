import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The customer may cancel only before the merchant starts preparing. The
/// server (cancel_order) is the authority and also lets an order be cancelled
/// later through support; this is the self-service window shown in the app.
bool canCustomerCancel(OrderStatus status) =>
    status == OrderStatus.pending || status == OrderStatus.confirmed;

/// Stable codes stored in orders.cancelled_reason; shown localized on read.
const cancelReasonCodes = ['changed_mind', 'wrong_address', 'other'];

String? localizedCancelReason(AppLocalizations l10n, String? code) =>
    switch (code) {
      'changed_mind' => l10n.cancelReasonChangedMind,
      'wrong_address' => l10n.cancelReasonWrongAddress,
      'other' => l10n.cancelReasonOther,
      _ => code,
    };

enum CancelOrderError { outForDelivery, notCancellable, forbidden, other }

/// `cancel_order` answers `{ok:false, code}`; the data source rethrows it as
/// "cancel_order refused: CODE".
CancelOrderError cancelOrderErrorOf(Object error) {
  final text = error.toString();
  if (text.contains('OUT_FOR_DELIVERY')) return CancelOrderError.outForDelivery;
  if (text.contains('NOT_CANCELLABLE')) return CancelOrderError.notCancellable;
  if (text.contains('FORBIDDEN') || text.contains('UNAUTHENTICATED')) {
    return CancelOrderError.forbidden;
  }
  return CancelOrderError.other;
}

class CancelOrderButton extends ConsumerStatefulWidget {
  const CancelOrderButton({
    super.key,
    required this.order,
    required this.onCancelled,
  });

  final Order order;
  final VoidCallback onCancelled;

  @override
  ConsumerState<CancelOrderButton> createState() => _CancelOrderButtonState();
}

class _CancelOrderButtonState extends ConsumerState<CancelOrderButton> {
  bool _busy = false;

  Future<String?> _askReason(AppLocalizations l10n) {
    const reasons = cancelReasonCodes;
    var selected = reasons.first;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.cancelOrder),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.cancelOrderConfirmBody),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (v) => setLocal(() => selected = v ?? selected),
                  child: Column(
                    children: [
                      for (final r in reasons)
                        RadioListTile<String>(
                          value: r,
                          title: Text(localizedCancelReason(l10n, r) ?? r),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.cancelOrderLimitNote,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancelOrderKeep),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(selected),
              child: Text(l10n.cancelOrder),
            ),
          ],
        ),
      ),
    );
  }

  String _errorText(AppLocalizations l10n, Object e) =>
      switch (cancelOrderErrorOf(e)) {
        CancelOrderError.outForDelivery => l10n.cancelOrderOutForDelivery,
        CancelOrderError.notCancellable => l10n.cancelOrderNotAllowed,
        CancelOrderError.forbidden => l10n.cancelOrderNotAllowed,
        CancelOrderError.other => l10n.cancelOrderFailed,
      };

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final reason = await _askReason(l10n);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .cancelOrder(orderId: widget.order.id, reason: reason);
      if (!mounted) return;
      context.showAppSnackBar(l10n.cancelOrderDone);
      widget.onCancelled();
    } catch (e) {
      if (mounted) context.showAppSnackBar(_errorText(l10n, e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!canCustomerCancel(widget.order.status)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _cancel,
        icon: const Icon(Icons.cancel_outlined),
        label: Text(l10n.cancelOrder),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
