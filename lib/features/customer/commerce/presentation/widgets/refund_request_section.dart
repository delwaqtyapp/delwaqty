import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/customer/commerce/data/refund_requests_api.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final refundRequestForOrderProvider =
    FutureProvider.family<RefundRequest?, String>(
      (ref, orderId) => RefundRequestsApi().latestForOrder(orderId),
    );

/// Whether the customer can ask for a refund on this order right now. The
/// server re-checks everything (delivered, paid, 14-day window).
bool canRequestRefund(Order order, RefundRequest? latest) {
  if (order.status != OrderStatus.delivered) return false;
  if (order.paymentStatus != PaymentStatus.paid) return false;
  if (DateTime.now().difference(order.createdAt) > const Duration(days: 14)) {
    return false;
  }
  return latest == null || latest.status == 'rejected';
}

String refundReasonLabel(AppLocalizations l10n, String code) => switch (code) {
  'missing_item' => l10n.refundReasonMissingItem,
  'wrong_item' => l10n.refundReasonWrongItem,
  'quality' => l10n.refundReasonQuality,
  'late' => l10n.refundReasonLate,
  'damaged' => l10n.refundReasonDamaged,
  _ => l10n.refundReasonOther,
};

String refundErrorText(AppLocalizations l10n, Object e) {
  final code = e is RefundException ? e.code : '';
  return switch (code) {
    'ALREADY_REQUESTED' => l10n.refundErrorAlready,
    'WINDOW_EXPIRED' => l10n.refundErrorWindow,
    'NOT_DELIVERED' ||
    'NOT_REFUNDABLE' ||
    'TOO_MANY_REQUESTS' => l10n.refundErrorNotEligible,
    _ => l10n.refundErrorGeneric,
  };
}

class RefundRequestSection extends ConsumerStatefulWidget {
  const RefundRequestSection({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<RefundRequestSection> createState() =>
      _RefundRequestSectionState();
}

class _RefundRequestSectionState extends ConsumerState<RefundRequestSection> {
  bool _busy = false;

  Future<({String code, String? details})?> _ask(AppLocalizations l10n) {
    var code = refundReasonCodes.first;
    final details = TextEditingController();
    return showDialog<({String code, String? details})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.refundRequestTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioGroup<String>(
                  groupValue: code,
                  onChanged: (v) => setLocal(() => code = v ?? code),
                  child: Column(
                    children: [
                      for (final c in refundReasonCodes)
                        RadioListTile<String>(
                          value: c,
                          title: Text(refundReasonLabel(l10n, c)),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                TextField(
                  controller: details,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: l10n.refundDetailsHint),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx)
                      .pop((code: code, details: details.text.trim())),
              child: Text(l10n.refundSubmit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final picked = await _ask(l10n);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await RefundRequestsApi().request(
        orderId: widget.order.id,
        reasonCode: picked.code,
        details: picked.details,
      );
      ref.invalidate(refundRequestForOrderProvider(widget.order.id));
      if (mounted) context.showAppSnackBar(l10n.refundRequestSent);
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(refundErrorText(l10n, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = widget.order;
    if (order.status != OrderStatus.delivered) return const SizedBox.shrink();
    final latest = ref
        .watch(refundRequestForOrderProvider(order.id))
        .asData
        ?.value;
    final lines = <Widget>[];
    if (latest != null) {
      final text = switch (latest.status) {
        'pending' => l10n.refundStatusPending,
        'approved' =>
          '${l10n.refundStatusApproved} ${(latest.approvedAmount ?? latest.amount).toStringAsFixed(2)}',
        _ =>
          '${l10n.refundStatusRejected}${(latest.reviewNote ?? '').isEmpty ? '' : ': ${latest.reviewNote}'}',
      };
      lines.add(
        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_exchange_rounded),
            title: Text(text),
          ),
        ),
      );
    }
    if (canRequestRefund(order, latest)) {
      lines.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.currency_exchange_rounded),
          label: Text(l10n.refundRequestTitle),
        ),
      );
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: lines,
      ),
    );
  }
}
