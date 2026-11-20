import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/features/provider/financial/presentation/providers/financial_providers.dart';

class FinancialCenterPage extends ConsumerWidget {
  const FinancialCenterPage({super.key});

  String _localizedMethod(AppLocalizations l10n, String method) {
    switch (method) {
      case 'bank_transfer':
        return l10n.paymentBankTransfer;
      case 'instapay':
        return l10n.paymentInstapay;
      case 'vodafone_cash':
        return l10n.paymentVodafoneCash;
      case 'cash':
        return l10n.paymentCash;
      default:
        return method;
    }
  }

  (String, Color) _localizedStatus(AppLocalizations l10n, String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return (l10n.verified, AppColors.successLight);
      case 'rejected':
      case 'cancelled':
        return (l10n.rejected, AppColors.errorLight);
      case 'pending':
      default:
        return (l10n.pendingReview, AppColors.warningLight);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(financialSummaryProvider);
    final grace = ref.watch(graceProvider);
    final topups = ref.watch(topupRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.financialCenter),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(financialSummaryProvider);
              ref.invalidate(graceProvider);
              ref.invalidate(topupRequestsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialSummaryProvider);
          ref.invalidate(graceProvider);
          ref.invalidate(topupRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            summary.when(
              loading: () => const Column(
                children: [
                  ShimmerCard(height: 150),
                  SizedBox(height: 12),
                  ShimmerCard(height: 80),
                ],
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.error,
                    message: appErrorText(context, e),
                    actionLabel: l10n.retry,
                    onAction: () => ref.invalidate(financialSummaryProvider),
                  ),
                ),
              ),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedFadeIn(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.brandPurple,
                            AppColors.brandViolet,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandPurple.withValues(
                              alpha: 0.28,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.balance,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.balance.toStringAsFixed(2)} ${l10n.currencySymbol}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _HeroPill(
                                  label: l10n.commissionRate,
                                  value:
                                      '${s.commissionRate.toStringAsFixed(1)}%',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _HeroPill(
                                  label: l10n.pendingTopups,
                                  value: '${s.pendingTopups}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.brandPurple,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => context.push(
                                '/provider-financial-center/topup',
                              ),
                              icon: const Icon(Icons.add_card_rounded),
                              label: Text(
                                l10n.requestTopUp,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  grace.when(
                    data: (g) {
                      final ratio = g.limit > 0
                          ? (g.used / g.limit).clamp(0.0, 1.0)
                          : 0.0;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    color: AppColors.brandPurple,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.graceLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.graceUsed(g.limit, g.remaining, g.used),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.recentTransactions,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (s.recentTransactions.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.noTransactionsYet),
                      ),
                    )
                  else
                    ...s.recentTransactions.map((t) {
                      final isCredit = t.type.toLowerCase() == 'credit';
                      final color = isCredit
                          ? AppColors.successLight
                          : AppColors.errorLight;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(
                              isCredit
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: color,
                            ),
                          ),
                          title: Text(t.description),
                          subtitle: Text(
                            isCredit ? l10n.topUp : l10n.commission,
                          ),
                          trailing: Text(
                            '${isCredit ? '+' : '-'}${t.amount.toStringAsFixed(2)} ${l10n.currencySymbol}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.topUpHistory,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            topups.when(
              loading: () => const ShimmerCard(height: 70),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(appErrorText(context, e)),
                ),
              ),
              data: (list) => list.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.noTopUpRequests),
                      ),
                    )
                  : Column(
                      children: list.map((t) {
                        final (statusText, statusColor) = _localizedStatus(
                          l10n,
                          t.status,
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withValues(
                                alpha: 0.12,
                              ),
                              child: Icon(
                                Icons.receipt_rounded,
                                color: statusColor,
                              ),
                            ),
                            title: Text(
                              '${t.amount.toStringAsFixed(2)} ${l10n.currencySymbol}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_localizedMethod(l10n, t.paymentMethod)} · $statusText',
                                ),
                                if (t.rejectionReason != null &&
                                    t.rejectionReason!.isNotEmpty)
                                  Text(
                                    t.rejectionReason!,
                                    style: const TextStyle(
                                      color: AppColors.errorLight,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
