import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
            onPressed: () {},
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
}

class _MerchantTile extends StatelessWidget {
  const _MerchantTile({
    required this.merchant,
    required this.l10n,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> merchant;
  final AppLocalizations l10n;
  final Function(String) onStatusChanged;

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
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Icon(
            Icons.store_outlined,
            color: isVerified ? Colors.green : Colors.orange,
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
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isVerified ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => onStatusChanged(value),
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
              ],
            ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
