import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_quote.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The live price negotiation of an ask-anything ride (436): the captain
/// proposes a delivery price; the customer accepts, rejects or counters.
/// The 15 + 5 per extra shop floor is enforced here on counters (#211)
/// and again by the server.
class CourierNegotiationCard extends ConsumerWidget {
  const CourierNegotiationCard({required this.state, super.key});

  final AskAnythingRideState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final quotes = ref.watch(courierQuotesProvider(state.rideId)).value;

    final pending = quotes?.where((q) => q.isPending).firstOrNull;

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
                    state.quoteLocked
                        ? l10n.priceAgreed
                        : pending == null
                        ? l10n.driverQuoteTitle
                        : pending.isFromDriver
                        ? l10n.driverQuoteTitle
                        : l10n.yourCounterTitle,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (state.quoteLocked && state.fare != null)
              Text(
                '${state.fare} ${l10n.egp}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (pending == null)
              Text(
                l10n.waitingForDriverQuote,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                '${pending.amount} ${l10n.egp}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (pending.note != null && pending.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  pending.note!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                l10n.counterFloor(state.quoteBaseline.toString()),
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (pending.isFromDriver)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            _respond(context, ref, pending, 'accept'),
                        child: Text(l10n.accept),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _respond(context, ref, pending, 'reject'),
                        child: Text(l10n.reject),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _counter(context, ref),
                        child: Text(l10n.negotiate),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  l10n.counterSentWaiting,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    CourierQuote quote,
    String action,
  ) async {
    try {
      await ref
          .read(deliveryRepositoryProvider)
          .respondCourierQuote(quote.id, action);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    }
  }

  Future<void> _counter(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final floor = state.quoteBaseline;
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(l10n.counterPrompt),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
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
                  ),
                  onChanged: (_) => setState(() => errorText = null),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.counterFloor(floor.toString()),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  // #211: the client-side floor check; the server
                  // enforces the same bound.
                  final value = double.tryParse(controller.text.trim());
                  if (value == null || value < floor) {
                    setState(
                      () => errorText = l10n.counterFloor(floor.toString()),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop(value);
                },
                child: Text(l10n.sendCounter),
              ),
            ],
          ),
        );
      },
    );
    if (amount == null) return;
    try {
      await ref
          .read(deliveryRepositoryProvider)
          .proposeCourierQuote(state.rideId, amount);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    }
  }
}
