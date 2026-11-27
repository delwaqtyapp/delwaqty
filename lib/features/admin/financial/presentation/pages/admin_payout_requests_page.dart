import 'package:flutter/material.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_states.dart';
import 'package:delwaqty/features/provider/merchant/data/merchant_payouts_api.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_payouts_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

/// Admin queue for merchant payout requests. Approving debits the merchant
/// ledger (admin_review_payout re-checks the balance under lock). The server
/// enforces the admin scope; payout RPCs are platform-global.
class AdminPayoutRequestsPage extends StatefulWidget {
  const AdminPayoutRequestsPage({super.key});

  @override
  State<AdminPayoutRequestsPage> createState() =>
      _AdminPayoutRequestsPageState();
}

class _AdminPayoutRequestsPageState extends State<AdminPayoutRequestsPage> {
  final _api = MerchantPayoutsApi();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
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
      final rows = await _api.adminList();
      if (mounted) {
        setState(() {
          _rows = rows;
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

  Future<void> _approve(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final amount = (row['amount'] as num).toStringAsFixed(2);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.approve),
        content: Text('${l10n.adminPayoutApproveBody} $amount'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.approve),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _review(row, approve: true);
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final note = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reject),
        content: TextField(
          controller: note,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.adminRefundRejectHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(note.text.trim()),
            child: Text(l10n.reject),
          ),
        ],
      ),
    );
    if (text == null || !mounted) return;
    if (text.isEmpty) {
      context.showAppSnackBar(l10n.adminRefundNoteRequired, isError: true);
      return;
    }
    await _review(row, approve: false, reason: text);
  }

  Future<void> _review(
    Map<String, dynamic> row, {
    required bool approve,
    String? reason,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      await _api.adminReview(
        requestId: row['id'] as String,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      context.showAppSnackBar(
        approve ? l10n.adminPayoutApproved : l10n.adminPayoutRejected,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(payoutErrorText(l10n, e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminPayoutRequests),
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
          : _error != null
          ? AdminErrorState(
              message: _error is PayoutException
                  ? l10n.payoutErrorGeneric
                  : appErrorText(context, _error),
              onRetry: _load,
            )
          : _rows.isEmpty
          ? PremiumEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: l10n.adminPayoutNone,
              message: l10n.allCaughtUp,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final r = _rows[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(r['merchant_name'] as String?) ?? ''} - ${(r['amount'] as num).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.balance}: ${(r['merchant_balance'] as num).toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _approve(r),
                                child: Text(l10n.approve),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _reject(r),
                                child: Text(l10n.reject),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
