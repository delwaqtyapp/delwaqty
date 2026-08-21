import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';

class AdminGraceManagementPage extends ConsumerStatefulWidget {
  const AdminGraceManagementPage({super.key});

  @override
  ConsumerState<AdminGraceManagementPage> createState() =>
      _AdminGraceManagementPageState();
}

class _AdminGraceManagementPageState
    extends ConsumerState<AdminGraceManagementPage> {
  final _targetController = TextEditingController();
  final _limitController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _busy = false;

  Future<void> _set() async {
    final target = ref.read(graceTargetProvider).trim();
    final limit = int.tryParse(_limitController.text.trim());
    if (target.isEmpty || limit == null || limit < 0) return;
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(adminFinancialRepositoryProvider)
          .setGrace(
            userId: target,
            newLimit: limit,
            reason: _reasonController.text.trim(),
          );
      final code = res['code'] as String?;
      if (code == 'OK') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grace limit updated')),
          );
        }
        ref.invalidate(graceAccountProvider);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final accountAsync = ref.watch(graceAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Grace Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lookup Account',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _targetController,
                        decoration: const InputDecoration(
                          labelText: 'User ID (UUID)',
                          hintText: 'Paste the account UUID',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(graceTargetProvider.notifier).state =
                              _targetController.text.trim(),
                      child: const Text('Fetch'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          accountAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AppLoaderCircular(),
              ),
            ),
            error: (e, _) => PremiumEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.error,
              message: e.toString(),
            ),
            data: (account) {
              if (account == null) {
                return const PremiumEmptyState(
                  icon: Icons.search_rounded,
                  title: 'No account',
                  message:
                      'Enter a valid account UUID to manage its grace limit.',
                );
              }
              return PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Grace',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Stat(
                          label: 'Limit',
                          value: account.graceLimit.toString(),
                        ),
                        _Stat(
                          label: 'Used',
                          value: account.graceUsed.toString(),
                        ),
                        _Stat(
                          label: 'Remaining',
                          value: account.remaining.toString(),
                          color: cs.primary,
                        ),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: _limitController,
                      decoration: const InputDecoration(
                        labelText: 'New Grace Limit',
                        hintText: '0, 1, 2, 3, 4, 5, 6, 10 ...',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _set,
                        child: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Update Grace Limit'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
