import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/provider/financial/presentation/providers/financial_providers.dart';
import 'package:delwaqty/features/driver/financial/presentation/providers/driver_financial_providers.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';

class DriverFinancialCenterPage extends ConsumerWidget {
  const DriverFinancialCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId =
        authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Financial Center')),
        body: const Center(child: Text('Please log in to view your finances.')),
      );
    }
    final driverId = userId;

    final summary = ref.watch(financialSummaryProvider);
    final grace = ref.watch(graceProvider);
    final topups = ref.watch(topupRequestsProvider);
    final wallet = ref.watch(driverWalletDetailProvider(driverId));
    final earnings = ref.watch(driverEarningsProvider(driverId));

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Center')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/driver/financial-center/topup'),
        icon: const Icon(Icons.add),
        label: const Text('Top-Up'),
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
                    title: 'Wallet Balance',
                    value: '${s.balance.toStringAsFixed(2)} SAR',
                  ),
                  _StatCard(
                    title: 'Commission Rate',
                    value: '${s.commissionRate.toStringAsFixed(2)}%',
                  ),
                  _StatCard(
                    title: 'Pending Top-Ups',
                    value: '${s.pendingTopups}',
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const _StatCard(title: 'Balance', value: 'Unavailable'),
            ),
            wallet.when(
              data: (w) => Column(
                children: [
                  _StatCard(
                    title: 'Available Balance',
                    value:
                        '${(w.balance - w.pendingWithdrawals).clamp(0.0, double.infinity).toStringAsFixed(2)} EGP',
                  ),
                  _StatCard(
                    title: 'Pending Withdrawals',
                    value: '${w.pendingWithdrawals.toStringAsFixed(2)} EGP',
                  ),
                  _StatCard(
                    title: 'Total Withdrawn',
                    value: '${w.totalWithdrawn.toStringAsFixed(2)} EGP',
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            grace.when(
              data: (g) => _StatCard(
                title: 'Grace',
                value:
                    'Used ${g.used} / Limit ${g.limit} (${g.remaining} remaining)',
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
                      title: 'Gross Earnings',
                      value: '${gross.toStringAsFixed(2)} EGP',
                    ),
                    _StatCard(
                      title: 'Commission',
                      value:
                          '${commission.toStringAsFixed(2)} EGP (${rate.toStringAsFixed(1)}%)',
                    ),
                    _StatCard(
                      title: 'Net Earnings',
                      value: '${net.toStringAsFixed(2)} EGP',
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Recent Transactions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            summary.when(
              data: (s) => s.recentTransactions.isEmpty
                  ? const Text('No transactions yet.')
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
            const Text(
              'Top-Up History',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            topups.when(
              data: (list) => list.isEmpty
                  ? const Text('No top-up requests yet.')
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
              error: (e, _) => Text('Error: $e'),
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
