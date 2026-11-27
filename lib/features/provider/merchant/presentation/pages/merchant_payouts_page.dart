import 'package:flutter/material.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_states.dart';
import 'package:delwaqty/features/provider/merchant/data/merchant_payouts_api.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

String payoutErrorText(AppLocalizations l10n, Object e) =>
    switch (payoutErrorKey(e)) {
      'INSUFFICIENT_BALANCE' => l10n.payoutErrorBalance,
      'PENDING_EXISTS' => l10n.payoutErrorPending,
      'AMBIGUOUS_MERCHANT' ||
      'NO_MERCHANT' => l10n.payoutErrorMerchantUnsupported,
      'INVALID_AMOUNT' => l10n.payoutErrorAmount,
      _ => l10n.payoutErrorGeneric,
    };

String payoutStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'approved' => l10n.payoutStatusApproved,
      'rejected' => l10n.rejected,
      _ => l10n.pending,
    };

/// Parses a typed amount; null when it is not a positive number with at most
/// two decimals.
num? parsePayoutAmount(String text) {
  final v = num.tryParse(text.trim().replaceAll(',', '.'));
  if (v == null || v <= 0 || v.isNaN || v.isInfinite) return null;
  if ((v * 100).round() != v * 100) return null;
  return v;
}

class MerchantPayoutsPage extends StatefulWidget {
  const MerchantPayoutsPage({super.key});

  @override
  State<MerchantPayoutsPage> createState() => _MerchantPayoutsPageState();
}

class _MerchantPayoutsPageState extends State<MerchantPayoutsPage> {
  final _api = MerchantPayoutsApi();
  MerchantLedger? _ledger;
  List<PayoutRequestRow> _requests = [];
  bool _loading = true;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ledger = await _api.ledger();
      final reqs = await _api.myRequests();
      if (mounted) {
        setState(() {
          _ledger = ledger;
          _requests = reqs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _request() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    // One key per dialog: a retry of the same submit replays instead of
    // creating a second request.
    final key = 'app-${DateTime.now().microsecondsSinceEpoch}';
    final amount = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.payoutRequest),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.amount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final v = parsePayoutAmount(controller.text);
              if (v == null) {
                ctx.showAppSnackBar(l10n.payoutErrorAmount, isError: true);
                return;
              }
              Navigator.of(ctx).pop(v);
            },
            child: Text(l10n.submit),
          ),
        ],
      ),
    );
    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.requestPayout(amount, idempotencyKey: key);
      if (mounted) context.showAppSnackBar(l10n.payoutRequested);
      await _load();
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(payoutErrorText(l10n, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final ledger = _ledger;
    final hasPending = _requests.any((r) => r.status == 'pending');
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.merchantPayouts),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || ledger == null
          ? AdminErrorState(
              message: _error is PayoutException
                  ? l10n.payoutErrorGeneric
                  : appErrorText(context, _error),
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.balance),
                          const SizedBox(height: 4),
                          Text(
                            ledger.balance.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed:
                                (_busy || hasPending || ledger.balance <= 0)
                                ? null
                                : _request,
                            icon: const Icon(Icons.payments_rounded),
                            label: Text(l10n.payoutRequest),
                          ),
                          if (hasPending)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                l10n.payoutErrorPending,
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.payoutRequestsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final r in _requests)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.amount.toStringAsFixed(2)),
                      subtitle: Text(
                        '${payoutStatusLabel(l10n, r.status)}'
                        '${(r.rejectionReason ?? '').isEmpty ? '' : ': ${r.rejectionReason}'}',
                      ),
                      trailing: Text(
                        r.createdAt.toLocal().toString().substring(0, 10),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.payoutLedgerTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (ledger.entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l10n.payoutLedgerEmpty),
                    ),
                  for (final e in ledger.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        e.isCredit
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: e.isCredit ? Colors.green : cs.error,
                      ),
                      title: Text(
                        '${e.isCredit ? '+' : '-'}${e.amount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(e.description ?? ''),
                      trailing: Text(
                        e.createdAt.toLocal().toString().substring(0, 10),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
