import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/provider/financial/presentation/providers/financial_providers.dart';
import 'package:delwaqty/features/driver/financial/presentation/providers/driver_financial_providers.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class DriverFinancialCenterPage extends ConsumerWidget {
  const DriverFinancialCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final userId =
        authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.financialCenter)),
        body: Center(child: Text(l10n.pleaseLogInFinances)),
      );
    }
    final driverId = userId;

    final summary = ref.watch(financialSummaryProvider);
    final grace = ref.watch(graceProvider);
    final topups = ref.watch(topupRequestsProvider);
    final wallet = ref.watch(driverWalletDetailProvider(driverId));
    final earnings = ref.watch(driverEarningsProvider(driverId));
    final symbol = l10n.currencySymbol;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.financialCenter)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/driver/financial-center/topup'),
        icon: const Icon(Icons.add),
        label: Text(l10n.topUp),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialSummaryProvider);
          ref.invalidate(graceProvider);
          ref.invalidate(topupRequestsProvider);
          ref.invalidate(driverWalletDetailProvider(driverId));
          ref.invalidate(driverEarningsProvider(driverId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summary.when(
              data: (s) => Column(
                children: [
                  _StatCard(
                    title: l10n.walletBalance,
                    value: '${s.balance.toStringAsFixed(2)} $symbol',
                  ),
                  _StatCard(
                    title: l10n.commissionRate,
                    value: '${s.commissionRate.toStringAsFixed(2)}%',
                  ),
                  _StatCard(
                    title: l10n.pendingTopups,
                    value: '${s.pendingTopups}',
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const _StatCard(title: '', value: ''),
            ),
            wallet.when(
              data: (w) => Column(
                children: [
                  _StatCard(
                    title: l10n.availableBalance,
                    value:
                        '${(w.balance - w.pendingWithdrawals).clamp(0.0, double.infinity).toStringAsFixed(2)} $symbol',
                  ),
                  _StatCard(
                    title: l10n.pendingWithdrawals,
                    value: '${w.pendingWithdrawals.toStringAsFixed(2)} $symbol',
                  ),
                  _StatCard(
                    title: l10n.totalWithdrawn,
                    value: '${w.totalWithdrawn.toStringAsFixed(2)} $symbol',
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            grace.when(
              data: (g) => _StatCard(
                title: l10n.graceLabel,
                value: l10n.graceUsed(g.limit, g.remaining, g.used),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            earnings.when(
              data: (list) {
                final gross =
                    list.fold<double>(0, (sum, e) => sum + e.amount);
                final rate = summary.maybeWhen(
                  data: (s) => s.commissionRate,
                  orElse: () => 0.0,
                );
                final commission = gross * rate / 100;
                final net = gross - commission;
                return Column(
                  children: [
                    _StatCard(
                      title: l10n.grossEarnings,
                      value: '${gross.toStringAsFixed(2)} $symbol',
                    ),
                    _StatCard(
                      title: l10n.commission,
                      value:
                          '${commission.toStringAsFixed(2)} $symbol (${rate.toStringAsFixed(1)}%)',
                    ),
                    _StatCard(
                      title: l10n.netEarnings,
                      value: '${net.toStringAsFixed(2)} $symbol',
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.recentTransactions,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            summary.when(
              data: (s) => s.recentTransactions.isEmpty
                  ? Text(l10n.noTransactionsYet)
                  : Column(
                      children: s.recentTransactions
                          .map(
                            (t) => ListTile(
                              title: Text(t.description),
                              subtitle: Text(t.type),
                              trailing:
                                  Text(t.amount.toStringAsFixed(2)),
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
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
              error: (e, _) => Text(l10n.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(title: Text(title), subtitle: Text(value)),
      );
}
