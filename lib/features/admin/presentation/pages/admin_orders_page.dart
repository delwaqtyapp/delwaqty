import 'package:flutter/material.dart';

class AdminOrdersPage extends StatelessWidget {
  const AdminOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search orders...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list_outlined),
                  onPressed: () {},
                  tooltip: 'Filter Orders',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: const [
                _OrderTile(
                  orderId: 'ORD-4521',
                  customer: 'Khalid Al-Saud',
                  merchant: 'Al Baik',
                  amount: 'SAR 87.50',
                  status: 'In Transit',
                  statusColor: Colors.blue,
                ),
                _OrderTile(
                  orderId: 'ORD-4520',
                  customer: 'Fatima Al-Otaibi',
                  merchant: 'Tamimi Markets',
                  amount: 'SAR 234.00',
                  status: 'Delivered',
                  statusColor: Colors.green,
                ),
                _OrderTile(
                  orderId: 'ORD-4519',
                  customer: 'Omar Bin Laden',
                  merchant: 'Nahdi Pharmacy',
                  amount: 'SAR 56.25',
                  status: 'Disputed',
                  statusColor: Colors.red,
                ),
                _OrderTile(
                  orderId: 'ORD-4518',
                  customer: 'Noura Al-Zahrani',
                  merchant: 'Jarir Bookstore',
                  amount: 'SAR 420.00',
                  status: 'Pending',
                  statusColor: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.orderId,
    required this.customer,
    required this.merchant,
    required this.amount,
    required this.status,
    required this.statusColor,
  });

  final String orderId;
  final String customer;
  final String merchant;
  final String amount;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.receipt_outlined, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Text(
              orderId,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              amount,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(child: Text('$customer · $merchant')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
