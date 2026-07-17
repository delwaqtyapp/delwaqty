import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_service.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';

class AdminMerchantsPage extends ConsumerWidget {
  const AdminMerchantsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(adminMerchantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () {},
            tooltip: 'Filter',
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
                hintText: 'Search merchants...',
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (merchants) {
                if (merchants.isEmpty) {
                  return const Center(child: Text('No merchants found'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: merchants.length,
                  itemBuilder: (context, index) {
                    final merchant = merchants[index];
                    return _MerchantTile(
                      merchant: merchant,
                      onStatusChanged: (status) async {
                        final adminService = ref.read(adminServiceProvider);
                        await adminService.updateMerchantStatus(
                          merchant['id'] as String,
                          status,
                        );
                        ref.invalidate(adminMerchantsProvider);
                      },
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
  const _MerchantTile({required this.merchant, required this.onStatusChanged});

  final Map<String, dynamic> merchant;
  final Function(String) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = merchant['name'] as String? ?? 'Unknown';
    final type = merchant['type'] as String? ?? 'General';
    final status = merchant['status'] as String? ?? 'pending';
    final isVerified = status == 'verified';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isVerified
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
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
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
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
                  const PopupMenuItem(value: 'verified', child: Text('Verify')),
                if (status != 'suspended')
                  const PopupMenuItem(
                    value: 'suspended',
                    child: Text('Suspend'),
                  ),
                if (status != 'pending')
                  const PopupMenuItem(
                    value: 'pending',
                    child: Text('Set Pending'),
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
