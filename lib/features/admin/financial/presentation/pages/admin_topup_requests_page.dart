import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/features/admin/financial/domain/entities/admin_financial_entities.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';

class AdminTopupRequestsPage extends ConsumerStatefulWidget {
  const AdminTopupRequestsPage({super.key});

  @override
  ConsumerState<AdminTopupRequestsPage> createState() =>
      _AdminTopupRequestsPageState();
}

class _AdminTopupRequestsPageState
    extends ConsumerState<AdminTopupRequestsPage> {
  static const _statuses = [
    'pending',
    'under_review',
    'approved',
    'rejected',
    'cancelled',
  ];
  String? _busyId;

  String _label(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _color(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _approve(AdminTopupRequest item) async {
    setState(() => _busyId = item.id);
    try {
      final res = await ref
          .read(adminFinancialRepositoryProvider)
          .approveTopup(item.id);
      final code = res['code'] as String?;
      if (code == 'OK') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Top-up approved')),
          );
        }
        ref.invalidate(adminTopupRequestsProvider);
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

  Future<void> _reject(AdminTopupRequest item) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Top-Up'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyId = item.id);
    try {
      final res = await ref
          .read(adminFinancialRepositoryProvider)
          .rejectTopup(item.id, reasonController.text.trim());
      final code = res['code'] as String?;
      if (code == 'OK') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Top-up rejected')),
          );
        }
        ref.invalidate(adminTopupRequestsProvider);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final filter = ref.watch(adminTopupStatusFilterProvider);
    final listAsync = ref.watch(adminTopupRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top-Up Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(adminTopupRequestsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: _statuses.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final value = i == 0 ? null : _statuses[i - 1];
                final label = i == 0 ? 'All' : _label(value!, l10n);
                final selected = filter == value;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(adminTopupStatusFilterProvider.notifier)
                      .state = value,
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(adminTopupRequestsProvider),
              child: listAsync.when(
                loading: () => const Center(child: AppLoaderCircular()),
                error: (e, _) => PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: e.toString(),
                  actionLabel: l10n.retry,
                  onAction: () =>
                      ref.invalidate(adminTopupRequestsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const PremiumEmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'No requests',
                      message: 'There are no top-up requests in this scope.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final busy = _busyId == item.id;
                      return PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${l10n.currencySymbol} ${item.amount.toStringAsFixed(2)}',
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
                                    color: _color(item.status)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _label(item.status, l10n),
                                    style: TextStyle(
                                      color: _color(item.status),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Account: ${item.accountId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (item.transferReference != null)
                              Text(
                                'Reference: ${item.transferReference}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (item.message != null)
                              Text(
                                'Note: ${item.message}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (item.status == 'pending') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          busy ? null : () => _approve(item),
                                      icon: busy
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
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
                                      onPressed:
                                          busy ? null : () => _reject(item),
                                      icon: const Icon(Icons.close),
                                      label: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (item.rejectionReason != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reason: ${item.rejectionReason}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.error),
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
          ),
        ],
      ),
    );
  }
}
