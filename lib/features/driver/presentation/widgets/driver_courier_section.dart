import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_invoice_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_shopping_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_quote.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The captain's side of an ask-anything ride (436): propose the
/// delivery price and answer counters while the price is open, then
/// record each item at the shop with its real price, cancel the
/// customer's rejected items, and finish shopping. Renders nothing on
/// plain rides (the state stream proves data(null)).
class DriverCourierSection extends ConsumerStatefulWidget {
  const DriverCourierSection({required this.rideId, super.key});

  final String rideId;

  @override
  ConsumerState<DriverCourierSection> createState() =>
      _DriverCourierSectionState();
}

class _DriverCourierSectionState extends ConsumerState<DriverCourierSection> {
  bool _busy = false;
  final Set<String> _busyItemIds = {};

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(courierErrorText(context, e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final askAsync = ref.watch(askAnythingRideProvider(widget.rideId));
    return askAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _ErrorCard(
        onRetry: () => ref.invalidate(askAnythingRideProvider(widget.rideId)),
      ),
      data: (state) {
        if (state == null) return const SizedBox.shrink();
        final live = state.status == 'matched' || state.status == 'arrived';
        if (!live && !state.shoppingFinished) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What the customer asked for, with units or EGP amounts
            // (#217): the captain prices and shops from this list.
            _RequestItemsCard(rideId: state.rideId),
            if (live && !state.quoteLocked)
              _Negotiation(state: state, busy: _busy, run: _run),
            if (live && state.quoteLocked && !state.shoppingFinished)
              _Shopping(
                state: state,
                busy: _busy,
                busyItemIds: _busyItemIds,
                run: _run,
                onItemBusy: (id, isBusy) {
                  if (!mounted) return;
                  setState(
                    () =>
                        isBusy ? _busyItemIds.add(id) : _busyItemIds.remove(id),
                  );
                },
              ),
            if (state.shoppingFinished) _ShoppingDone(state: state),
          ],
        );
      },
    );
  }
}

class _Negotiation extends ConsumerWidget {
  const _Negotiation({
    required this.state,
    required this.busy,
    required this.run,
  });

  final AskAnythingRideState state;
  final bool busy;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final quotesAsync = ref.watch(courierQuotesProvider(state.rideId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.driverQuoteTitle,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.counterFloor(state.quoteBaseline.toStringAsFixed(0)),
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            quotesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => _ErrorCard(
                onRetry: () =>
                    ref.invalidate(courierQuotesProvider(state.rideId)),
              ),
              data: (quotes) {
                final pending = quotes.where((q) => q.isPending).firstOrNull;
                if (pending == null) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _propose(context, ref),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: Text(l10n.driverProposePrice),
                    ),
                  );
                }
                if (pending.isFromDriver) {
                  return Text(
                    l10n.driverQuoteSent,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  );
                }
                // The customer's counter: answer it.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.customerCounter,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pending.amount.toStringAsFixed(2)} ${l10n.egp}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () => ref
                                      .read(driverRepositoryProvider)
                                      .respondCourierQuote(
                                        pending.id,
                                        'accept',
                                      ),
                                ),
                          child: Text(l10n.accept),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () => ref
                                      .read(driverRepositoryProvider)
                                      .respondCourierQuote(
                                        pending.id,
                                        'reject',
                                      ),
                                ),
                          child: Text(l10n.reject),
                        ),
                        OutlinedButton(
                          onPressed: busy ? null : () => _propose(context, ref),
                          child: Text(l10n.negotiate),
                        ),
                      ],
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

  Future<void> _propose(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final floor = state.quoteBaseline;
    final result = await showDialog<(double, String?)>(
      context: context,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(l10n.driverProposePrice),
            // Scrollable: at 320px with 1.6x text and the keyboard open
            // the fixed column overflowed and hid the floor note; the
            // error text wraps instead of ellipsizing (UI review).
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: InputDecoration(
                      hintText: l10n.amountEgp,
                      errorText: errorText,
                      errorMaxLines: 3,
                    ),
                    onChanged: (_) => setState(() => errorText = null),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    inputFormatters: [LengthLimitingTextInputFormatter(300)],
                    decoration: InputDecoration(hintText: l10n.notes),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.counterFloor(floor.toStringAsFixed(0)),
                    style: Theme.of(ctx).textTheme.bodySmall,
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
                onPressed: () {
                  // Client-side bounds (436): the 15 + 5 per extra shop
                  // floor and the 50000 cap; the server enforces both.
                  final value = double.tryParse(amountController.text.trim());
                  if (value == null || value < floor) {
                    setState(
                      () => errorText = l10n.counterFloor(
                        floor.toStringAsFixed(0),
                      ),
                    );
                    return;
                  }
                  if (value > 50000) {
                    setState(() => errorText = l10n.courierErrQuoteCap);
                    return;
                  }
                  final note = noteController.text.trim();
                  Navigator.of(ctx).pop((value, note.isEmpty ? null : note));
                },
                child: Text(l10n.sendCounter),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || !context.mounted) return;
    await run(
      () => ref
          .read(driverRepositoryProvider)
          .proposeCourierQuote(state.rideId, result.$1, note: result.$2),
    );
  }
}

class _Shopping extends ConsumerWidget {
  const _Shopping({
    required this.state,
    required this.busy,
    required this.busyItemIds,
    required this.run,
    required this.onItemBusy,
  });

  final AskAnythingRideState state;
  final bool busy;
  final Set<String> busyItemIds;
  final Future<void> Function(Future<void> Function()) run;
  final void Function(String itemId, bool isBusy) onItemBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              l10n.driverInvoiceHint,
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
              error: (_, _) => _ErrorCard(
                onRetry: () =>
                    ref.invalidate(courierInvoiceItemsProvider(state.rideId)),
              ),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.map(
                    (item) => _DriverItemRow(
                      item: item,
                      busy: busy || busyItemIds.contains(item.id),
                      onCancel: item.isRejected
                          ? () => _cancelItem(context, ref, item)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: busy ? null : () => _addItem(context, ref),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l10n.addItemAtShop),
                      ),
                      FilledButton(
                        onPressed: busy ? null : () => _finish(context, ref),
                        child: Text(l10n.finishShopping),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelItem(
    BuildContext context,
    WidgetRef ref,
    CourierInvoiceItem item,
  ) async {
    onItemBusy(item.id, true);
    await run(
      () =>
          ref.read(driverRepositoryProvider).cancelCourierInvoiceItem(item.id),
    );
    // The parent clears the flag only while it is still mounted (#218).
    if (context.mounted) onItemBusy(item.id, false);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.finishShopping),
        content: Text(l10n.finishShoppingConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.finishShopping),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await run(
      () => ref
          .read(driverRepositoryProvider)
          .finishCourierShopping(state.rideId),
    );
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final shopController = TextEditingController();
    final productController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController();
    final receiptController = TextEditingController();
    String unit = 'piece';
    final added =
        await showDialog<(String, String, double, String, double?, String?)>(
          context: context,
          builder: (ctx) {
            String? errorText;
            return StatefulBuilder(
              builder: (ctx, setState) => AlertDialog(
                title: Text(l10n.addItemAtShop),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: shopController,
                        autofocus: true,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(200),
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.shopNameLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: productController,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(200),
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.productLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.priceEgpLabel,
                          errorText: errorText,
                        ),
                        onChanged: (_) => setState(() => errorText = null),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        children: [
                          for (final (value, label) in [
                            ('piece', l10n.unitPiece),
                            ('kilo', l10n.unitKilo),
                            ('half', l10n.unitHalf),
                            ('quarter', l10n.unitQuarter),
                            ('amount', l10n.unitAmount),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: unit == value,
                              onSelected: (_) => setState(() => unit = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.quantityLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: receiptController,
                        keyboardType: TextInputType.url,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1000),
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.receiptLinkLabel,
                        ),
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
                    onPressed: () {
                      // Server bounds (436): non-empty shop/product,
                      // 0 <= price <= 100000, quantity 0.001..1000.
                      final shop = shopController.text.trim();
                      final product = productController.text.trim();
                      final price = double.tryParse(
                        priceController.text.trim(),
                      );
                      final quantityText = quantityController.text.trim();
                      final quantity = quantityText.isEmpty
                          ? null
                          : double.tryParse(quantityText);
                      if (shop.isEmpty || product.isEmpty) return;
                      if (price == null || price < 0 || price > 100000) {
                        setState(
                          () => errorText = l10n.courierErrInvalidAmount,
                        );
                        return;
                      }
                      // "1.." parses to null: that is a malformed
                      // quantity, not an absent one - say so.
                      if (quantityText.isNotEmpty && quantity == null) {
                        setState(() => errorText = l10n.courierErrInvalidInput);
                        return;
                      }
                      if (quantity != null &&
                          (quantity < 0.001 || quantity > 1000)) {
                        setState(() => errorText = l10n.courierErrInvalidInput);
                        return;
                      }
                      final receipt = receiptController.text.trim();
                      Navigator.of(ctx).pop((
                        shop,
                        product,
                        price,
                        unit,
                        quantity,
                        receipt.isEmpty ? null : receipt,
                      ));
                    },
                    child: Text(l10n.addItem),
                  ),
                ],
              ),
            );
          },
        );
    if (added == null || !context.mounted) return;
    await run(
      () => ref
          .read(driverRepositoryProvider)
          .addCourierInvoiceItem(
            state.rideId,
            shopName: added.$1,
            productName: added.$2,
            price: added.$3,
            unit: added.$4,
            quantity: added.$5,
            receiptPhotoUrl: added.$6,
          ),
    );
  }
}

class _DriverItemRow extends StatelessWidget {
  const _DriverItemRow({required this.item, required this.busy, this.onCancel});

  final CourierInvoiceItem item;
  final bool busy;
  final VoidCallback? onCancel;

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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    decoration: item.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  '${item.shopName} - ${item.price.toStringAsFixed(2)} ${l10n.egp}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            TextButton(
              onPressed: busy ? null : onCancel,
              child: Text(l10n.cancelAtShop),
            )
          else
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
        ],
      ),
    );
  }
}

class _ShoppingDone extends StatelessWidget {
  const _ShoppingDone({required this.state});

  final AskAnythingRideState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fare = state.fare ?? 0;
    final goods = state.goodsTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.shoppingFinishedTitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _TotalLine(label: l10n.deliveryFeeLabel, amount: fare),
            _TotalLine(label: l10n.goodsLabel, amount: goods),
            _TotalLine(
              label: l10n.cashOnDeliveryTotal,
              amount: fare + goods,
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final double amount;
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
          Text('${amount.toStringAsFixed(2)} ${l10n.egp}', style: style),
        ],
      ),
    );
  }
}

/// The customer's structured request (#217): each item with its
/// localized unit or its EGP amount, so the captain knows what to buy
/// before pricing the ride.
class _RequestItemsCard extends ConsumerWidget {
  const _RequestItemsCard({required this.rideId});

  final String rideId;

  String _unitText(AppLocalizations l10n, CourierShoppingItem item) {
    return switch (item.unit) {
      'kilo' => l10n.unitKilo,
      'half' => l10n.unitHalf,
      'quarter' => l10n.unitQuarter,
      'amount' => '${(item.amountEgp ?? 0).toStringAsFixed(2)} ${l10n.egp}',
      _ => item.unit,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final itemsAsync = ref.watch(driverCourierRequestItemsProvider(rideId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.shoppingListTitle,
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
                      driverCourierRequestItemsProvider(rideId),
                    ),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          Text(
                            _unitText(l10n, item),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text(l10n.somethingWentWrong)),
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
