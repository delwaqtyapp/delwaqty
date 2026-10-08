import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_stock_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

/// Stock control for the merchant panel.
///
/// `product_inventory` (with its RLS and realtime publication) and
/// `products.stock_quantity` both existed, and the customer app already
/// shipped a full inventory data source — but no merchant page consumed
/// any of it, so a merchant could neither restock a product nor see what
/// was running low.
class MerchantInventoryPage extends ConsumerWidget {
  const MerchantInventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final merchantIdAsync = ref.watch(providerMerchantIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventory),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final id = merchantIdAsync.value;
              if (id != null && id.isNotEmpty) {
                ref.invalidate(merchantStockProvider(id));
              }
            },
          ),
        ],
      ),
      body: merchantIdAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: l10n.failedToLoad,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(providerMerchantIdProvider),
        ),
        data: (merchantId) {
          if (merchantId.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.storefront_outlined,
              title: l10n.noMerchantAccount,
              message: l10n.noMerchantAccountDescription,
            );
          }
          return _InventoryBody(merchantId: merchantId);
        },
      ),
    );
  }
}

class _InventoryBody extends ConsumerWidget {
  const _InventoryBody({required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stockAsync = ref.watch(merchantStockProvider(merchantId));

    return stockAsync.when(
      loading: () => const Center(child: AppLoaderCircular()),
      error: (e, _) => PremiumEmptyState(
        icon: Icons.error_outline,
        title: l10n.error,
        message: l10n.failedToLoad,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(merchantStockProvider(merchantId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return PremiumEmptyState(
            icon: Icons.inventory_2_outlined,
            title: l10n.noInventoryItems,
            message: l10n.noInventoryItemsDescription,
          );
        }

        final outOfStock = items.where((i) => i.isOutOfStock).length;
        final lowStock = items.where((i) => i.isLowStock).length;

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(merchantStockProvider(merchantId)),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryChip(
                          label: l10n.products,
                          value: '${items.length}',
                          color: AppColors.brandPurple,
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryChip(
                          label: l10n.lowStock,
                          value: '$lowStock',
                          color: AppColors.warningLight,
                          icon: Icons.trending_down_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryChip(
                          label: l10n.outOfStock,
                          value: '$outOfStock',
                          color: AppColors.errorLight,
                          icon: Icons.remove_shopping_cart_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _StockTile(
                    item: items[index],
                    merchantId: merchantId,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color.withValues(alpha: 0.85),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StockTile extends ConsumerStatefulWidget {
  const _StockTile({required this.item, required this.merchantId});

  final MerchantStockItem item;
  final String merchantId;

  @override
  ConsumerState<_StockTile> createState() => _StockTileState();
}

class _StockTileState extends ConsumerState<_StockTile> {
  bool _busy = false;

  Future<void> _apply(int delta) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(stockNotifierProvider).adjustBy(
            merchantId: widget.merchantId,
            productId: widget.item.productId,
            delta: delta,
            currentQuantity: widget.item.stockQuantity,
            lowStockThreshold: widget.item.lowStockThreshold,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editExact() async {
    final l10n = AppLocalizations.of(context);
    final controller =
        TextEditingController(text: '${widget.item.stockQuantity}');
    final threshold =
        TextEditingController(text: '${widget.item.lowStockThreshold}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.item.productName),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.stockQuantity),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: threshold,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.lowStockThreshold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final qty = int.tryParse(controller.text.trim());
    final low = int.tryParse(threshold.text.trim());
    if (qty == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(stockNotifierProvider).setStock(
            merchantId: widget.merchantId,
            productId: widget.item.productId,
            quantity: qty,
            lowStockThreshold: low ?? widget.item.lowStockThreshold,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final statusColor = item.isOutOfStock
        ? AppColors.errorLight
        : item.isLowStock
            ? AppColors.warningLight
            : AppColors.successLight;
    final statusLabel = item.isOutOfStock
        ? l10n.outOfStock
        : item.isLowStock
            ? l10n.lowStock
            : l10n.inStock;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: item.isLowStock || item.isOutOfStock
              ? statusColor.withValues(alpha: 0.35)
              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.inventory_2_outlined, color: statusColor),
                  )
                : Icon(Icons.inventory_2_outlined, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$statusLabel · ${l10n.availableLabel} ${item.availableQuantity}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove,
            enabled: !_busy && item.stockQuantity > 0,
            onTap: () => _apply(-1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.stockQuantity}',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            enabled: !_busy,
            onTap: () => _apply(1),
          ),
          IconButton(
            tooltip: l10n.edit,
            onPressed: _busy ? null : _editExact,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? AppColors.brandPurple.withValues(alpha: 0.10)
          : Colors.grey.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? AppColors.brandPurple
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }
}