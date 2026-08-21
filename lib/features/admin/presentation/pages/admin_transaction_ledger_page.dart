import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';

class AdminTransactionLedgerPage extends ConsumerStatefulWidget {
  const AdminTransactionLedgerPage({super.key});

  @override
  ConsumerState<AdminTransactionLedgerPage> createState() =>
      _AdminTransactionLedgerPageState();
}

class _AdminTransactionLedgerPageState
    extends ConsumerState<AdminTransactionLedgerPage> {
  String? _selectedType;
  String _searchQuery = '';
  int _currentPage = 0;

  static const _types = <String?>[
    null,
    'order',
    'ride',
    'service_booking',
    'delivery',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final ledgerAsync = ref.watch(
      transactionLedgerProvider((
        type: _selectedType,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: _currentPage,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTransactionLedger),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(transactionLedgerProvider);
              setState(() {
                _currentPage = 0;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterRow(context, l10n, cs),
          Expanded(
            child: ledgerAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(
                child: PremiumCard(
                  child: PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.error,
                    message: l10n.errorLoading,
                    actionLabel: l10n.retry,
                    onAction: () => ref.invalidate(transactionLedgerProvider),
                  ),
                ),
              ),
              data: (ledger) {
                if (ledger.items.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: l10n.noTransactions,
                    message: l10n.noTransactions,
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: _buildLedgerList(context, ledger.items, l10n, cs),
                    ),
                    _buildPagination(context, ledger, l10n, cs),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final typeLabels = <String?, String>{
      null: l10n.all,
      'order': l10n.orders,
      'ride': l10n.ride,
      'service_booking': l10n.serviceBookingType,
      'delivery': l10n.delivery,
    };

    return AnimatedFadeIn(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: cs.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedType,
                  isDense: true,
                  items: _types.map((type) {
                    return DropdownMenuItem<String?>(
                      value: type,
                      child: Text(
                        typeLabels[type] ?? l10n.all,
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                      _currentPage = 0;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.search,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: AppTextStyles.bodyMedium,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 0;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerList(
    BuildContext context,
    List<TransactionLedgerItem> items,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return AnimatedFadeIn(
          delay: Duration(milliseconds: index * 30),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index < items.length - 1 ? 8 : 0,
            ),
            child: _LedgerItemTile(
              item: item,
              l10n: l10n,
              cs: cs,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination(
    BuildContext context,
    TransactionLedger ledger,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    if (ledger.totalPages <= 1) return const SizedBox.shrink();

    return AnimatedFadeIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _currentPage > 0
                  ? () => setState(() => _currentPage--)
                  : null,
              icon: const Icon(Icons.chevron_right),
              color: cs.onSurface,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brandLavender,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_currentPage + 1} / ${ledger.totalPages}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.brandPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _currentPage < ledger.totalPages - 1
                  ? () => setState(() => _currentPage++)
                  : null,
              icon: const Icon(Icons.chevron_left),
              color: cs.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerItemTile extends StatelessWidget {
  const _LedgerItemTile({
    required this.item,
    required this.l10n,
    required this.cs,
  });

  final TransactionLedgerItem item;
  final AppLocalizations l10n;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item.status);
    final dateStr = item.createdAt != null
        ? '${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year}'
        : '-';

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: AppSpacing.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandLavender,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.referenceType,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.brandPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: AppTextStyles.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _AmountColumn(
                label: l10n.amount,
                value: '${item.grossAmount.toStringAsFixed(2)} ${item.currency}',
                cs: cs,
              ),
              const SizedBox(width: 12),
              _AmountColumn(
                label: l10n.commissionLabel,
                value: '${item.commissionRate.toStringAsFixed(0)}%',
                cs: cs,
                isSmall: true,
              ),
              const SizedBox(width: 12),
              _AmountColumn(
                label: l10n.netLabel,
                value: '${item.commissionAmount.toStringAsFixed(2)} ${item.currency}',
                cs: cs,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.netLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${item.netAmount.toStringAsFixed(2)} ${item.currency}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPurple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.successLight;
      case 'pending':
        return AppColors.warningLight;
      case 'failed':
      case 'cancelled':
        return AppColors.errorLight;
      default:
        return AppColors.infoLight;
    }
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({
    required this.label,
    required this.value,
    required this.cs,
    this.isSmall = false,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: (isSmall ? AppTextStyles.labelMedium : AppTextStyles.bodySmall)
              .copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
