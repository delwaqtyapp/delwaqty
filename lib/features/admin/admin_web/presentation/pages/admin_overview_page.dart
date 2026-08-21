import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  final _client = Supabase.instance.client;
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        _client.from('users').select().count(),
        _client.from('merchants').select().count(),
        _client.from('orders').select().count(),
        _client.from('drivers').select().count(),
        _client.from('service_bookings').select().count(),
      ]);
      if (mounted) {
        setState(() {
          _stats = {
            'users': results[0].count,
            'merchants': results[1].count,
            'orders': results[2].count,
            'drivers': results[3].count,
            'serviceBookings': results[4].count,
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1035),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome to the Delwaqty Admin Panel',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: GridView.count(
                crossAxisCount: _getCrossAxisCount(context),
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.8,
                children: [
                  _StatCard(
                    title: 'Total Users',
                    value: '${_stats['users'] ?? 0}',
                    icon: Icons.people_rounded,
                    color: const Color(0xFF4A90D9),
                  ),
                  _StatCard(
                    title: 'Total Merchants',
                    value: '${_stats['merchants'] ?? 0}',
                    icon: Icons.store_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                  _StatCard(
                    title: 'Total Orders',
                    value: '${_stats['orders'] ?? 0}',
                    icon: Icons.shopping_bag_rounded,
                    color: const Color(0xFF34C759),
                  ),
                  _StatCard(
                    title: 'Active Drivers',
                    value: '${_stats['drivers'] ?? 0}',
                    icon: Icons.delivery_dining_rounded,
                    color: const Color(0xFFFF9500),
                  ),
                  _StatCard(
                    title: 'Service Bookings',
                    value: '${_stats['serviceBookings'] ?? 0}',
                    icon: Icons.home_repair_service_rounded,
                    color: const Color(0xFF00838F),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 800) return 3;
    return 2;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1035),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
