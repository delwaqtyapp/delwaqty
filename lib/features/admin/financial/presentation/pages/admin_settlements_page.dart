import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';

class AdminSettlementsPage extends ConsumerStatefulWidget {
  const AdminSettlementsPage({super.key});

  @override
  ConsumerState<AdminSettlementsPage> createState() =>
      _AdminSettlementsPageState();
}

class _AdminSettlementsPageState extends ConsumerState<AdminSettlementsPage> {
  String? _busyId;

  Color _color(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _label(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'under_review':
        return 'Under Review';
      default:
        return 'Pending';
    }
  }

  Future<void> _act(String id, bool approve) async {
    setState(() => _busyId = id);
    try {
      final repo = ref.read(adminFinancialRepositoryProvider);
      final res = approve
          ? await repo.approveSettlement(id)
          : await repo.rejectSettlement(id, 'Reviewed by admin');
      final code = res['code'] as String?;
      if (code == 'OK') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve ? 'Settlement approved' : 'Settlement rejected'),
            ),
          );
        }
        ref.invalidate(adminSettlementsProvider);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _submit() async {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final messageController = TextEditingController();
    String method = 'bank_transfer';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Submit Settlement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  items: const [
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'instapay',
                      child: Text('InstaPay'),
                    ),
                  ],
                  onChanged: (v) => setStateDialog(() => method = v!),
                  decoration: const InputDecoration(labelText: 'Method'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(labelText: 'Reference'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text);
                if (amt == null || amt <= 0) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) return;
    try {
      final res = await ref
          .read(adminFinancialRepositoryProvider)
          .submitSettlement(
            amount: amount,
            method: method,
            reference: referenceController.text.trim(),
            message: messageController.text.trim(),
          );
      final code = res['code'] as String?;
      if (code == 'OK') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settlement submitted')),
          );
        }
        ref.invalidate(adminSettlementsProvider);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(adminIsOwnerProvider);
    final listAsync = ref.watch(adminSettlementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminSettlementsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submit,
        icon: const Icon(Icons.add),
        label: const Text('Submit'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminSettlementsProvider),
        child: listAsync.when(
          loading: () => const Center(child: AppLoaderCircular()),
          error: (e, _) => PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: e.toString(),
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(adminSettlementsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const PremiumEmptyState(
                icon: Icons.account_balance_wallet_rounded,
                title: 'No settlements',
                message: 'Submit a settlement to move collected funds.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = items[i];
                final busy = _busyId == s.id;
                return PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l10n.currencySymbol} ${s.amount.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _color(s.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _label(s.status),
                              style: TextStyle(
                                color: _color(s.status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Admin: ${s.adminId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (s.reference != null)
                        Text(
                          'Reference: ${s.reference}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (s.status == 'pending' && isOwner) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: busy ? null : () => _act(s.id, true),
                                icon: busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : () => _act(s.id, false),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ] else if (s.rejectionReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Reason: ${s.rejectionReason}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
