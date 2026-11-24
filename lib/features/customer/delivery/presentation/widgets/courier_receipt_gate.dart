import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/presentation/widgets/courier_receipt_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Chooses which receipt (if any) the tracking page shows, from the
/// FULL AsyncValue of the ask-anything ride state (#213):
///
/// - loading or error: NO money receipt at all - a failed or loading
///   stream must never fall back to the generic fare-only receipt,
///   which would hide the goods total of a completed courier ride.
///   Error shows a retry.
/// - data(null): the ride is proven to be a plain ride, so [fallback]
///   (the generic receipt) may render.
/// - data(state): terminal rides get the ask-anything receipt (#212);
///   during the ride the live invoice card is the summary, so nothing
///   renders here.
class CourierReceiptGate extends StatelessWidget {
  const CourierReceiptGate({
    required this.askAsync,
    required this.isTerminal,
    required this.fallback,
    required this.onRetry,
    super.key,
  });

  final AsyncValue<AskAnythingRideState?> askAsync;
  final bool isTerminal;
  final Widget fallback;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return askAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => AskStateLoadError(onRetry: onRetry),
      data: (askState) {
        if (askState != null) {
          return isTerminal
              ? CourierReceiptCard(state: askState)
              : const SizedBox.shrink();
        }
        return fallback;
      },
    );
  }
}

/// The outer ask-anything state stream failed: a retry, and crucially
/// NO money receipt until data(null) proves a plain ride (#213).
class AskStateLoadError extends StatelessWidget {
  const AskStateLoadError({required this.onRetry, super.key});

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
