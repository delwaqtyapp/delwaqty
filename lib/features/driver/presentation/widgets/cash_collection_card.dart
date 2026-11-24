import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The captain's cash-handoff card (migration 392).
///
/// After the recipient code completes a cash delivery, this card shows the
/// amount the customer hands over and the "تم التحصيل" button. Once the
/// server stamps the collection it switches to a clear collected
/// confirmation with a Done button that returns the captain to the hub.
class CashCollectionCard extends StatelessWidget {
  const CashCollectionCard({
    super.key,
    required this.state,
    required this.busy,
    required this.onCollect,
    required this.onDone,
  });

  final CashCollectionState state;
  final bool busy;
  final VoidCallback onCollect;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final amount = state.amount == null
        ? null
        : '${state.amount!.toStringAsFixed(2)} ${state.currency}';

    return Card(
      key: const ValueKey('cashCollectionCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.collected
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: cs.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.cashCollectedTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.cashCollectedBody(amount ?? ''),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    key: const ValueKey('cashCollectionDone'),
                    onPressed: onDone,
                    child: Text(l10n.done),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: cs.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.cashToCollectTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (amount != null)
                        Text(
                          amount,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.cashToCollectBody(amount ?? ''),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('cashCollectButton'),
                    onPressed: busy ? null : onCollect,
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.collectCashCta),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Fail-closed fallback (migration 392): when the collection state cannot
/// be read after the delivery completed, the captain sees this retryable
/// card instead of the page silently showing nothing — an uncollected cash
/// delivery never looks done.
class CashCollectionRetryCard extends StatelessWidget {
  const CashCollectionRetryCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      key: const ValueKey('cashCollectionRetryCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sync_problem_rounded, color: cs.error, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.cashCollectionStateError,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('cashCollectionRetry'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// The completed-delivery cash block (migration 392, review #84): decides
/// what renders from the async collection state. FAIL CLOSED — an
/// unreadable (error) or unknown (null) state shows the retry card; only a
/// positively known NON-cash delivery renders nothing.
class CashCollectionSection extends StatelessWidget {
  const CashCollectionSection({
    super.key,
    required this.state,
    required this.busy,
    required this.onCollect,
    required this.onDone,
    required this.onRetry,
  });

  final AsyncValue<CashCollectionState?> state;
  final bool busy;
  final VoidCallback onCollect;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (cash) {
        if (cash == null) {
          return CashCollectionRetryCard(onRetry: onRetry);
        }
        if (!cash.isCash) {
          return const SizedBox.shrink();
        }
        return CashCollectionCard(
          state: cash,
          busy: busy,
          onCollect: onCollect,
          onDone: onDone,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => CashCollectionRetryCard(onRetry: onRetry),
    );
  }
}
