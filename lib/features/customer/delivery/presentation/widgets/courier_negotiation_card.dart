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
/// The 15 + 5 per extra shop floor and the 50000 cap are enforced here
/// on counters (#211, #215) and again by the server.
class CourierNegotiationCard extends ConsumerStatefulWidget {
  const CourierNegotiationCard({required this.state, super.key});

  final AskAnythingRideState state;

  /// Server bound (436): no quote or counter above this.
  static const maxQuote = 50000;

  @override
  ConsumerState<CourierNegotiationCard> createState() =>
      _CourierNegotiationCardState();
}

class _CourierNegotiationCardState
    extends ConsumerState<CourierNegotiationCard> {
  bool _busy = false;

  AskAnythingRideState get state => widget.state;

  @override
  Widget build(BuildContext context) {
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
                    state.quoteLocked
                        ? l10n.priceAgreed
                        : l10n.driverQuoteTitle,
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
                '${state.fare!.toStringAsFixed(2)} ${l10n.egp}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              quotesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => _LoadError(
                  onRetry: () =>
                      ref.invalidate(courierQuotesProvider(state.rideId)),
                ),
                data: (quotes) => _buildNegotiation(context, l10n, cs, quotes),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNegotiation(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
    List<CourierQuote> quotes,
  ) {
    final theme = Theme.of(context);
    final pending = quotes.where((q) => q.isPending).firstOrNull;

    if (pending == null) {
      return Text(
        l10n.waitingForDriverQuote,
        style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pending.isFromDriver ? l10n.driverQuoteTitle : l10n.yourCounterTitle,
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
          l10n.counterFloor(state.quoteBaseline.toStringAsFixed(0)),
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (pending.isFromDriver)
          // Wrap keeps every action readable at 320px and large text
          // scales instead of squeezing three buttons into one row.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _respond(pending, 'accept'),
                child: Text(l10n.accept),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _respond(pending, 'reject'),
                child: Text(l10n.reject),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _counter,
                child: Text(l10n.negotiate),
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
    );
  }

  Future<void> _respond(CourierQuote quote, String action) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(deliveryRepositoryProvider)
          .respondCourierQuote(quote.id, action);
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

  Future<void> _counter() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final floor = state.quoteBaseline;
    const cap = CourierNegotiationCard.maxQuote;
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
                  l10n.counterFloor(floor.toStringAsFixed(0)),
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
                  // #211: the client-side floor check; #215: the server
                  // cap. The server enforces both bounds again.
                  final value = double.tryParse(controller.text.trim());
                  if (value == null || value < floor) {
                    setState(
                      () => errorText = l10n.counterFloor(
                        floor.toStringAsFixed(0),
                      ),
                    );
                    return;
                  }
                  if (value > cap) {
                    setState(() => errorText = l10n.courierErrQuoteCap);
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
    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(deliveryRepositoryProvider)
          .proposeCourierQuote(state.rideId, amount);
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
}

/// Inline load-failure state with a retry, so a failed stream never
/// renders as empty data (#213).
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.somethingWentWrong,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(l10n.retry)),
      ],
    );
  }
}
