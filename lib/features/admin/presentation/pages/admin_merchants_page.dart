import 'package:flutter/material.dart';

class AdminMerchantsPage extends StatelessWidget {
  const AdminMerchantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () {},
            tooltip: 'Filter',
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
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: const [
                _MerchantTile(
                  name: 'Al Baik',
                  type: 'Restaurant',
                  status: 'Verified',
                  orders: '12,450',
                  rating: 4.8,
                ),
                _MerchantTile(
                  name: 'Tamimi Markets',
                  type: 'Grocery',
                  status: 'Verified',
                  orders: '8,320',
                  rating: 4.6,
                ),
                _MerchantTile(
                  name: 'Nahdi Pharmacy',
                  type: 'Pharmacy',
                  status: 'Pending Review',
                  orders: '5,100',
                  rating: 4.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantTile extends StatelessWidget {
  const _MerchantTile({
    required this.name,
    required this.type,
    required this.status,
    required this.orders,
    required this.rating,
  });

  final String name;
  final String type;
  final String status;
  final String orders;
  final double rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = status == 'Verified';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
          child: Icon(
            Icons.store_outlined,
            color: isVerified ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(name),
        subtitle: Text('$type · $orders orders'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 2),
            Text(
              rating.toString(),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
