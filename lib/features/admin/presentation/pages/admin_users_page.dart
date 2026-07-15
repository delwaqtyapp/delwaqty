import 'package:flutter/material.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sampleUsers = [
      AdminUser(
        id: 'usr-001',
        name: 'Ahmed Al-Farsi',
        email: 'ahmed@example.com',
        role: AdminRole.admin,
        status: AdminUserStatus.active,
        lastLogin: DateTime.now().subtract(const Duration(minutes: 30)),
        createdAt: DateTime(2024, 1, 15),
      ),
      AdminUser(
        id: 'usr-002',
        name: 'Sara Hassan',
        email: 'sara@example.com',
        role: AdminRole.support,
        status: AdminUserStatus.active,
        lastLogin: DateTime.now().subtract(const Duration(hours: 3)),
        createdAt: DateTime(2024, 3, 22),
      ),
      AdminUser(
        id: 'usr-003',
        name: 'Mohammed Al-Qahtani',
        email: 'mohammed@example.com',
        role: AdminRole.moderator,
        status: AdminUserStatus.suspended,
        lastLogin: DateTime.now().subtract(const Duration(days: 14)),
        createdAt: DateTime(2024, 6, 1),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () {},
            tooltip: 'Add Admin User',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: sampleUsers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = sampleUsers[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(user.name[0]),
                  ),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RoleChip(role: user.role),
                      const SizedBox(width: 8),
                      _StatusDot(status: user.status),
                    ],
                  ),
                  onTap: () {},
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      AdminRole.superAdmin => Colors.red,
      AdminRole.admin => Colors.blue,
      AdminRole.moderator => Colors.orange,
      AdminRole.support => Colors.green,
    };

    return Chip(
      label: Text(
        role.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final AdminUserStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdminUserStatus.active => Colors.green,
      AdminUserStatus.pending => Colors.orange,
      AdminUserStatus.suspended => Colors.red,
      AdminUserStatus.deactivated => Colors.grey,
    };

    return Tooltip(
      message: status.name,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
