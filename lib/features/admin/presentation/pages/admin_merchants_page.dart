import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class AdminMerchantsPage extends ConsumerWidget {
  const AdminMerchantsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final merchantsAsync = ref.watch(adminMerchantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.merchantManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(l10n.verified),
                        onTap: () => Navigator.pop(ctx),
                      ),
                      ListTile(
                        leading: const Icon(Icons.pending_outlined),
                        title: Text(l10n.pending),
                        onTap: () => Navigator.pop(ctx),
                      ),
                      ListTile(
                        leading: const Icon(Icons.block),
                        title: Text(l10n.suspended),
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              );
            },
            tooltip: l10n.filter,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminMerchantsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchMerchantsAdmin,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.invalidate(adminMerchantsProvider);
              },
            ),
          ),
          Expanded(
            child: merchantsAsync.when(
              loading: () => const Center(
                child: AppLoaderCircular(),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(adminMerchantsProvider),
                ),
              ),
              data: (merchants) {
                if (merchants.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.store_outlined,
                    title: l10n.noMerchantsAdmin,
                    message: l10n.noMerchantsAdmin,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: merchants.length,
                  itemBuilder: (context, index) {
                    final merchant = merchants[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: _MerchantTile(
                        merchant: merchant,
                        l10n: l10n,
                        onStatusChanged: (status) async {
                          final adminService =
                              ref.read(adminServiceProvider);
                          await adminService.updateMerchantStatus(
                            merchant['id'] as String,
                            status,
                          );
                          ref.invalidate(adminMerchantsProvider);
                        },
                        onManageProducts: () => _showManageProductsSheet(
                          context,
                          ref,
                          merchant,
                        ),
                        onDeleteMerchant: () => _confirmDeleteMerchant(
                          context,
                          ref,
                          merchant,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageProductsSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> merchant,
  ) async {
    final l10n = AppLocalizations.of(context);
    final merchantId = merchant['id'] as String;
    final merchantName = merchant['name'] as String? ?? '';
    final adminService = ref.read(adminServiceProvider);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${l10n.manageProducts} — $merchantName',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: adminService.getMerchantProducts(merchantId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: AppLoaderCircular());
                  }
                  final products = snap.data ?? [];
                  if (products.isEmpty) {
                    return Center(
                      child: PremiumEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: l10n.noData,
                        message: l10n.noData,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    itemBuilder: (listCtx, index) {
                      final p = products[index];
                      final available = p['is_available'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: available
                                ? AppColors.successLight.withValues(alpha: 0.1)
                                : AppColors.warningLight.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                              color: available
                                  ? AppColors.successLight
                                  : AppColors.warningLight,
                            ),
                          ),
                          title: Text(p['name'] as String? ?? ''),
                          subtitle: Text(
                            '${p['price'] ?? ''}'
                            '${available ? '' : ' • ${l10n.suspended}'}',
                          ),
                          trailing: IconButton(
                            tooltip: l10n.deleteProduct,
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: Theme.of(listCtx).colorScheme.error,
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(listCtx);
                              final ok = await showDialog<bool>(
                                context: listCtx,
                                builder: (dCtx) => AlertDialog(
                                  title: Text(l10n.deleteProduct),
                                  content: Text(l10n.confirmDeleteReview),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(dCtx).colorScheme.error,
                                      ),
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              final done = await adminService
                                  .deleteProduct(p['id'] as String);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(done
                                      ? l10n.deleted
                                      : l10n.deleteSoftFailed),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _showManageProductsSheet(
                                  context,
                                  ref,
                                  merchant,
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMerchant(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> merchant,
  ) async {
    final l10n = AppLocalizations.of(context);
    final merchantName = merchant['name'] as String? ?? '';
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.deleteMerchant} — $merchantName'),
        content: Text(l10n.confirmDeleteMerchant),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final done =
        await ref.read(adminServiceProvider).deleteMerchant(merchant['id'] as String);
    ref.invalidate(adminMerchantsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(done ? l10n.deleted : l10n.deleteFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MerchantTile extends StatelessWidget {
  const _MerchantTile({
    required this.merchant,
    required this.l10n,
    required this.onStatusChanged,
    required this.onManageProducts,
    required this.onDeleteMerchant,
  });

  final Map<String, dynamic> merchant;
  final AppLocalizations l10n;
  final Function(String) onStatusChanged;
  final VoidCallback onManageProducts;
  final VoidCallback onDeleteMerchant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = merchant['name'] as String? ?? '';
    final type = merchant['type'] as String? ?? '';
    final status = merchant['status'] as String? ?? 'pending';
    final isVerified = status == 'verified';

    final statusLabel = switch (status) {
      'verified' => l10n.verified,
      'suspended' => l10n.suspended,
      'pending' => l10n.pending,
      _ => status,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isVerified
              ? AppColors.successLight.withValues(alpha: 0.1)
              : AppColors.warningLight.withValues(alpha: 0.1),
          child: Icon(
            Icons.store_outlined,
            color: isVerified ? AppColors.successLight : AppColors.warningLight,
          ),
        ),
        title: Text(name),
        subtitle: Text(type),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isVerified
                    ? AppColors.successLight.withValues(alpha: 0.1)
                    : AppColors.warningLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isVerified ? AppColors.successLight : AppColors.warningLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == '__products') {
                  onManageProducts();
                } else if (value == '__delete') {
                  onDeleteMerchant();
                } else {
                  onStatusChanged(value);
                }
              },
              itemBuilder: (context) => [
                if (!isVerified)
                  PopupMenuItem(
                    value: 'verified',
                    child: Text(l10n.verify),
                  ),
                if (status != 'suspended')
                  PopupMenuItem(
                    value: 'suspended',
                    child: Text(l10n.suspend),
                  ),
                if (status != 'pending')
                  PopupMenuItem(
                    value: 'pending',
                    child: Text(l10n.setPending),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: '__products',
                  child: Text(l10n.manageProducts),
                ),
                PopupMenuItem(
                  value: '__delete',
                  child: Text(
                    l10n.deleteMerchant,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.typeLabel}: $type'),
                  const SizedBox(height: 4),
                  Text('${l10n.statusLabel}: $statusLabel'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
