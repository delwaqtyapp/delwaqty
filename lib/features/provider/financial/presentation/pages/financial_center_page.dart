import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/provider/financial/presentation/providers/financial_providers.dart';

class FinancialCenterPage extends ConsumerWidget {
  const FinancialCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(financialSummaryProvider);
    final grace = ref.watch(graceProvider);
    final topups = ref.watch(topupRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.financialCenter)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialSummaryProvider);
          ref.invalidate(graceProvider);
          ref.invalidate(topupRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summary.when(
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Card(title: l10n.balance, value: '${s.balance.toStringAsFixed(2)} SAR'),
                  _Card(
                    title: l10n.commissionRate,
                    value: '${s.commissionRate.toStringAsFixed(2)}%',
                  ),
                  _Card(title: l10n.pendingTopups, value: '${s.pendingTopups}'),
                  const SizedBox(height: 12),
                  Text(
                    l10n.recentTransactions,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...s.recentTransactions.map(
                    (t) => ListTile(
                      title: Text(t.description),
                      subtitle: Text(t.type),
                      trailing: Text(t.amount.toStringAsFixed(2)),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            grace.when(
              data: (g) => _Card(
                title: l10n.graceLabel,
                value: l10n.graceUsed(g.limit, g.remaining, g.used),
              ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  context.push('/provider-financial-center/topup'),
              child: Text(l10n.requestTopUp),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.topUpHistory,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            topups.when(
              data: (list) => list.isEmpty
                  ? Text(l10n.noTopUpRequests)
                  : Column(
                      children: list
                          .map(
                            (t) => ListTile(
                              title: Text(
                                '${t.amount.toStringAsFixed(2)} ${t.currency}',
                              ),
                              subtitle: Text('${t.status} · ${t.paymentMethod}'),
                              trailing: t.rejectionReason != null
                                  ? Text(t.rejectionReason!)
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(title: Text(title), subtitle: Text(value)),
      );
}
